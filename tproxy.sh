#!/bin/sh

exit_func() { # doing before exit
  echo "[TProxy] Get exit signal."
  kill -15 -1 # send SIGTERM to all process

  while [ "$(ps -ef | grep -cv "PID\|ps -ef\|\[")" != "2" ] # remain itself and it's fork $(...)
  do
    usleep 10000 # wait 10ms
  done

  echo "[TProxy] All subprocess exit."
  exit
}

ipv4_tproxy() { # IPv4 tproxy settings
  ip -4 rule add fwmark 1 table 100
  ip -4 route add local 0.0.0.0/0 dev lo table 100
  iptables -t mangle -N XRAY

  echo "[TProxy] IPv4 bypass"
  for cidr in $(ip -4 addr | grep -w "inet" | awk '{print $2}') # bypass local ipv4 range
  do
    echo "[TProxy]   $cidr"
    eval "iptables -t mangle -A XRAY -d $cidr -j RETURN"
  done

  while read -r cidr # bypass custom ipv4 range
  do
    echo "[TProxy]   $cidr"
    eval "iptables -t mangle -A XRAY -d $cidr -j RETURN"
  done < /etc/xray/expose/network/bypass/ipv4

  iptables -t mangle -A XRAY -p tcp -j TPROXY --on-port 7288 --tproxy-mark 1
  iptables -t mangle -A XRAY -p udp -j TPROXY --on-port 7288 --tproxy-mark 1
  iptables -t mangle -A PREROUTING -j XRAY
}

ipv6_tproxy() { # IPv6 tproxy settings
  ip -6 rule add fwmark 1 table 106
  ip -6 route add local ::/0 dev lo table 106
  ip6tables -t mangle -N XRAY6

  echo "[TProxy] IPv6 bypass"
  for cidr in $(ip -6 addr | grep -w "inet6" | awk '{print $2}') # bypass local ipv6 range
  do
    echo "[TProxy]   $cidr"
    eval "ip6tables -t mangle -A XRAY6 -d $cidr -j RETURN"
  done

  while read -r cidr # bypass custom ipv6 range
  do
    echo "[TProxy]   $cidr"
    eval "ip6tables -t mangle -A XRAY6 -d $cidr -j RETURN"
  done < /etc/xray/expose/network/bypass/ipv6

  ip6tables -t mangle -A XRAY6 -p tcp -j TPROXY --on-port 7289 --tproxy-mark 1
  ip6tables -t mangle -A XRAY6 -p udp -j TPROXY --on-port 7289 --tproxy-mark 1
  ip6tables -t mangle -A PREROUTING -j XRAY6
}

trap exit_func 2 15 # SIGINT and SIGTERM signal

echo "[TProxy] Server start."
echo "[TProxy] Init network environment."
sh /etc/xray/load.sh
ipv4_tproxy
ipv6_tproxy
echo "[TProxy] Init complete."

echo "[TProxy] Running custom script."
custom_script="/etc/xray/expose/custom.sh"
[ -f "$custom_script" ] && sh $custom_script

echo "[TProxy] Start xray service."
xray -confdir /etc/xray/config
