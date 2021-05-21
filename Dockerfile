FROM alpine as asset
COPY ./asset.sh /
RUN apk --update add --no-cache curl wget && \
    sh /asset.sh

FROM alpine
COPY ["./load.sh", "./tproxy.sh", "/etc/xray/"]
COPY --from=asset /tmp/asset/ /etc/xray/asset/
COPY --from=asset /tmp/xray/xray /usr/bin/
ENV XRAY_LOCATION_ASSET=/etc/xray/asset
RUN apk --update add --no-cache iptables ip6tables && \
    mkdir -p /etc/xray/conf && \
    mkdir -p /etc/xray/expose/log && \
    mkdir -p /etc/xray/expose/segment && \
    mv /etc/xray/tproxy.sh /
CMD ["sh","/tproxy.sh"]
