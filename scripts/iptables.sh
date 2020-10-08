#!/bin/bash
# Script to Enable $IPTABLES
#
# Add $IPSET for multiple
# Setup rules for multiple configs..simplify it
# chains?

# Add Variables for system configurations
# SYSTEMIP
# DNS1 / DNS2
# SQUID VIP
# NET ACL
# MULTI INET?
date=`date`
echo "$0 Started...$date" >> /var/log/iptables.sh.log
IPTABLES='/usr/sbin/iptables'
IPSET='/usr/sbin/ipset'
SYSTEMIP=`hostname -I | awk '{print $1}'`
SRCSUBNET="10.0.0.0/8"
EM10="10.0.0.0/8"
TANIUMENDZONE="199.189.124.193/32"
WORLD="0.0.0.0/0"
DNSARRAY=`grep nameserver /etc/resolv.conf  | awk '{print $2}'`
#ADARRAY="10.110.39.11 10.110.39.12 10.130.39.11 10.130.39.12 10.190.39.11 10.190.39.12"
CUSTOMLIST="/opt/iptables/ips.txt"
CLIENTACL="/opt/iptables/clientacl.txt"
DOMAINACL="/opt/iptables/domains.txt"
SQUIDVIP="/opt/iptables/squidvip.txt"
ACLARRAY="$CUSTOMLIST $CLIENTACL $DOMAINACL $SQUIDVIP"
for LIST in ${ACLARRAY[@]}; do
	touch $LIST
done
#echo "DESTROY"
systemctl stop iptables
$IPTABLES -F
$IPSET destroy

#### IPSET
$IPSET create squidvip hash:ip > /dev/null 2>&1
$IPSET create squidvip_temp hash:ip > /dev/null 2>&1
for vip in $(cat $SQUIDVIP); do
	#echo "SquidVIP: $SQUIDVIP";
	$IPSET add squidvip_temp $vip > /dev/null 2>&1
done
$IPSET flush squidvip
$IPSET swap squidvip_temp squidvip
$IPSET destroy squidvip_temp


# Create ClientACL list to of sites to connect to if it doesn't exist
$IPSET create ClientACL nethash hashsize 16384 > /dev/null 2>&1
$IPSET create ClientACL_temp nethash hashsize 16384 > /dev/null 2>&1
#echo "### CLientACL: /opt/iptables/clientacl.txt ###"
for address in $(cat $CLIENTACL); do
	#echo "ClientACL IP: $address";
	$IPSET add ClientACL_temp $address > /dev/null 2>&1
done

$IPSET flush ClientACL
$IPSET swap ClientACL_temp ClientACL > /dev/null 2>&1
$IPSET destroy ClientACL_temp

# CrowdStrike
$IPSET create crowdstrike hash:ip
$IPSET create crowdstrike_temp hash:ip

for csaddress in $(dig ts01-b.cloudsink.net lfodown01-b.cloudsink.net. +short | grep -v cloud); do
    	#echo "CS ADDRESS: $csaddress";
	$IPSET add crowdstrike_temp $csaddress
done
$IPSET flush crowdstrike
$IPSET swap crowdstrike_temp crowdstrike
$IPSET destroy crowdstrike_temp

# Create CustomSite list to of sites to connect to if it doesn't exist
$IPSET create CustomSites hash:ip
$IPSET create CustomSites_temp hash:ip
DOMAINARRAY=()
for entry in `cat $DOMAINACL` ;do
        DOMAINARRAY=$(dig a $entry +short | grep -vP [a-zA-Z]);
	#echo "DOMARRAY1: -> $DOMAINARRAY"
	$IPSET add CustomSites_temp $DOMAINARRAY > /dev/null 2>&1
done


$IPSET flush CustomSites
$IPSET swap CustomSites_temp CustomSites > /dev/null 2>&1
$IPSET destroy CustomSites_temp > /dev/null 2>&1

## Now start with the basics!
$IPTABLES -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
#$IPTABLES -A INPUT -p icmp -j ACCEPT
$IPTABLES -A INPUT -p icmp -j ACCEPT
$IPTABLES -A INPUT -i lo -j ACCEPT
$IPTABLES -A OUTPUT -o lo -j ACCEPT
$IPTABLES -A OUTPUT -p icmp -j ACCEPT
#$IPTABLES -A OUTPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# DNS
for DNSSERVER in ${DNSARRAY[@]}; do
	$IPTABLES -A INPUT -p udp -s $DNSSERVER --sport 53 -m state --state ESTABLISHED,RELATED -j ACCEPT
	$IPTABLES -A INPUT -p tcp -s $DNSSERVER --sport 53 -m state --state ESTABLISHED,RELATED -j ACCEPT
	$IPTABLES -A OUTPUT -p udp -d $DNSSERVER --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
	$IPTABLES -A OUTPUT -p tcp -d $DNSSERVER --dport 53 -m state --state NEW,ESTABLISHED -j ACCEPT
