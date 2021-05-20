get_github_latest_version() {
  VERSION=$(curl --silent "https://api.github.com/repos/$1/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/');
}

get_architecture() {
  case "$(uname -m)" in
    'i386' | 'i686')
      MACHINE='i386'
      ;;
    'amd64' | 'x86_64')
      MACHINE='amd64'
      ;;
    'armv7' | 'armv7l')
      MACHINE='arm'
      ;;
    'armv8' | 'aarch64')
      MACHINE='arm64'
      ;;
    *)
      echo "The architecture is not supported."
      exit 1
      ;;
  esac
}

XRAY_DIR="/tmp/xray"
ASSET_DIR="/tmp/asset"
mkdir -p $XRAY_DIR/pkg

get_architecture
case "$MACHINE" in
  'i386')
    XRAY_PKG_NAME="Xray-linux-32.zip"
    ;;
  'amd64')
    XRAY_PKG_NAME="Xray-linux-64.zip"
    ;;
  'arm')
    XRAY_PKG_NAME="Xray-linux-arm32-v7a.zip"
    ;;
  'arm64')
    XRAY_PKG_NAME="Xray-linux-arm64-v8a.zip"
    ;;
esac

get_github_latest_version "XTLS/Xray-core"
wget -P $XRAY_DIR/pkg "https://hub.fastgit.org/XTLS/Xray-core/releases/download/$VERSION/$XRAY_PKG_NAME"
unzip $XRAY_DIR/pkg/$XRAY_PKG_NAME -d /$XRAY_DIR/pkg
cp $XRAY_DIR/pkg/xray $XRAY_DIR
rm -rf $XRAY_DIR/pkg

get_github_latest_version "Loyalsoldier/v2ray-rules-dat"
wget -P $ASSET_DIR "https://hub.fastgit.org/Loyalsoldier/v2ray-rules-dat/releases/download/$VERSION/geoip.dat"
wget -P $ASSET_DIR "https://hub.fastgit.org/Loyalsoldier/v2ray-rules-dat/releases/download/$VERSION/geosite.dat"
