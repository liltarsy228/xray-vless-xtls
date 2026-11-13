#Install package for iptables
apt-get install -y ipset  iptables-persistent

#Create ip lists
ipset create knock1 hash:ip timeout 2
ipset create knock2 hash:ip timeout 2
ipset create knock_allowed hash:ip timeout 60
ipset create knock_admin_panel_allowed hash:ip timeout 1200 -exist
#Resrore iptables rules (added to existing)
iptables-restore -n ./rules.v4