done

# SSH
#$IPTABLES -A INPUT -m set --match-set blocklist src -j LOG --log-prefix "DENIED:"
#$IPTABLES -A INPUT -m set --match-set blocklist src -j REJECT --reject-with icmp-host-prohibited
$IPTABLES -A INPUT -p tcp -s $EM10 --dport 22 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -s $EM10 --sport 22 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -s $SYSTEMIP --sport 22 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# NTP
$IPTABLES -A INPUT -p udp -m udp -s 169.254.169.123 --sport 123 -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -p udp -m udp -d 169.254.169.123 --dport 123 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# AD AUTH,
## Multiports
for ADSERVER in ${ADARRAY[@]}; do
	$IPTABLES -A OUTPUT -p tcp -m tcp -s $ADSERVER -m state --state NEW,ESTABLISHED,RELATED --dport 88 -j ACCEPT
	$IPTABLES -A OUTPUT -p tcp -m tcp -s 169.254.169.254 -m state --state NEW,ESTABLISHED,RELATED --dport 88 -j ACCEPT
	$IPTABLES -A OUTPUT -p udp -m udp -s $EM10  -m state --state NEW,ESTABLISHED,RELATED --dport 67 -j ACCEPT
	$IPTABLES -A OUTPUT -p tcp -m tcp -s $ADSERVER -m state --state NEW,ESTABLISHED,RELATED --dport 135 -j ACCEPT
	$IPTABLES -A OUTPUT -p tcp -m tcp -s $ADSERVER -m state --state NEW,ESTABLISHED,RELATED --dport 137 -j ACCEPT
	$IPTABLES -A OUTPUT -p tcp -m tcp -s $ADSERVER -m state --state NEW,ESTABLISHED,RELATED --dport 139 -j ACCEPT
	$IPTABLES -A OUTPUT -p tcp -m tcp -s $ADSERVER -m state --state NEW,ESTABLISHED,RELATED --dport 389 -j ACCEPT
	$IPTABLES -A OUTPUT -p tcp -m tcp -s $ADSERVER -m state --state NEW,ESTABLISHED,RELATED --dport 445 -j ACCEPT
	$IPTABLES -A OUTPUT -p tcp -m tcp -s $ADSERVER -m state --state NEW,ESTABLISHED,RELATED --dport 3268 -j ACCEPT
	$IPTABLES -A OUTPUT -p tcp -m tcp -s $ADSERVER -m state --state NEW,ESTABLISHED,RELATED --dport 3269 -j ACCEPT
# UDP
	$IPTABLES -A OUTPUT -p udp -m udp -s $ADSERVER -m state --state NEW,ESTABLISHED,RELATED --dport 135 -j ACCEPT
	$IPTABLES -A OUTPUT -p udp -m udp -s $ADSERVER -m state --state NEW,ESTABLISHED,RELATED --dport 137 -j ACCEPT
	$IPTABLES -A OUTPUT -p udp -m udp -s $ADSERVER -m state --state NEW,ESTABLISHED,RELATED --dport 139 -j ACCEPT
	$IPTABLES -A OUTPUT -p udp -m udp -s $ADSERVER -m state --state NEW,ESTABLISHED,RELATED --dport 445 -j ACCEPT

done

# SQUID
$IPTABLES -A INPUT -p tcp -d $SYSTEMIP --dport 3128 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A INPUT -p tcp -m set --match-set ClientACL src --dport 3128 -j ACCEPT
$IPTABLES -A INPUT -p tcp -m set --match-set squidvip src --dport 3128 -j ACCEPT
#$IPTABLES -A INPUT -p tcp -s $SRCSUBNET --dport 3128 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -s $SYSTEMIP  --sport 3128 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -s $SYSTEMIP  --dport 3128 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -o lo -p tcp -m tcp --dport 3128 -j ACCEPT

# Tanium
$IPTABLES -A INPUT -p tcp --sport 17472 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp --dport 17472 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

