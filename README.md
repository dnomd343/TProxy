# 虚拟代理网关

快速搭建的虚拟网关，以旁路由形式收集内网流量，用于局域网设备的透明代理。该网关拥有独立的MAC与IP地址，脱离宿主机网络环境，使用Docker容器化部署，拉取镜像设置参数后即可运行，无需进行复杂的路由配置。

原理上，借助于macvlan虚拟网卡技术实现，iptables与ip6tables机制收集客户端流量，以[TProxy方式](https://www.kernel.org/doc/html/latest/networking/tproxy.html)将数据交由[Xray内核](https://github.com/XTLS/Xray-core.git)处理，实现虚拟代理网关，支持TCP和UDP流量，支持IPv4与IPv6双栈，支持 `amd64`、`i386`、`arm64`、`armv7` 多种CPU架构。

## 镜像获取

在[Docker Hub](https://hub.docker.com/repository/docker/dnomd343/tproxy)或[Github Package](https://github.com/dnomd343/TProxy/pkgs/container/tproxy)可以查看已构建的镜像，使用时建议拉取 `latest` 版本，如果需要特定版本镜像，拉取时指定tag为版本号即可。

```
# latest版本
shell> docker pull dnomd343/tproxy

# 指定版本
shell> docker pull dnomd343/tproxy:v1.1
```

镜像可以从多个源拉取，其数据完全相同，国内用户建议首选阿里云镜像。

```
# Docker Hub
shell> docker pull docker.io/dnomd343/tproxy

# Github Package
shell> docker pull ghcr.io/dnomd343/tproxy

# 阿里云个人镜像
shell> docker pull registry.cn-shenzhen.aliyuncs.com/dnomd343/tproxy
```

## 开始部署

> 以下内容基于树莓派4B测试，系统为 `Raspberry Pi OS` ，Linux内核为 `5.10.60` ，其它设备环境原理类似。

开启网卡混杂模式

```
shell> ip link set eth0 promisc on
```

安装相关内核模块

```
shell> modprobe ip6table_filter
```

创建 `macvlan` 网络

```
# 此处网段与网关信息需按实际网络指定
shell> docker network create -d macvlan \
--subnet=192.168.2.0/24 \
--gateway=192.168.2.1 \
--subnet=fc00::/64 \
--gateway=fc00::1 \
--ipv6 -o parent=eth0 macvlan
```

选择一个目录存储数据，此处使用 `/etc/scutweb`

```
shell> mkdir /etc/scutweb
```

启动容器，将宿主机时间与时区信息映射到内部，同步时间参数（容器内默认为UTC零时区），用于日志时间记录。

```
# 容器名称和存储目录可自行指定
shell> docker run --restart always \
--name scutweb \
--network macvlan \
--privileged -d \
--volume /etc/scutweb/:/etc/xray/expose/ \
--volume /etc/timezone:/etc/timezone:ro \
--volume /etc/localtime:/etc/localtime:ro \
dnomd343/tproxy:latest
# 此处为DockerHub镜像源，可按上文链接替换为其他源
```

使用以下命令查看容器运行状态

```
shell> docker ps -a
```

容器成功运行以后，将会在存储目录下生成以下四个文件夹

+ `asset`：存储路由规则

+ `config`：存储Xray配置文件

+ `log`：存储代理流量日志

+ `network`：存储网络相关配置

**资源文件夹**

`asset` 目录默认放置 `geoip.dat` 与 `geosite.dat` 规则文件，分别存储IP与域名归属信息，容器初始化时会同时创建 `update.sh` 脚本，用于[规则文件](https://github.com/Loyalsoldier/v2ray-rules-dat.git)的拉取更新。

该目录也可放置自定义规则文件，所有后缀为 `.dat` 的文件将被装载到容器内部，可以在Xray配置文件里直接引用，格式为 `ext:file.dat:tag` ，具体配置见[Xray文档](https://xtls.github.io/config/routing.html#ruleobject)。

**配置文件夹**

`config` 目录存储Xray配置文件，容器初始化时会创建 `dns.json` 、`outbounds.json` 和 `routing.json` 三个文件，分别指定路由DNS服务器、流量出口信息、流量路由信息。

`dns.json` 指定路由匹配时的DNS服务器，默认使用主机DNS，具体原理见[Xray文档](https://xtls.github.io/config/dns.html)

```
{
  "dns": {
    "servers": [
      "localhost"
    ]
  }
}
```

`outbounds.json` 默认配置流量转发给上游网关，需要用户手动配置为上游接口，具体语法见[Xray文档](https://xtls.github.io/config/outbound.html)

```
{
  "outbounds": [
    {
      "tag": "node",
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
```

`routing.json` 默认配置将全部流量交由 `node` 接口，即 `outbounds.json` 中的 `freedom` 出口，具体语法见[Xray文档](https://xtls.github.io/config/routing.html)

```
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
```

此外，本目录下所有后缀为 `.json` 的文件将被加载到Xray中，使用[多文件配置](https://xtls.github.io/config/features/multiple.html)方式执行，容器内已预置 `log.json` 与 `inbounds.json` 两个文件，分别控制日志模块与入站流量，在 `config` 目录下创建同名文件可实现覆盖效果，不过若配置有误将导致代理失效，正常情况下不建议修改这两个文件。

**日志文件夹**

`log` 目录用于放置Xray代理日志，数据将记录到 `access.log` 和 `error.log` 两个文件中。

日志记录级别默认为 `warning` ，需要修改时可以在目录下创建 `level` 文件，写入 `debug` 、`info` 、`warning` 、`error` 或 `none` 指定级别，具体区别见[Xray文档](https://xtls.github.io/config/log.html)。

**网络文件夹**

`network` 文件夹记录虚拟网关的网络配置，默认创建 `bypass` 和 `interface` 两个文件夹，前者记录不代理的网段，后者存储容器的IP、掩码和上游网关等信息。

`bypass` 文件夹下默认有 `ipv4` 与 `ipv6` 两个文件，其中分别记录两种协议栈的绕过信息，容器初始化时除了默认配置的回环地址、内网地址绕过，还将补充本配置文件中的网段。正常情况下，建议IPv4绕过链路本地地址 `169.254.0.0/16` 、D类多点播送地址和E类保留地址 `224.0.0.0/3` ，IPv6绕过唯一本地地址 `fc00::/7` 、链路本地地址 `fe80::/10` 以及组播地址 `ff00::/8` ，容器初始化时预置网段如下：

```
shell> cat /etc/scutweb/network/bypass/ipv4
169.254.0.0/16
224.0.0.0/3
shell> cat /etc/scutweb/network/bypass/ipv6
fc00::/7
fe80::/10
ff00::/8
```

`interface` 文件夹下默认有 `ipv4` 与 `ipv6` 两个文件，分别记录容器网络配置信息，两者初始化时内容均如下：

```
ADDRESS=
GATEWAY=
FORWARD=true
```

+ `ADDRESS` 指定容器静态IP地址及掩码，如 `192.168.2.2/24` 或 `fc00::2/64`

+ `GATEWAY` 指定容器上游网关，如 `192.168.2.1` 或 `fc00::1`

+ `FORWARD` 指定是否开启IPv4或IPv6的内核转发功能，正常情况下建议打开

如果不需要自定义任何网络配置，可以在 `interface` 目录下创建 `ignore` 文件，跳过网络参数的相关配置。

`radvd` 文件夹在容器初始化时会默认创建 `config` 文件，配置网关IPv6路由广播信息，内容如下：

```
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
```

默认情况下为 `stateless` 无状态模式，自动根据容器IPv6地址发布RA报文。如果需要配置为 `stateful` 或无状态DHCPv6模式，修改 `AdvManagedFlag` 与 `AdvOtherConfigFlag` 的状态即可（两者分别对应RA报文的M字段与O字段），其他参数的解释可见[man手册](https://linux.die.net/man/5/radvd.conf)，需要注意的是，此处配置文件仅支持上述11个核心参数，其他选项将被忽略。

如果不想开启本项功能，在 `radvd` 目录下创建 `ignore` 文件即可关闭服务。

除此之外，在 `network` 目录下还可创建 `dns` 文件，在其中指定网关内部的DNS服务器。

在更改完以上参数后，重启容器即可生效

```
shell> docker restart -t=0 scutweb
```

受限于macvlan机制，宿主机无法直接与macvlan容器通讯，需要配置网桥才能让宿主机访问虚拟网关。

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
  address 192.168.2.34   # 宿主机静态IP地址
  netmask 255.255.255.0  # 子网掩码
  gateway 192.168.2.2    # 虚拟网关IP地址
  dns-nameservers 192.168.2.3  # DNS主服务器
  dns-nameservers 192.168.2.1  # DNS备用服务器
  pre-up ip link add macvlan link eth0 type macvlan mode bridge
  post-down ip link del macvlan link eth0 type macvlan mode bridge
  # 搭建网桥macvlan，用于与虚拟网关通讯
```

重启宿主机网络生效（或直接重启宿主机）

```
shell> /etc/init.d/networking restart
[ ok ] Restarting networking (via systemctl): networking.service.
```

配置完成后，容器IP为虚拟旁路由网关地址，设备网关设置为该地址即可正常上网。

对于非静态IP地址设备（常见情况）有以下情形：

+ 在IPv4上，修改路由器DHCP设置，将网关指向容器IP即可全局生效

+ 在IPv6上，容器默认会启动IPv6路由组播机制，内网设备将会无状态配置子网地址，网关地址自动指向容器链路本地地址，该配置可全局生效（需关闭路由器IPv6分配，避免冲突）

对于静态IP地址设备（非常见情况）有以下情形：

+ 在IPv4上，修改设备网关为容器IPv4地址

+ 在IPv6上，修改设备地址至容器指定子网内，网关地址配置为容器IPv6地址（非链路本地地址）

综上，开启虚拟网关前需关闭路由器IPv6地址分配，而后连入设备将自动适配IPv4与IPv6网络（绝大多数设备均以DHCP与IPv6路由器发现机制联网），对于此前在内网固定IP地址的设备，手动为其配置网关地址即可。

## 实例演示

### 示例1-全局科学上网

> 代理全部流量并进行分流，国内流量直连，国外流量走科学上网节点

假设原网关IP为 `192.168.2.2` ，可通过它正常访问国内网络，此时搭建新的虚拟网关 `192.168.2.4` ，用于访问国外网络（此处仅配置IPv4网络，IPv6可类比设置）

`network/interface/ipv4` 中指定以下参数

```
ADDRESS=192.168.2.4/24
GATEWAY=192.168.2.2
FORWARD=true
```

更改Xray配置文件

```
# dns.json
{
  "dns": {
    "servers": [
      "223.5.5.5"
    ]
  }
}
```

此处DNS服务器用于域名分流，可指定国内公共DNS服务器，如 `223.5.5.5` 或 `119.29.29.29` 等（利用了GFW污染域名均为国外IP的特性），如果更准确地分流，也可指定为国外公共DNS服务器，如 `1.1.1.1` 或 `8.8.8.8` 等（请求流量会路由至国外节点，不存在污染问题，但会降低解析速度）

在出口配置中可以使用多台服务器进行负载均衡，提高科学上网速度，这里设置了三个节点

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
      ···
    },
    {
      "tag": "proxy03",
      ···
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

在路由中配置分流与负载均衡，同时开启了广告拦截功能

```
# routing.json
{
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
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

假设路由器WAN口配置了校园网提供的静态IP地址，内网通过NAT方式连接到交换机上，路由器IP地址为 `192.168.2.1` ，创建虚拟旁路由 `192.168.2.2` ，将流量代理到个人服务器上，让内网设备可以正常联网。

`network/interface/ipv4` 中指定以下参数

```
ADDRESS=192.168.2.2/24
GATEWAY=192.168.2.1
FORWARD=true
```

`network/interface/ipv6` 中指定以下参数（代理隧道运行在IPv4上，内网IPv6流量将封装后在远程服务器上输出）

```
ADDRESS=fc00::2/64
GATEWAY=
FORWARD=false
```

在主目录下可以创建 `custom.sh` 文件，该脚本将在容器启动时执行，可添加自定义命令进行定制。

```
shell> cd /etc/scutweb
shell> vim custom.sh
```

由于TProxy模式不代理网络层及以下的数据包，ping流量的ICMP数据包不走代理，需要时可以在 `custom.sh` 中添加以下命令，回应所有发往外网的ICMP数据包，表现为ping成功且延迟为内网访问时间。

```
# DNAT目标指定为自身IP地址
iptables -t nat -N FAKE_PING
iptables -t nat -A FAKE_PING -j DNAT --to-destination 192.168.2.2
iptables -t nat -A PREROUTING -i eth0 -p icmp -j FAKE_PING
ip6tables -t nat -N FAKE_PING
ip6tables -t nat -A FAKE_PING -j DNAT --to-destination fc00::2
ip6tables -t nat -A PREROUTING -i eth0 -p icmp -j FAKE_PING
# ICMP数据包实际未到达，使用NAT方式假冒远程主机返回到达信息
```

当前需求下，所有流量将被代理，不存在域名分流需求，因此无需设置DNS服务器

```
# dns.json
{
  "dns": {}
}
```

此处配置三个可用节点，分别为 `nodeA` 、`nodeB` 和 `nodeC`

```
# outbounds.json
{
  "outbounds": [
    {
      "tag": "nodeA",
      ···
    },
    {
      "tag": "nodeB",
      ···
    },
    {
      "tag": "nodeC",
      ···
    },
  ]
}
```

路由核心接管全部流量并进行分流，这里将IPv4透明代理流量转发到三台服务器负载均衡，但由于仅有 `nodeC` 节点支持IPv6，因此IPv6代理流量只会被转发到 `nodeC` 上，其余非透明代理流量也将由 `nodeC` 兜底。

```
# routing.json
{
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "inboundTag": [ "tproxy" ],
        "balancerTag": "ipv4"
      },
      {
        "type": "field",
        "inboundTag": [ "tproxy6" ],
        "balancerTag": "ipv6"
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "balancerTag": "ipv6"
      }
    ],
    "balancers": [
      {
        "tag": "ipv4",
        "selector": [ "nodeA", "nodeB", "nodeC" ]
      },
      {
        "tag": "ipv6",
        "selector": [ "nodeC" ]
      }
    ]
  }
}
```

配置完成后重启容器即可使用

## 开发相关

### 预设接口

+ `IPv4透明代理`：7288端口，标志为 `tproxy`

+ `IPv6透明代理`：7289端口，标志为 `tproxy6`

+ `Socks5代理`：1080端口，支持UDP，无授权，标志为 `socks`

+ `HTTP代理`：1081端口，无授权，标志为 `http`

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
shell> docker buildx build -t dnomd343/tproxy --platform="linux/amd64,linux/arm64,linux/386,linux/arm/v7" https://github.com/dnomd343/TProxy.git --push
```

## 许可证

MIT ©2022 [@dnomd343](https://github.com/dnomd343)
