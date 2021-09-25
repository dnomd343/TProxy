XRAY_DIR="/etc/xray"
LOG_DIR="$XRAY_DIR/expose/log"
ASSET_DIR="$XRAY_DIR/expose/asset"
CONFIG_DIR="$XRAY_DIR/expose/config"

load_log(){
log_level=`cat $LOG_DIR/level`
legal=false
[ "$log_level" == "debug" ] && legal=true
[ "$log_level" == "info" ] && legal=true
[ "$log_level" == "warning" ] && legal=true
[ "$log_level" == "error" ] && legal=true
[ "$log_level" == "none" ] && legal=true
[ "$legal" == false ] && log_level="warning"
cat>$XRAY_DIR/config/log.json<<EOF
{
  "log": {
    "loglevel": "$log_level",
    "access": "$LOG_DIR/access.log",
    "error": "$LOG_DIR/error.log"
  }
}
EOF
}

load_inbounds(){
cat>$XRAY_DIR/config/inbounds.json<<EOF
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
    },
    {
      "tag": "proxy",
      "port": 10808,
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
    }
  ]
}
EOF
}

load_outbounds(){
cat>$CONFIG_DIR/outbounds.json<<EOF
{
  "outbounds": [
    {
      "tag": "node",
      "protocol": "freedom"
    }
  ]
}
EOF
}

load_routing(){
cat>$CONFIG_DIR/routing.json<<EOF
{
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "proxy"
        ],
        "outboundTag": "node"
      },
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


load_dns(){
cat>$CONFIG_DIR/dns.json<<EOF
{
  "dns": {
    "servers": [
      "localhost"
    ]
  }
}
EOF
}

load_asset_update(){
cat>$ASSET_DIR/update.sh<<"EOF"
GITHUB="github.com"
ASSET_REPO="Loyalsoldier/v2ray-rules-dat"
VERSION=$(curl --silent "https://api.github.com/repos/$ASSET_REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/');
mkdir -p ./temp/
wget -P ./temp/ "https://$GITHUB/$ASSET_REPO/releases/download/$VERSION/geoip.dat"
file_size=`du ./temp/geoip.dat | awk '{print $1}'`
[ $file_size != "0" ] && mv -f ./temp/geoip.dat ./
wget -P ./temp/ "https://$GITHUB/$ASSET_REPO/releases/download/$VERSION/geosite.dat"
file_size=`du ./temp/geosite.dat | awk '{print $1}'`
[ $file_size != "0" ] && mv -f ./temp/geosite.dat ./
rm -rf ./temp/
EOF
chmod +x $ASSET_DIR/update.sh
}

load_ipv4(){
cat>$XRAY_DIR/expose/segment/ipv4<<EOF
127.0.0.0/8
169.254.0.0/16
224.0.0.0/3
EOF
}

load_ipv6(){
cat>$XRAY_DIR/expose/segment/ipv6<<EOF
::1/128
FC00::/7
FE80::/10
FF00::/8
EOF
}

mkdir -p $XRAY_DIR/config
mkdir -p $XRAY_DIR/expose/segment
mkdir -p $LOG_DIR
mkdir -p $ASSET_DIR
mkdir -p $CONFIG_DIR

[ ! -s "$LOG_DIR/access.log" ] && touch $LOG_DIR/access.log
[ ! -s "$LOG_DIR/error.log" ] && touch $LOG_DIR/error.log

load_log
load_inbounds
[ ! -s "$CONFIG_DIR/outbounds.json" ] && load_outbounds
[ ! -s "$CONFIG_DIR/routing.json" ] && load_routing
[ ! -s "$CONFIG_DIR/dns.json" ] && load_dns
cp $CONFIG_DIR/*.json $XRAY_DIR/config/

[ ! -s "$ASSET_DIR/geoip.dat" ] && cp $XRAY_DIR/asset/geoip.dat $ASSET_DIR/
[ ! -s "$ASSET_DIR/geosite.dat" ] && cp $XRAY_DIR/asset/geosite.dat $ASSET_DIR/
[ ! -s "$ASSET_DIR/update.sh" ] && load_asset_update
cp $ASSET_DIR/*.dat $XRAY_DIR/asset/

[ ! -s "$XRAY_DIR/expose/segment/ipv4" ] && load_ipv4
[ ! -s "$XRAY_DIR/expose/segment/ipv6" ] && load_ipv6
