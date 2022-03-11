FROM alpine as asset
COPY ./asset.sh /
RUN apk --update add --no-cache curl wget jq && \
    sh /asset.sh

FROM alpine
COPY ["./load.sh", "./tproxy.sh", "/etc/xray/"]
COPY --from=asset /tmp/asset/ /etc/xray/asset/
COPY --from=asset /tmp/xray/xray /usr/bin/
ENV XRAY_LOCATION_ASSET=/etc/xray/asset
RUN apk add --no-cache iptables ip6tables radvd && \
    mkdir -p /etc/xray/config && \
    mkdir -p /run/radvd/ && \
    mv /etc/xray/tproxy.sh /tproxy
ENTRYPOINT ["sh","tproxy"]
