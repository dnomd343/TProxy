# TProxy

基于Docker的旁路由透明代理工具，借助Xray处理TProxy流量，实现拥有独立IP与MAC地址的虚拟化代理网关。

TProxy当前支持 `amd64`、`i386`、`arm64`、`armv7` 四种CPU架构，可代理任意TCP与UDP流量。

## 部署

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

`custom.sh` 将在容器启动时首先执行，可用于指定容器IP与网关地址

```
# 此处指定网关为192.168.2.1，容器IP为192.168.2.2
ip addr flush dev eth0
ip addr add 192.168.2.2/24 brd 192.168.2.255 dev eth0
ip route add default via 192.168.2.1
```

启动容器，此处映射时间与时区信息到容器中，可以与宿主机进行同步（容器内默认为UTC零时区），用于日志时间记录

```
# 容器名称和存储目录可自行指定
docker run --restart always \
--name scutweb \
--network macvlan \
--privileged -d \
--volume /etc/scutweb/:/etc/xray/expose/ \
--volume /etc/timezone:/etc/timezone:ro \
--volume /etc/localtime:/etc/localtime:ro \
dnomd343/tproxy
```

使用以下命令查看容器运行状态

```
shell> docker ps -a
```

容器成功运行以后，将会在存储目录下生成多个文件和文件夹

+ `log`：文件夹，存储Xray日志文件

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

`routeing.json` 默认配置将全部流量交由 `node` 接口，即 `outbounds.json` 中的 `freedom` 出口，具体语法见[Xray文档](https://xtls.github.io/config/base/routing/)

```
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
```

`segment` 文件夹下默认存储 `ipv4` 与 `ipv6` 两个文件，其中存储不代理的网段信息

```
# IPv4与IPv6均默认绕过组播地址
shell> cat /etc/scutweb/segment/ipv4
224.0.0.0/3
shell> cat /etc/scutweb/segment/ipv6
FF00::/8
```

建议绕过内网地址、本地回环地址、链路本地地址、组播地址等网段

```
# IPv4
127.0.0.0/8
169.254.0.0/16
192.168.2.0/24
224.0.0.0/3

# IPv6
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

重启宿主机生效

```
shell> reboot
```

预设接口

+ `Socks5代理`: 1080端口，支持UDP，无授权，标志为 `socks`

+ `HTTP代理`: 1081端口，无授权，标志为 `http`

+ `全局Socks5代理`: 10808端口，支持UDP，无授权，标志为 `proxy`

## 构建

如果需要修改TProxy或构建自己的容器，可按如下操作

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
