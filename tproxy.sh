#!/bin/sh
trap "echo \"Get exit signal\" && exit" 2 15
[ -f "/etc/xray/expose/custom.sh" ] && sh /etc/xray/expose/custom.sh

# IPv4 tproxy settings
ip -4 rule add fwmark 1 table 100
ip -4 route add local 0.0.0.0/0 dev lo table 100
iptables -t mangle -N XRAY

for cidr in $(ip -4 addr | grep -w "inet" | awk '{print $2}') # bypass local ipv4 range
do
  eval "iptables -t mangle -A XRAY -d $cidr -j RETURN"
done

while read -r cidr # bypass custom ipv4 range
do
  eval "iptables -t mangle -A XRAY -d $cidr -j RETURN"
done < /etc/xray/expose/network/bypass/ipv4

iptables -t mangle -A XRAY -p tcp -j TPROXY --on-port 7288 --tproxy-mark 1
iptables -t mangle -A XRAY -p udp -j TPROXY --on-port 7288 --tproxy-mark 1
iptables -t mangle -A PREROUTING -j XRAY

# IPv6 tproxy settings
ip -6 rule add fwmark 1 table 106
ip -6 route add local ::/0 dev lo table 106
ip6tables -t mangle -N XRAY6

for cidr in $(ip -6 addr | grep -w "inet6" | awk '{print $2}') # bypass local ipv6 range
do
  eval "ip6tables -t mangle -A XRAY6 -d $cidr -j RETURN"
done

while read -r cidr # bypass custom ipv6 range
do
  eval "ip6tables -t mangle -A XRAY6 -d $cidr -j RETURN"
done < /etc/xray/expose/network/bypass/ipv6

ip6tables -t mangle -A XRAY6 -p tcp -j TPROXY --on-port 7289 --tproxy-mark 1
ip6tables -t mangle -A XRAY6 -p udp -j TPROXY --on-port 7289 --tproxy-mark 1
ip6tables -t mangle -A PREROUTING -j XRAY6

sh /etc/xray/load.sh
xray -confdir /etc/xray/config/ # start xray server
