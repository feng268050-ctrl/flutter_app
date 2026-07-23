#!/usr/bin/env bash
# Install host tools required by `make build` (make ai + make mediamtx) on Linux CI runners.
# Usage (persists PATH in the same shell): source scripts/ci/setup-native-build.sh
set -euo pipefail

GO_VERSION="${CI_GO_VERSION:-1.23.4}"
GO_INSTALL_DIR="${CI_GO_INSTALL_DIR:-/usr/local/go}"

apt_install() {
  if ! command -v apt-get >/dev/null 2>&1; then
    return 1
  fi
  local runner=(apt-get)
  if [[ "$(id -u)" -ne 0 ]]; then
    if ! command -v sudo >/dev/null 2>&1; then
      return 1
    fi
    runner=(sudo apt-get)
  fi
  "${runner[@]}" update -qq
  DEBIAN_FRONTEND=noninteractive "${runner[@]}" install -y -qq curl unzip cmake ca-certificates
}

ensure_cmake() {
  if command -v cmake >/dev/null 2>&1 && cmake --version >/dev/null 2>&1; then
    echo "setup-native-build: cmake OK ($(cmake --version | head -1))"
    return 0
  fi
  echo "setup-native-build: installing cmake..."
  apt_install
  command -v cmake >/dev/null 2>&1 || {
    echo "ERROR: cmake not available after apt install" >&2
    exit 1
  }
  cmake --version | head -1
}

go_version_ok() {
  local ver="${1#go}"
  local major minor
  IFS=. read -r major minor _ <<<"$ver"
  [[ "${major:-0}" -gt 1 || ( "${major:-0}" -eq 1 && "${minor:-0}" -ge 22 ) ]]
}

ensure_go() {
  if command -v go >/dev/null 2>&1; then
    local ver
    ver="$(go version | awk '{print $3}')"
    if go_version_ok "$ver"; then
      echo "setup-native-build: go OK ($ver)"
      return 0
    fi
    echo "setup-native-build: system go too old ($ver); installing Go ${GO_VERSION}..."
  else
    echo "setup-native-build: installing Go ${GO_VERSION}..."
  fi

  local arch tar url
  case "$(uname -m)" in
    x86_64|amd64) arch=amd64 ;;
    aarch64|arm64) arch=arm64 ;;
    *)
      echo "ERROR: unsupported host arch for Go install: $(uname -m)" >&2
      exit 1
      ;;
  esac

  tar="go${GO_VERSION}.linux-${arch}.tar.gz"
  url="https://go.dev/dl/${tar}"
  tmp="$(mktemp -d)"

  curl -fL --retry 3 --retry-delay 2 -o "$tmp/$tar" "$url"
  rm -rf "$GO_INSTALL_DIR"
  if [[ "$(id -u)" -eq 0 ]]; then
    tar -C /usr/local -xzf "$tmp/$tar"
  else
    sudo rm -rf "$GO_INSTALL_DIR"
    sudo tar -C /usr/local -xzf "$tmp/$tar"
  fi
  rm -rf "$tmp"
  export PATH="$GO_INSTALL_DIR/bin:$PATH"
  go version
}

ensure_cmake
ensure_go

export PATH="$GO_INSTALL_DIR/bin:${PATH:-}"
