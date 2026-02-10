#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "用法: $0 <version> [server_os_arch] [cli_os_arch]"
  echo "示例: $0 1.108.2 linux-x64 alpine-x64"
  exit 1
fi

VERSION="$1"
SERVER_OS_ARCH="${2:-linux-x64}"
CLI_OS_ARCH="${3:-alpine-x64}"

REPO_URL="https://github.com/microsoft/vscode.git"

COMMIT_ID="$(git ls-remote --tags "$REPO_URL" "refs/tags/$VERSION" | awk '{print $1}')"
if [[ -z "$COMMIT_ID" ]]; then
  echo "未找到版本号: $VERSION"
  exit 1
fi

echo "找到版本 $VERSION 对应的提交 ID: $COMMIT_ID"

OUT_DIR="$COMMIT_ID"
mkdir -p "$OUT_DIR"

SERVER_URL="https://update.code.visualstudio.com/commit:${COMMIT_ID}/server-${SERVER_OS_ARCH}/stable"
CLI_URL="https://update.code.visualstudio.com/commit:${COMMIT_ID}/cli-${CLI_OS_ARCH}/stable"

SERVER_FILE="$OUT_DIR/server-${SERVER_OS_ARCH}.tar.gz"
CLI_FILE_OS_ARCH="${CLI_OS_ARCH/alpine/linux}"
CLI_FILE="$OUT_DIR/cli-${CLI_FILE_OS_ARCH}.tar.gz"

echo "下载 URL:"
echo "$SERVER_URL"
echo "$CLI_URL"

curl -L "$SERVER_URL" -o "$SERVER_FILE"
curl -L "$CLI_URL" -o "$CLI_FILE"

INSTALL_SH="$OUT_DIR/install.sh"
cat > "$INSTALL_SH" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "用法: $0 [target_dir]"
  echo "默认 target_dir: ~/.vscode-server"
  exit 1
fi

COMMIT_ID="$(basename "$PWD")"
TARGET_DIR="${1:-$HOME/.vscode-server}"

OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ARCH="$(uname -m)"
case "$ARCH" in
  x86_64|amd64) ARCH="x64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  armv7l|armv6l) ARCH="armhf" ;;
esac

case "$OS" in
  linux) OS="linux" ;;
  darwin) OS="darwin" ;;
  msys*|mingw*|cygwin*) OS="win32" ;;
esac

SERVER_TGZ="server-${OS}-${ARCH}.tar.gz"
CLI_TGZ="cli-${OS}-${ARCH}.tar.gz"

if [[ ! -f "$SERVER_TGZ" || ! -f "$CLI_TGZ" ]]; then
  echo "未找到匹配当前系统的压缩包:"
  echo "$SERVER_TGZ"
  echo "$CLI_TGZ"
  echo "请在下载目录内运行该脚本，或确认已下载对应 OS/ARCH 的包"
  exit 1
fi

mkdir -p "$TARGET_DIR"

SERVER_TMP="$(mktemp -d)"
CLI_TMP="$(mktemp -d)"

tar -xzf $SERVER_TGZ -C "$SERVER_TMP"
tar -xzf $CLI_TGZ -C "$CLI_TMP"

if [[ -e "$CLI_TMP/code" ]]; then
  CLI_SRC="$CLI_TMP/code"
else
  CLI_SRC="$(find "$CLI_TMP" -maxdepth 1 -type d -name 'code-*' -o -name 'vscode-cli-*' | head -n 1)"
  if [[ -z "$CLI_SRC" ]]; then
    CLI_SRC="$(find "$CLI_TMP" -maxdepth 2 -type d | head -n 1)"
  fi
fi

SERVER_SRC="$(find "$SERVER_TMP" -maxdepth 1 -type d -name 'vscode-server-*' | head -n 1)"

if [[ -z "$CLI_SRC" || -z "$SERVER_SRC" ]]; then
  echo "解压失败或结构不匹配"
  exit 1
fi

mkdir -p "$TARGET_DIR/cli/servers/Stable-$COMMIT_ID/server"
mv "$CLI_SRC" "$TARGET_DIR/code-$COMMIT_ID"
cp -R "$SERVER_SRC/." "$TARGET_DIR/cli/servers/Stable-$COMMIT_ID/server/"

echo "完成:"
echo "$TARGET_DIR/code-$COMMIT_ID"
echo "$TARGET_DIR/cli/servers/Stable-$COMMIT_ID/server"
EOF

chmod +x "$INSTALL_SH"

echo "完成下载:"
echo "$SERVER_FILE"
echo "$CLI_FILE"
echo "$INSTALL_SH"