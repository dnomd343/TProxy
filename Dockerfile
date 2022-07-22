FROM golang:1.18-alpine3.16 AS xray
ENV XRAY_VERSION="v1.5.9"
RUN \
  apk add git && \
  git clone https://github.com/XTLS/Xray-core.git && \
  cd ./Xray-core/ && git checkout ${XRAY_VERSION} && \
  env CGO_ENABLED=0 go build -o xray -trimpath -ldflags "-s -w" ./main && \
  mv ./xray /tmp/

# upx can't be compiled under gcc11, so we should use alpine:3.15
FROM alpine:3.15 AS upx
ENV UPX_VERSION="3.96"
RUN \
  apk add bash build-base perl ucl-dev zlib-dev && \
  wget https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-src.tar.xz && \
  tar xf upx-${UPX_VERSION}-src.tar.xz && \
  cd upx-${UPX_VERSION}-src/ && make all && \
  mv ./src/upx.out /tmp/upx

FROM alpine:3.16 AS asset
COPY --from=xray /tmp/xray /asset/usr/bin/
COPY --from=upx /tmp/upx /usr/bin/
COPY . /TProxy
RUN \
  apk add libgcc libstdc++ ucl && upx -9 /asset/usr/bin/xray && \
  cd /tmp/ && mkdir ./asset/ && mkdir -p /asset/etc/xray/ && \
  wget "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" -P /tmp/asset/ && \
  wget "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" -P /tmp/asset/ && \
  tar czf asset.tar.gz ./asset/ && mv ./asset.tar.gz /asset/etc/xray/ && \
  mv /TProxy/load.sh /asset/etc/xray/ && chmod +x /asset/etc/xray/load.sh && \
  mv /TProxy/tproxy.sh /asset/tproxy && chmod +x /asset/tproxy

FROM alpine:3.16
COPY --from=asset /asset/ /
ENV XRAY_LOCATION_ASSET=/etc/xray/asset
RUN apk add --no-cache iptables ip6tables radvd && mkdir -p /run/radvd/
ENTRYPOINT ["sh","tproxy"]
