get_github_latest_version() {
  VERSION=$(curl --silent "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/');
}

ASSET_DIR="/tmp/asset"
mkdir -p $ASSET_DIR/pkg

XRAY_PKG_NAME="Xray-linux-arm64-v8a.zip"
get_github_latest_version "XTLS/Xray-core"
wget -P $ASSET_DIR/pkg "https://hub.fastgit.org/XTLS/Xray-core/releases/download/$VERSION/$XRAY_PKG_NAME"
unzip $ASSET_DIR/pkg/$XRAY_PKG_NAME -d /$ASSET_DIR/pkg
cp $ASSET_DIR/pkg/xray $ASSET_DIR
rm -rf $ASSET_DIR/pkg

get_github_latest_version "Loyalsoldier/v2ray-rules-dat"
wget -P $ASSET_DIR "https://hub.fastgit.org/Loyalsoldier/v2ray-rules-dat/releases/download/$VERSION/geoip.dat"
wget -P $ASSET_DIR "https://hub.fastgit.org/Loyalsoldier/v2ray-rules-dat/releases/download/$VERSION/geosite.dat"
