XRAY_DIR="/etc/xray"
LOG_DIR="$XRAY_DIR/expose/log"
ASSET_DIR="$XRAY_DIR/expose/asset"
CONFIG_DIR="$XRAY_DIR/expose/config"
NETWORK_DIR="$XRAY_DIR/expose/network"

load_xray_log() {
  if [ -f "$LOG_DIR/level" ]; then
    log_level=$(cat $LOG_DIR/level)
  else
    log_level="warning"
  fi
  legal=false
  [ "$log_level" == "debug" ] && legal=true
  [ "$log_level" == "info" ] && legal=true
  [ "$log_level" == "warning" ] && legal=true
  [ "$log_level" == "error" ] && legal=true
  [ "$log_level" == "none" ] && legal=true
  [ "$legal" == false ] && log_level="warning"
  if [ "$log_level" != "none" ]; then
    [ ! -f "$LOG_DIR/access.log" ] && touch $LOG_DIR/access.log
    [ ! -f "$LOG_DIR/error.log" ] && touch $LOG_DIR/error.log
  fi
  cat > $XRAY_DIR/config/log.json << EOF
{
  "log": {
    "loglevel": "$log_level",
    "access": "$LOG_DIR/access.log",
    "error": "$LOG_DIR/error.log"
  }
}
EOF
}

