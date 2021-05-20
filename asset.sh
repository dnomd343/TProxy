get_github_latest_version() {
  VERSION=$(curl --silent "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/');
}

XRAY_DIR="/tmp/xray"
ASSET_DIR="/tmp/asset"
mkdir -p $XRAY_DIR/pkg

XRAY_PKG_NAME="Xray-linux-arm64-v8a.zip"
get_github_latest_version "XTLS/Xray-core"
wget -P $XRAY_DIR/pkg "https://hub.fastgit.org/XTLS/Xray-core/releases/download/$VERSION/$XRAY_PKG_NAME"
unzip $XRAY_DIR/pkg/$XRAY_PKG_NAME -d /$XRAY_DIR/pkg
cp $XRAY_DIR/pkg/xray $XRAY_DIR
rm -rf $XRAY_DIR/pkg

get_github_latest_version "Loyalsoldier/v2ray-rules-dat"
wget -P $ASSET_DIR "https://hub.fastgit.org/Loyalsoldier/v2ray-rules-dat/releases/download/$VERSION/geoip.dat"
wget -P $ASSET_DIR "https://hub.fastgit.org/Loyalsoldier/v2ray-rules-dat/releases/download/$VERSION/geosite.dat"
