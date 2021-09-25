FROM alpine as asset
COPY ./asset.sh /
RUN apk --update add --no-cache curl wget jq && \
    sh /asset.sh

FROM alpine
COPY ["./load.sh", "./tproxy.sh", "/etc/xray/"]
COPY --from=asset /tmp/asset/ /etc/xray/asset/
COPY --from=asset /tmp/xray/xray /usr/bin/
ENV XRAY_LOCATION_ASSET=/etc/xray/asset
RUN apk --update add --no-cache iptables ip6tables && \
    mkdir -p /etc/xray/config && \
    mv /etc/xray/tproxy.sh /
CMD ["sh","/tproxy.sh"]
