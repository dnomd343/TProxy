FROM golang:1.18.1-alpine3.15 AS asset
COPY . /tmp/TProxy
ENV UPX_VERSION="3.96"
ENV XRAY_VERSION="v1.5.5"
RUN \
  apk add build-base bash make curl git perl ucl-dev zlib-dev && \
  \
  # upx compile
  wget https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-src.tar.xz -P /tmp/ && \
  cd /tmp/ && tar xf upx-${UPX_VERSION}-src.tar.xz && \
  cd upx-${UPX_VERSION}-src && make all && \
  mv ./src/upx.out /usr/bin/upx && \
  \
  # xray-core compile
  mkdir -p /asset/usr/bin/ && mkdir -p /asset/run/radvd/ && \
  git clone https://github.com/XTLS/Xray-core.git /tmp/Xray-core && \
  cd /tmp/Xray-core/ && git checkout $XRAY_VERSION && \
  env CGO_ENABLED=0 go build -o xray -trimpath -ldflags "-s -w" ./main && \
  upx -9 ./xray && mv ./xray /asset/usr/bin/ && \
  \
  # asset download
  mkdir -p /asset/etc/xray/asset/ && cd /asset/etc/xray/asset/ && \
  wget "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" && \
  wget "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" && \
  cd /asset/etc/xray/ && tar czf asset.tar.gz ./asset/ && rm -rf ./asset/ && \
  \
  # init script
  mv /tmp/TProxy/load.sh /asset/etc/xray/ && chmod +x /asset/etc/xray/load.sh && \
  mv /tmp/TProxy/tproxy.sh /asset/tproxy && chmod +x /asset/tproxy

FROM alpine:3.15.4
COPY --from=asset /asset/ /
ENV XRAY_LOCATION_ASSET=/etc/xray/asset
RUN apk add --no-cache iptables ip6tables radvd
ENTRYPOINT ["sh","tproxy"]
