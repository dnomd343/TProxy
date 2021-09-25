[ -f "/etc/xray/expose/custom.sh" ] && sh /etc/xray/expose/custom.sh
sh /etc/xray/load.sh

ip -4 rule add fwmark 1 table 100
ip -4 route add local 0.0.0.0/0 dev lo table 100
iptables -t mangle -N XRAY
ip -4 addr | grep -w "inet" | awk '{print $2}' > /ipv4_range
while read -r segment
do
  eval "iptables -t mangle -A XRAY -d $segment -j RETURN"
done < /ipv4_range
rm -f /ipv4_range
while read -r segment
do
  eval "iptables -t mangle -A XRAY -d $segment -j RETURN"
done < /etc/xray/expose/network/bypass/ipv4
iptables -t mangle -A XRAY -p tcp -j TPROXY --on-port 7288 --tproxy-mark 1
iptables -t mangle -A XRAY -p udp -j TPROXY --on-port 7288 --tproxy-mark 1
iptables -t mangle -A PREROUTING -j XRAY

ip -6 rule add fwmark 1 table 106
ip -6 route add local ::/0 dev lo table 106
ip6tables -t mangle -N XRAY6
ip -6 addr | grep -w "inet6" | awk '{print $2}' > /ipv6_range
while read -r segment
do
  eval "ip6tables -t mangle -A XRAY6 -d $segment -j RETURN"
done < /ipv6_range
rm -f /ipv6_range
while read -r segment
do
  eval "ip6tables -t mangle -A XRAY6 -d $segment -j RETURN"
done < /etc/xray/expose/network/bypass/ipv6
ip6tables -t mangle -A XRAY6 -p tcp -j TPROXY --on-port 7289 --tproxy-mark 1
ip6tables -t mangle -A XRAY6 -p udp -j TPROXY --on-port 7289 --tproxy-mark 1
ip6tables -t mangle -A PREROUTING -j XRAY6

xray -confdir /etc/xray/config/
