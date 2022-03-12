FROM alpine:3.15 as asset
COPY . /tmp/TProxy
ENV UPX_VERSION="3.96"
ENV XRAY_VERSION="v1.5.3"
RUN \
  apk add build-base bash make curl go git perl ucl-dev zlib-dev && \
  \
  # upx compile
  wget https://github.com/upx/upx/releases/download/v${UPX_VERSION}/upx-${UPX_VERSION}-src.tar.xz -P /tmp/ && \
  cd /tmp/ && tar xf upx-${UPX_VERSION}-src.tar.xz && \
  cd upx-${UPX_VERSION}-src && make all && \
  mv ./src/upx.out /usr/bin/upx && \
  \
  # xray-core compile
  mkdir -p /tmp/asset/usr/bin/ && mkdir -p /tmp/asset/run/radvd/ && \
  git clone https://github.com/XTLS/Xray-core.git /tmp/Xray-core && \
  cd /tmp/Xray-core/ && git checkout $XRAY_VERSION && \
  env CGO_ENABLED=0 go build -o xray -trimpath -ldflags "-s -w" ./main && \
  upx -9 ./xray && mv ./xray /tmp/asset/usr/bin/ && \
  \
  # asset download
  mkdir -p /tmp/asset/etc/xray/asset/ && cd /tmp/asset/etc/xray/asset/ && \
  GEO_VERSION=$(curl -sL "https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') && \
  wget "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/$GEO_VERSION/geoip.dat" && \
  wget "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/$GEO_VERSION/geosite.dat" && \
  cd /tmp/asset/etc/xray/ && tar czf asset.tar.gz asset/ && rm -rf asset/ && \
  \
  # init script
  mv /tmp/TProxy/load.sh /tmp/asset/etc/xray/ && chmod +x /tmp/asset/etc/xray/load.sh && \
  mv /tmp/TProxy/tproxy.sh /tmp/asset/tproxy && chmod +x /tmp/asset/tproxy

FROM alpine:3.15
COPY --from=asset /tmp/asset/ /
ENV XRAY_LOCATION_ASSET=/etc/xray/asset
RUN apk add --no-cache iptables ip6tables radvd
ENTRYPOINT ["sh","tproxy"]
