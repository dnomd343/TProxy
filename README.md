# TProxy

基于Docker的旁路由透明代理工具，借助Xray处理TProxy流量，可以实现虚拟化的代理网关，拥有独立的IP与MAC地址。

TProxy当前支持 `amd64`、`i386`、`arm64`、`armv7` 四种CPU架构，可正常代理全部TCP与UDP流量。

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

选择一个目录存储数据，这里使用 `/etc/scutweb`

```
shell> mkdir /etc/scutweb
shell> cd /etc/scutweb
shell> vim custom.sh
```

`custom.sh` 将在容器启动时首先执行，可用于指定容器IP地址与网关地址

```
# 此处指定网关为192.168.2.1，容器IP为192.168.2.2
ip addr flush dev eth0
ip addr add 192.168.2.2/24 brd 192.168.2.255 dev eth0
ip route add default via 192.168.2.1
```

启动容器，此处映射时间与时区信息到容器中，可以与宿主机进行同步（容器内默认为协调世界时零时区），主要用于日志时间显示

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
···
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

建议绕过内网地址、本地回环地址、链路本地地址、组播地址等

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

配置完成以后需要重启容器生效

```
shell> docker restart scutweb
···
```

## 构建

本地构建

```
shell> docker build -t tproxy https://github.com/dnomd343/TProxy.git#master
···
```

交叉构建

```
shell> docker buildx build -t dnomd343/tproxy --platform="linux/amd64,linux/arm64,linux/386,linux/arm/v7" https://github.com/dnomd343/TProxy.git#master --load
```

## 许可证

MIT ©2021 [@dnomd343](https://github.com/dnomd343)