# LogRhythm Cluster
$IPTABLES -A INPUT -p tcp -m tcp -d 10.193.27.0/24 --sport 443 -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A INPUT -p tcp -m tcp -d 35.155.113.167/32 --sport 443 -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp -d 10.193.27.0/24 --dport 443 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp -d 35.155.113.167/32 --dport 443 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT

$IPTABLES -A INPUT -p tcp -m tcp --sport 443 -j ACCEPT

# CustomSite
#$IPTABLES -A OUTPUT -p tcp -m set --match-set CustomSites dst -j LOG --log-prefix "CustomSites OUT:"
$IPTABLES -A INPUT -p tcp -m set --match-set CustomSites src --sport 443 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m set --match-set CustomSites dst --dport 443 -j ACCEPT
$IPTABLES -A INPUT -p tcp -m set --match-set CustomSites src --sport 80 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m set --match-set CustomSites dst --dport 80 -j ACCEPT
# Amazon SSM
$IPTABLES -A OUTPUT -p tcp -m tcp -d 52.119.169.59 --dport 80 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp -d 52.119.169.59 --dport 443 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp -d 52.119.162.189 --dport 443 -j ACCEPT


# CrowdStrike
#$IPTABLES -A OUTPUT -p tcp -m set --match-set crowdstrike dst -j LOG --log-prefix "CROWDSTRIKE OUT:"
$IPTABLES -A OUTPUT -p tcp -m set --match-set crowdstrike dst --dport 443 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m set --match-set crowdstrike dst --dport 80 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp -d 169.254.169.254/32 --dport 80 -j ACCEPT

#Twistlock
$IPTABLES -A INPUT -p tcp -m tcp -s 35.233.225.166 --sport 443 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp -d 35.233.225.166 --dport 443 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp -d 52.218.176.88 --dport 80 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp -d 10.0.0.0/8 --dport 514 -j ACCEPT

# Outbound to icanhazip
$IPTABLES -A OUTPUT -p tcp -m tcp -d 116.202.55.106 --dport 443 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp -d 116.202.244.153 --dport 443 -j ACCEPT

#Outbound to Amazon updates
$IPTABLES -A OUTPUT -p tcp -m tcp -d 52.218.201.104 --dport 443 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp -d 52.218.238.24 --dport 80 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp -d 52.218.160.68 --dport 80 -j ACCEPT
$IPTABLES -A OUTPUT -p tcp -m tcp -d 52.218.238.8 --dport 80 -j ACCEPT
# Outbound to Qualys
$IPTABLES -A OUTPUT -p tcp -m tcp -d 64.39.96.0/20 --dport 443 -j ACCEPT

# Zabbix
$IPTABLES -A INPUT -p tcp -s 10.190.39.212 -m tcp --dport 10050 -j ACCEPT
$IPTABLES -A INPUT -p tcp -s 10.110.39.243 -m tcp --dport 10050 -j ACCEPT
$IPTABLES -A INPUT -p tcp -s 10.130.39.243 -m tcp --dport 10050 -j ACCEPT
$IPTABLES -A INPUT -p tcp -s 10.190.39.240 -m tcp --dport 10050 -j ACCEPT
$IPTABLES -A INPUT -p tcp -s 10.110.39.241 -m tcp --dport 10050 -j ACCEPT
$IPTABLES -A INPUT -p tcp -s 10.130.39.241 -m tcp --dport 10050 -j ACCEPT
$IPTABLES -A INPUT -p tcp -s 10.111.39.242 -m tcp --dport 10050 -j ACCEPT
$IPTABLES -A INPUT -p tcp -s 10.190.39.242 -m tcp --dport 10050 -j ACCEPT

#### DROP ALL OTHER INPUT
$IPTABLES -A INPUT -j LOG --log-prefix "INPUT DROPPED:"
$IPTABLES -A INPUT -j REJECT --reject-with icmp-host-prohibited

#### DROP ALL OTHER FORWARDING
$IPTABLES -A FORWARD -j REJECT --reject-with icmp-host-prohibited

#### REJECT/DROP ALL OTHER OUTPUT BASED ON ENVIRONMENT
$IPTABLES -A OUTPUT -j LOG --log-prefix "OUTPUT DROPPED:"
$IPTABLES -A OUTPUT -j REJECT --reject-with icmp-host-prohibited
#$IPTABLES -A OUTPUT -j DROP

/usr/sbin/iptables-save > /etc/sysconfig/iptables
/usr/bin/systemctl start iptables
