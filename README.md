# TProxy

容器化的旁路由透明代理工具，使用Xray处理TProxy流量，实现独立MAC与IP地址的虚拟化代理网关，支持 `amd64`、`i386`、`arm64`、`armv7` 多种CPU架构，可代理全部TCP和UDP流量。

TProxy使用Docker容器化部署，在[Docker Hub](https://hub.docker.com/repository/docker/dnomd343/tproxy)或[Github Package](https://github.com/dnomd343/TProxy/pkgs/container/tproxy)可以查看已构建的镜像。

## 镜像获取

Docker镜像建议拉取 `latest` 版本，如果需要特定版本镜像，拉取时指定tag为版本号即可。

```
# latest版本
shell> docker pull dnomd343/tproxy

# 指定版本
shell> docker pull dnomd343/tproxy:v1.1
```

TProxy可以从多个镜像源拉取，其数据完全相同，国内用户建议首选阿里云镜像。

```
# Docker Hub
shell> docker pull docker.io/dnomd343/tproxy

# Github Package
shell> docker pull ghcr.io/dnomd343/tproxy

# 阿里云个人镜像
shell> docker pull registry.cn-shenzhen.aliyuncs.com/dnomd343/tproxy
```

## 开始部署

首先开启网卡混杂模式

```
shell> ip link set eth0 promisc on
```

创建 `macvlan` 网络

```
# 此处网段与网关信息需按实际网络指定
shell> docker network create -d macvlan \
--subnet=192.168.2.0/24 \
--gateway=192.168.2.1 \
-o parent=eth0 macvlan
```

选择一个目录存储数据，此处使用 `/etc/scutweb`

```
shell> mkdir /etc/scutweb
shell> cd /etc/scutweb
shell> vim custom.sh
```

`custom.sh` 将在容器启动时首先执行，可用于指定容器静态IP与主路由网关地址

```
# 指定网关为192.168.2.1，容器IP为192.168.2.2
ip addr flush dev eth0
ip addr add 192.168.2.2/24 brd 192.168.2.255 dev eth0
ip route add default via 192.168.2.1
```

由于TProxy只代理传输层TCP与UDP以上的流量，网络层及以下其他数据包将不被处理，其中最常见的是ICMP数据包，表现为ping流量不走代理。但可以在 `custom.sh` 中添加以下命令，回应所有发往外网的ICMP数据包，表现为ping成功且延迟为内网访问时间（ICMP数据包实际未到达，使用NAT方式假冒远程主机返回到达信息）

```
# DNAT目标指定为自身IP地址
iptables -t nat -N FAKE_PING
iptables -t nat -A FAKE_PING -j DNAT --to-destination 192.168.2.2
iptables -t nat -A PREROUTING -i eth0 -p icmp -j FAKE_PING
```

启动容器，此处映射时间与时区信息到容器中，可以与宿主机进行同步（容器内默认为UTC零时区），用于日志时间记录

```
# 容器名称和存储目录可自行指定
shell> docker run --restart always \
--name scutweb \
--network macvlan \
--privileged -d \
--volume /etc/scutweb/:/etc/xray/expose/ \
--volume /etc/timezone:/etc/timezone:ro \
--volume /etc/localtime:/etc/localtime:ro \
dnomd343/tproxy
# 此处为DockerHub镜像源，可按上文链接替换为其他源
```

使用以下命令查看容器运行状态

```
shell> docker ps -a
```

容器成功运行以后，将会在存储目录下生成多个文件和文件夹

+ `log`：文件夹，存储代理流量日志

+ `segment`：文件夹，存储不代理的网段信息

+ `outbounds.json`：指定流量出口信息

+ `routeing.json`：指定流量路由信息

`outbounds.json` 默认配置流量转发给网关，需要用户手动配置为上游接口，具体语法见[Xray文档](https://xtls.github.io/config/base/outbounds/)

```
{
  "outbounds": [
    {
      "tag": "node",
      "protocol": "freedom"
    }
  ]
}
```

`routing.json` 默认配置将全部流量交由 `node` 接口，即 `outbounds.json` 中的 `freedom` 出口，具体语法见[Xray文档](https://xtls.github.io/config/base/routing/)

```
{
  "routing": {
    "domainStrategy": "IPIfNonMatch",
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
        "network": "tcp,udp"
        "outboundTag": "node"
      }
    ]
  }
}
```

`dns.json` 指定路由匹配时的DNS服务器，具体语法见[Xray文档](https://xtls.github.io/config/base/dns/)

```
{
  "dns": {
    "servers": [
      "223.5.5.5",
      "119.29.29.29"
    ]
  }
}
```

`segment` 文件夹下默认有 `ipv4` 与 `ipv6` 两个文件，其中存储不代理的网段信息，建议绕过内网地址、本地回环地址、链路本地地址、组播地址等网段

```
# IPv4与IPv6均默认绕过组播地址
shell> cat /etc/scutweb/segment/ipv4
127.0.0.0/8
169.254.0.0/16
224.0.0.0/3
shell> cat /etc/scutweb/segment/ipv6
::1/128
FC00::/7
FE80::/10
FF00::/8
```

配置完成后重启容器生效

```
shell> docker restart scutweb
```

此时宿主机无法与macvlan网络直接连接，需要手动配置桥接，这里以Debian系Linux发行版为例

```
shell> vim /etc/network/interfaces
```

补充如下配置

```
# 具体网络信息需要按实际情况指定
auto eth0
iface eth0 inet manual

auto macvlan
iface macvlan inet static
  address 192.168.2.34
  netmask 255.255.255.0
  gateway 192.168.2.2
  dns-nameservers 192.168.2.3
  pre-up ip link add macvlan link eth0 type macvlan mode bridge
  post-down ip link del macvlan link eth0 type macvlan mode bridge
```

重启宿主机网络生效（重启宿主机亦可）

```
shell> /etc/init.d/networking restart
[ ok ] Restarting networking (via systemctl): networking.service.
```

配置完成后，TProxy容器的IP地址可视为旁路由IP，需要使用TProxy代理的设备修改其网关为该IP地址，若想让内网全部设备均可使用，则需修改路由器DHCP设置，将网关指向容器IP（仅对动态IP地址设备生效，配置过静态IP的设备仍需手动修改）

## 实例演示

### 示例1-全局科学上网

> 代理全部流量并进行分流，国内流量直连，国外流量走科学上网节点

初始化命令中指定容器IP地址

```
# custom.sh
ip addr flush dev eth0
ip addr add 192.168.2.4/24 brd 192.168.2.255 dev eth0
ip route add default via 192.168.2.2
```

绕过内网IP地址，添加 `192.168.2.0/24` 网段

```
# segment/ipv4
127.0.0.0/8
169.254.0.0/16
192.168.2.0/24
224.0.0.0/3
```

此处将DNS指向本地的无污染[ClearDNS](https://github.com/dnomd343/ClearDNS)服务，如果未部署该服务，修改为 `8.8.8.8` 即可（Xray会将其重新路由至国外节点，不存在污染问题）

```
# dns.json
{
  "dns": {
    "servers": [
      "192.168.2.3"
    ]
  }
}
```

可以配置多个服务节点负载均衡，提高科学上网速度，这里设置了三个VLESS+XTLS节点。

```
# outbounds.json
{
  "outbounds": [
    {
      "tag": "proxy01",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "···",
            "port": 443,
            "users": [
              {
                "id": "···",
                "encryption": "none",
                "flow": "xtls-rprx-direct"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "allowInsecure": false,
          "serverName": "···"
        }
      }
    },
    {
      "tag": "proxy02",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "···",
            "port": 443,
            "users": [
              {
                "id": "···",
                "encryption": "none",
                "flow": "xtls-rprx-direct"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "allowInsecure": false,
          "serverName": "···"
        }
      }
    },
    {
      "tag": "proxy03",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "···",
            "port": 443,
            "users": [
              {
                "id": "···",
                "encryption": "none",
                "flow": "xtls-rprx-direct"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "allowInsecure": false,
          "serverName": "···"
        }
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {}
    },
    {
      "tag": "block",
      "protocol": "blackhole",
      "settings": {}
    }
  ]
}
```

在路由中配置分流与负载均衡，其中还开启了广告拦截功能

```
# routing.json
{
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      {
        "type": "field",
        "inboundTag": [
          "proxy"
        ],
        "balancerTag": "balancer"
      },
      {
        "type": "field",
        "domain": [
          "geosite:category-ads-all"
        ],
        "outboundTag": "block"
      },
      {
        "type": "field",
        "domain": [
          "geosite:cn"
        ],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "ip": [
          "geoip:private",
          "geoip:cn"
        ],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "balancerTag": "balancer"
      }
    ],
    "balancers": [
      {
        "tag": "balancer",
        "selector": [
          "proxy"
        ]
      }
    ]
  }
}
```

配置完成后重启容器即可使用

### 示例2-校园网绕过认证

> 部分校园网存在TCP/53或UDP/53端口无认证漏洞，可将全部流量代理并转发到个人服务器上，实现免认证、无限速的上网

初始化命令中指定容器IP地址，同时模拟外网ICMP数据包响应（否则所有ping均为超时）

```
# custom.sh
ip addr flush dev eth0
ip addr add 192.168.2.2/24 brd 192.168.2.255 dev eth0
ip route add default via 192.168.2.1
iptables -t nat -N SCUT_PING
iptables -t nat -A SCUT_PING -j DNAT --to-destination 192.168.2.2
iptables -t nat -A PREROUTING -i eth0 -p icmp -j SCUT_PING
```

绕过内网IP地址，添加 `192.168.2.0/24` 网段

```
# segment/ipv4
127.0.0.0/8
169.254.0.0/16
192.168.2.0/24
224.0.0.0/3
```

此时所有流量将被代理，不存在域名分流需求，因此无需设置DNS服务器

```
# dns.json
{
  "dns": {}
}
```

这里配置了三个节点，平时使用一台即可，其他两台作为备用容灾

```
# outbounds.json
{
  "outbounds": [
    {
      "tag": "nodeA",
      "protocol": "vless",
      "settings": {
        "vnext": [
          {
            "address": "···",
            "port": 53,
            "users": [
              {
                "id": "···",
                "encryption": "none",
                "flow": "xtls-rprx-direct"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "xtls",
        "xtlsSettings": {
          "allowInsecure": false,
          "serverName": "···"
        }
      }
    },
    {
      "tag": "nodeB",
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "···",
            "port": 53,
            "users": [
              {
                "id": "···",
                "alterId": 0,
                "security": "auto"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "tcp",
        "security": "tls",
        "tlsSettings": {
          "allowInsecure": false,
          "serverName": "···"
        }
      }
    },
    {
      "tag": "nodeC",
      "protocol": "shadowsocks",
      "settings": {
        "servers": [
          {
            "address": "···",
            "method": "aes-256-gcm",
            "ota": false,
            "password": "···",
            "port": 53
          }
        ]
      },
      "streamSettings": {
        "network": "tcp"
      }
    }
  ]
}
```

路由核心接管全部流量并转发给 `nodeA` 节点

```
# routing.json
{
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "nodeA"
      }
    ]
  }
}
```

配置完成后重启容器即可使用

## 开发相关

### 预设接口

+ `Socks5代理`: 1080端口，支持UDP，无授权，标志为 `socks`

+ `HTTP代理`: 1081端口，无授权，标志为 `http`

+ `全局Socks5代理`: 10808端口，支持UDP，无授权，标志为 `proxy`

### 容器构建

**本地构建**

```
# 克隆仓库
shell> git clone https://github.com/dnomd343/TProxy.git
shell> cd TProxy
# 构建镜像
shell> docker build -t tproxy .
```

**交叉构建**

```
# 构建并推送至Docker Hub
shell> docker buildx build -t dnomd343/tproxy --platform="linux/amd64,linux/arm64,linux/386,linux/arm/v7" https://github.com/dnomd343/TProxy.git#master --push
```

## 许可证

MIT ©2021 [@dnomd343](https://github.com/dnomd343)
