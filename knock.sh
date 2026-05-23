#Install package for iptables
apt install iptables-persistent
apt-get install -y ipset

#Create ip lists
ipset create knock1 hash:ip timeout 2
ipset create knock2 hash:ip timeout 2
ipset create knock_allowed hash:ip timeout 60

#Resrore iptables rules (added to existing)
iptables-restore -n ./rules.v4
