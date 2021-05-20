FROM alpine as asset
COPY ./asset.sh /
RUN apk --update add --no-cache curl wget && \
    sh /asset.sh

FROM alpine
COPY . /tmp/xray
COPY --from=asset /tmp/asset/ /tmp/xray/asset/
RUN apk --update add --no-cache iptables ip6tables net-tools curl && \
    mkdir -p /etc/xray/conf && \
    mkdir -p /etc/xray/expose/log && \
    mkdir -p /etc/xray/expose/segment && \
    mv /tmp/xray/tproxy.sh / && \
    mv /tmp/xray/load.sh /etc/xray/ && \
    mv /tmp/xray/asset/xray /usr/bin/ && \
    mv /tmp/xray/asset /etc/xray/ && \
    rm -rf /tmp/xray
CMD ["sh","/tproxy.sh"]
