FROM alpine:3.15 as asset
COPY . /tmp/TProxy
ENV XRAY_VERSION="v1.5.3"
RUN \
apk add curl go git && \
mkdir -p /tmp/asset/usr/bin/ && mkdir -p /tmp/asset/run/radvd/ && \
git clone https://github.com/XTLS/Xray-core.git /tmp/Xray-core && \
cd /tmp/Xray-core/ && git checkout $XRAY_VERSION && \
env CGO_ENABLED=0 go build -o xray -trimpath -ldflags "-s -w" ./main && \
mv ./xray /tmp/asset/usr/bin/ && \
mkdir -p /tmp/asset/etc/xray/asset/ && cd /tmp/asset/etc/xray/asset/ && \
GEO_VERSION=$(curl -sL "https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/') && \
wget "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/$GEO_VERSION/geoip.dat" && \
wget "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/$GEO_VERSION/geosite.dat" && \
cd /tmp/asset/etc/xray/ && tar czf asset.tar.gz asset/ && rm -rf asset/ && \
mv /tmp/TProxy/load.sh /tmp/asset/etc/xray/ && chmod +x /tmp/asset/etc/xray/load.sh && \
mv /tmp/TProxy/tproxy.sh /tmp/asset/tproxy && chmod +x /tmp/asset/tproxy

FROM alpine:3.15
COPY --from=asset /tmp/asset/ /
ENV XRAY_LOCATION_ASSET=/etc/xray/asset
RUN apk add --no-cache iptables ip6tables radvd
ENTRYPOINT ["sh","tproxy"]
