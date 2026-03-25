
# depends like as platform: arm/amd
FROM --platform=$BUILDPLATFORM golang:latest AS build

WORKDIR /src
COPY ./Xray-core/ .

ARG TARGETOS
ARG TARGETARCH
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH CGO_ENABLED=0 go build -o xray -trimpath -buildvcs=false -gcflags="all=-l=4" -ldflags "-s -w -buildid=" ./main

ADD https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geoip.dat /tmp/geodat/geoip.dat
ADD https://raw.githubusercontent.com/Loyalsoldier/v2ray-rules-dat/release/geosite.dat /tmp/geodat/geosite.dat

# for correct copy from build to run
RUN mkdir /tmp/empty

RUN mkdir -p /tmp/usr/local/etc/xray \
 && cat <<EOF >/tmp/usr/local/etc/xray/00_log.json
{
  "log": {
    "error": "/var/log/xray/error.log",
    "loglevel": "warning",
    "access": "none",
    "dnsLog": false
  }
}
EOF



# create empty configs for template
RUN echo '{}' >/tmp/usr/local/etc/xray/01_api.json
RUN echo '{}' >/tmp/usr/local/etc/xray/02_dns.json
RUN echo '{}' >/tmp/usr/local/etc/xray/03_routing.json
RUN echo '{}' >/tmp/usr/local/etc/xray/04_policy.json
RUN echo '{}' >/tmp/usr/local/etc/xray/05_inbounds.json
RUN echo '{}' >/tmp/usr/local/etc/xray/06_outbounds.json
RUN echo '{}' >/tmp/usr/local/etc/xray/07_transport.json
RUN echo '{}' >/tmp/usr/local/etc/xray/08_stats.json
RUN echo '{}' >/tmp/usr/local/etc/xray/09_reverse.json

# create log files
RUN mkdir -p /tmp/var/log/xray && touch \
  /tmp/var/log/xray/access.log \
  /tmp/var/log/xray/error.log


#Build runtime image
FROM alpine:latest
LABEL Name=xray Version=0.0.1

RUN apk update && apk add  --no-cache jq 

ARG NEWUSER=xray
RUN addgroup -g 299 "${NEWUSER}" && \
    adduser -u 299 -G "${NEWUSER}" -D -H "${NEWUSER}"



COPY --from=build --chown="${NEWUSER}":"${NEWUSER}" --chmod=755 /src/xray /usr/local/bin/xray
COPY --from=build --chown="${NEWUSER}":"${NEWUSER}" --chmod=755 /tmp/empty /usr/local/share/xray
COPY --from=build --chown="${NEWUSER}":"${NEWUSER}" --chmod=644 /tmp/geodat/*.dat /usr/local/share/xray/
COPY --from=build --chown="${NEWUSER}":"${NEWUSER}" --chmod=755 /tmp/empty /usr/local/etc/xray
COPY --from=build --chown="${NEWUSER}":"${NEWUSER}" --chmod=644 /tmp/usr/local/etc/xray/*.json /usr/local/etc/xray/
COPY --from=build --chown="${NEWUSER}":"${NEWUSER}" --chmod=755 /tmp/empty /var/log/xray
COPY --from=build --chown="${NEWUSER}":"${NEWUSER}" --chmod=755 /tmp/var/log/xray/*.log /var/log/xray/


ARG XRAY_DIR=/usr/local/etc/xray
ARG TARGET_SERVER="www.microsoft.com"
ARG TARGET_PORT="443"


RUN mkdir -p "${XRAY_DIR}"/pki/server
RUN mkdir -p "${XRAY_DIR}"/pki/clients


COPY config.json "${XRAY_DIR}"


RUN \
    KEYS=$(/usr/local/bin/xray x25519) && \
    echo "Server KEYS:" > "${XRAY_DIR}"/pki/server/server.keys && \
    echo "$KEYS" >> "${XRAY_DIR}"/pki/server/server.keys


RUN PRIVATE_KEY=$(grep "PrivateKey:" "${XRAY_DIR}/pki/server/server.keys" | awk '{print $2}' | head -1) && \
    PUB_KEY=$(grep "Password:" "${XRAY_DIR}/pki/server/server.keys" | awk '{print $2}' | head -1) && \
    jq --arg priv "$PRIVATE_KEY" \
       --arg target "${TARGET_SERVER}:${TARGET_PORT}" \
       --arg server "${TARGET_SERVER}" \
       '.inbounds[1].streamSettings.realitySettings.privateKey = $priv | .inbounds[1].streamSettings.realitySettings.target = $target | .inbounds[1].streamSettings.realitySettings.serverNames[0] = $server' \
       "${XRAY_DIR}/config.json" > "${XRAY_DIR}/config.new.json" && \
    mv "${XRAY_DIR}/config.json" "${XRAY_DIR}/config.json.bak" && \
    mv "${XRAY_DIR}/config.new.json" "${XRAY_DIR}/config.json"

   

RUN chown -R "${NEWUSER}:${NEWUSER}" "${XRAY_DIR}"
RUN chown -R "${NEWUSER}:${NEWUSER}" /var/log/xray/


VOLUME ["${XRAY_DIR}"]
VOLUME ["/var/log/xray"]

ARG TZ=Etc/UTC
ENV TZ=$TZ

USER "${NEWUSER}"
EXPOSE 443 54321
ENTRYPOINT ["/usr/local/bin/xray"]
CMD ["-config", "/usr/local/etc/xray/config.json"]