load_xray_inbounds() {
  cat > $XRAY_DIR/config/inbounds.json << EOF
{
  "inbounds": [
    {
      "tag": "tproxy",
      "port": 7288,
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "streamSettings": {
        "sockopt": {
          "tproxy": "tproxy"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },
    {
      "tag": "tproxy6",
      "port": 7289,
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "streamSettings": {
        "sockopt": {
          "tproxy": "tproxy"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },
    {
      "tag": "socks",
      "port": 1080,
      "protocol": "socks",
      "settings": {
        "udp": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    },
    {
      "tag": "http",
      "port": 1081,
      "protocol": "http",
      "settings": {
        "allowTransparent": false
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      }
    }
  ]
}
EOF
}

load_xray_dns() {
  cat > $CONFIG_DIR/dns.json << EOF
{
  "dns": {
    "servers": [
      "localhost"
    ]
  }
}
EOF
}

load_xray_outbounds() {
  cat > $CONFIG_DIR/outbounds.json << EOF
{
  "outbounds": [
    {
      "tag": "node",
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
EOF
}

load_xray_routing() {
  cat > $CONFIG_DIR/routing.json << EOF
{
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "node"
      }
    ]
  }
}
EOF
}

load_update_script() {
  cat > $ASSET_DIR/update.sh << "EOF"
mkdir temp/ && cd temp/
wget "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat"
wget "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"
[ -s "geoip.dat" ] && mv -f geoip.dat ../
[ -s "geosite.dat" ] && mv -f geosite.dat ../
cd ../ && rm -rf temp/
EOF
  chmod +x $ASSET_DIR/update.sh
}

load_radvd_conf() {
  cat > $NETWORK_DIR/radvd/config << EOF
AdvSendAdvert=on
AdvManagedFlag=off
AdvOtherConfigFlag=off

MinRtrAdvInterval=10
MaxRtrAdvInterval=30
MinDelayBetweenRAs=3

AdvOnLink=on
AdvAutonomous=on
AdvRouterAddr=off
AdvValidLifetime=600
AdvPreferredLifetime=100
EOF
}

load_bypass_ipv4() {
  cat > $NETWORK_DIR/bypass/ipv4 << EOF
169.254.0.0/16
224.0.0.0/3
EOF
}

load_bypass_ipv6() {
  cat > $NETWORK_DIR/bypass/ipv6 << EOF
fc00::/7
fe80::/10
ff00::/8
EOF
}

load_network_ipv4() {
  cat > $NETWORK_DIR/interface/ipv4 << EOF
ADDRESS=
GATEWAY=
FORWARD=true
EOF
}

load_network_ipv6() {
  cat > $NETWORK_DIR/interface/ipv6 << EOF
ADDRESS=
GATEWAY=
FORWARD=true
EOF
}

init_dns() {
  cat /dev/null > /etc/resolv.conf
  while read -r row
  do
    echo "nameserver $row" >> /etc/resolv.conf
  done < $NETWORK_DIR/dns
}

init_network() {
  ifconfig eth0 down
  ip -4 addr flush dev eth0
  ip -6 addr flush dev eth0
  ifconfig eth0 up
  while read -r row
  do
    temp=${row#ADDRESS=}
    [ "$row" != "$temp" ] && ipv4_address=$temp
    temp=${row#GATEWAY=}
    [ "$row" != "$temp" ] && ipv4_gateway=$temp
    temp=${row#FORWARD=}
    [ "$row" != "$temp" ] && ipv4_forward=$temp
  done < $NETWORK_DIR/interface/ipv4
  [ -n "$ipv4_address" ] && eval "ip -4 addr add $ipv4_address dev eth0"
  [ -n "$ipv4_gateway" ] && eval "ip -4 route add default via $ipv4_gateway"
  if [ -n "$ipv4_forward" ]; then
    if [ "$ipv4_forward" = "true" ]; then
      eval "sysctl -w net.ipv4.ip_forward=1"
    else
      eval "sysctl -w net.ipv4.ip_forward=0"
    fi
  fi
  while read -r row
  do
    temp=${row#ADDRESS=}
    [ "$row" != "$temp" ] && ipv6_address=$temp
    temp=${row#GATEWAY=}
    [ "$row" != "$temp" ] && ipv6_gateway=$temp
    temp=${row#FORWARD=}
    [ "$row" != "$temp" ] && ipv6_forward=$temp
  done < $NETWORK_DIR/interface/ipv6
  [ -n "$ipv6_address" ] && eval "ip -6 addr add $ipv6_address dev eth0"
  [ -n "$ipv6_gateway" ] && eval "ip -6 route add default via $ipv6_gateway"
  if [ -n "$ipv6_forward" ]; then
    if [ "$ipv6_forward" = "true" ]; then
      eval "sysctl -w net.ipv6.conf.all.forwarding=1"
    else
      eval "sysctl -w net.ipv6.conf.all.forwarding=0"
    fi
  fi
}

init_radvd() {
  while read -r row
  do
    temp=${row#AdvSendAdvert=}
    [ "$row" != "$temp" ] && AdvSendAdvert=$temp
    temp=${row#AdvManagedFlag=}
    [ "$row" != "$temp" ] && AdvManagedFlag=$temp
    temp=${row#AdvOtherConfigFlag=}
    [ "$row" != "$temp" ] && AdvOtherConfigFlag=$temp
    temp=${row#MinRtrAdvInterval=}
    [ "$row" != "$temp" ] && MinRtrAdvInterval=$temp
    temp=${row#MaxRtrAdvInterval=}
    [ "$row" != "$temp" ] && MaxRtrAdvInterval=$temp
    temp=${row#MinDelayBetweenRAs=}
    [ "$row" != "$temp" ] && MinDelayBetweenRAs=$temp
    temp=${row#AdvOnLink=}
    [ "$row" != "$temp" ] && AdvOnLink=$temp
    temp=${row#AdvAutonomous=}
    [ "$row" != "$temp" ] && AdvAutonomous=$temp
    temp=${row#AdvRouterAddr=}
    [ "$row" != "$temp" ] && AdvRouterAddr=$temp
    temp=${row#AdvValidLifetime=}
    [ "$row" != "$temp" ] && AdvValidLifetime=$temp
    temp=${row#AdvPreferredLifetime=}
    [ "$row" != "$temp" ] && AdvPreferredLifetime=$temp
  done < $NETWORK_DIR/radvd/config

  RADVD_CONF="/etc/radvd.conf"
  echo "interface eth0 {" > $RADVD_CONF
  [ -n "$AdvSendAdvert" ] && echo "    AdvSendAdvert $AdvSendAdvert;" >> $RADVD_CONF
  [ -n "$AdvManagedFlag" ] && echo "    AdvManagedFlag $AdvManagedFlag;" >> $RADVD_CONF
  [ -n "$AdvOtherConfigFlag" ] && echo "    AdvOtherConfigFlag $AdvOtherConfigFlag;" >> $RADVD_CONF
  [ -n "$MinRtrAdvInterval" ] && echo "    MinRtrAdvInterval $MinRtrAdvInterval;" >> $RADVD_CONF
  [ -n "$MaxRtrAdvInterval" ] && echo "    MaxRtrAdvInterval $MaxRtrAdvInterval;" >> $RADVD_CONF
  [ -n "$MinDelayBetweenRAs" ] && echo "    MinDelayBetweenRAs $MinDelayBetweenRAs;" >> $RADVD_CONF
  if [ -n "$ipv6_address" ]; then
    echo "    prefix $ipv6_address {" >> $RADVD_CONF
    [ -n "$AdvOnLink" ] && echo "        AdvOnLink $AdvOnLink;" >> $RADVD_CONF
    [ -n "$AdvAutonomous" ] && echo "        AdvAutonomous $AdvAutonomous;" >> $RADVD_CONF
    [ -n "$AdvRouterAddr" ] && echo "        AdvRouterAddr $AdvRouterAddr;" >> $RADVD_CONF
    [ -n "$AdvValidLifetime" ] && echo "        AdvValidLifetime $AdvValidLifetime;" >> $RADVD_CONF
    [ -n "$AdvPreferredLifetime" ] && echo "        AdvPreferredLifetime $AdvPreferredLifetime;" >> $RADVD_CONF
    echo "    };" >> $RADVD_CONF
  fi
  echo "};" >> $RADVD_CONF
  radvd -C $RADVD_CONF
}

mkdir -p $LOG_DIR
mkdir -p $ASSET_DIR
mkdir -p $CONFIG_DIR
mkdir -p $NETWORK_DIR
mkdir -p $XRAY_DIR/config

load_xray_log
load_xray_inbounds
[ ! -s "$CONFIG_DIR/outbounds.json" ] && load_xray_outbounds
[ ! -s "$CONFIG_DIR/routing.json" ] && load_xray_routing
[ ! -s "$CONFIG_DIR/dns.json" ] && load_xray_dns
cp $CONFIG_DIR/*.json $XRAY_DIR/config/

tar -C $XRAY_DIR -xf $XRAY_DIR/asset.tar.gz
[ ! -s "$ASSET_DIR/geoip.dat" ] && cp $XRAY_DIR/asset/geoip.dat $ASSET_DIR/
[ ! -s "$ASSET_DIR/geosite.dat" ] && cp $XRAY_DIR/asset/geosite.dat $ASSET_DIR/
[ ! -s "$ASSET_DIR/update.sh" ] && load_update_script
cp $ASSET_DIR/*.dat $XRAY_DIR/asset/

mkdir -p $NETWORK_DIR/radvd
mkdir -p $NETWORK_DIR/bypass
mkdir -p $NETWORK_DIR/interface
[ -s "$NETWORK_DIR/dns" ] && init_dns
[ ! -f "$NETWORK_DIR/bypass/ipv4" ] && load_bypass_ipv4
[ ! -f "$NETWORK_DIR/bypass/ipv6" ] && load_bypass_ipv6

if [ ! -f "$NETWORK_DIR/interface/ignore" ]; then
  [ ! -s "$NETWORK_DIR/interface/ipv4" ] && load_network_ipv4
  [ ! -s "$NETWORK_DIR/interface/ipv6" ] && load_network_ipv6
  init_network
fi

if [ ! -f "$NETWORK_DIR/radvd/ignore" ]; then
  [ ! -s "$NETWORK_DIR/radvd/config" ] && load_radvd_conf
  init_radvd
fi
