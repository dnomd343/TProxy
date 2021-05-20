XRAY_DIR="/etc/xray"
LOG_DIR="$XRAY_DIR/expose/log"
load_inbounds(){
cat>$XRAY_DIR/conf/inbounds.json<<EOF
{
  "inbounds": [
    {
      "port": 7288,
      "protocol": "dokodemo-door",
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      },
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "streamSettings": {
        "sockopt": {
          "tproxy": "tproxy"
        }
      }
    },
    {
      "port": 1080,
      "protocol": "socks",
      "settings": {
        "udp": true
      }
    },
    {
      "port": 1081,
      "protocol": "http",
      "settings": {
        "allowTransparent": false
      }
    }
  ]
}
EOF
}

load_log(){
cat>$XRAY_DIR/conf/log.json<<EOF
{
  "log": {
    "loglevel": "warning",
    "access": "$LOG_DIR/access.log",
    "error": "$LOG_DIR/error.log" 
  }
}
EOF
}

load_outbounds(){
cat>$XRAY_DIR/expose/outbounds.json<<EOF
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
cat>$XRAY_DIR/expose/routing.json<<EOF
{
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "ip": [
          "0.0.0.0/0"
        ],
        "outboundTag": "node"
      }
    ]
  }
}
EOF
}

load_ipv4(){
cat>$XRAY_DIR/expose/segment/ipv4<<EOF
224.0.0.0/3
EOF
}

load_ipv6(){
cat>$XRAY_DIR/expose/segment/ipv6<<EOF
FF00::/8
EOF
}

mkdir -p $XRAY_DIR/conf
mkdir -p $XRAY_DIR/expose/segment
mkdir -p $LOG_DIR
[ ! -s "$LOG_DIR/access.log" ] && touch $LOG_DIR/access.log
[ ! -s "$LOG_DIR/error.log" ] && touch $LOG_DIR/error.log
load_inbounds
load_log
[ ! -s "$XRAY_DIR/expose/outbounds.json" ] && load_outbounds
[ ! -s "$XRAY_DIR/expose/routing.json" ] && load_routing
cp $XRAY_DIR/expose/outbounds.json $XRAY_DIR/conf/
cp $XRAY_DIR/expose/routing.json $XRAY_DIR/conf/
[ ! -s "$XRAY_DIR/expose/segment/ipv4" ] && load_ipv4
[ ! -s "$XRAY_DIR/expose/segment/ipv6" ] && load_ipv6