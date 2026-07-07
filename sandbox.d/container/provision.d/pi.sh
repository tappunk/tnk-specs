#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# shellcheck source=sandbox.d/container/provision.d/lib/provision-lib.sh
source "$(dirname "$0")/lib/provision-lib.sh"

PROFILE_REV="2026-07-06.5"
REQUIRED_NODE_VERSION="22.19.0"

# Runtime values injected by tnk at execution time:
#   TNK_INFERENCE_URL   http://<backend-gateway>:8080/v1
#   TNK_OPENAI_URL      http://<backend-gateway>:8080/v1
#   TNK_MODEL_NAME      01-qwen3-6-35b-a3b
#   TNK_CTX_WINDOW      262144
#   TNK_WORKSPACE_MOUNT /workspace
#   TNK_SPECS_REV       sha256 of provision script content
#   TNK_ENGINE_RUNTIME  inference runtime provider key (mlxcel, llama)

OPENAI_URL="${TNK_INFERENCE_URL:-${TNK_OPENAI_URL:-}}"
if [[ -z "$OPENAI_URL" ]]; then
    echo "[ERR] TNK_INFERENCE_URL (or TNK_OPENAI_URL) is required" >&2
    exit 1
fi
MODEL_NAME="${TNK_MODEL_NAME:?TNK_MODEL_NAME is required}"
CTX_WINDOW="${TNK_CTX_WINDOW:?TNK_CTX_WINDOW is required}"
WORKSPACE_MOUNT="${TNK_WORKSPACE_MOUNT:-/workspace}"

echo "[PROC] Pi coding agent environment provisioning..."

_lib_init_provision_state "pi" "$PROFILE_REV" "$OPENAI_URL" "$MODEL_NAME" "$CTX_WINDOW" "$WORKSPACE_MOUNT"

export DEBIAN_FRONTEND=noninteractive
export NPM_CONFIG_PREFIX="$HOME/.local"
mkdir -p "$HOME/.local/bin" "$HOME/.local/lib"
export PATH="$HOME/.local/bin:$PATH"
NPM_NET_FLAGS=(--fetch-retries=5 --fetch-retry-mintimeout=2000 --fetch-retry-maxtimeout=120000 --fetch-timeout=600000)
CURL_NET_FLAGS=(--fail --show-error --location --connect-timeout 15 --max-time 180 --retry 4 --retry-delay 2 --retry-all-errors)

CURRENT_NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo "0")"
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1 || [[ "$CURRENT_NODE_MAJOR" -lt 22 ]]; then
    echo "[PROC] Installing Node.js ${REQUIRED_NODE_VERSION}..."
    NODE_DIST="node-v${REQUIRED_NODE_VERSION}-linux-arm64"
    NODE_URL="https://nodejs.org/dist/v${REQUIRED_NODE_VERSION}/${NODE_DIST}.tar.xz"
    NODE_INSTALL_DIR="$HOME/.local/${NODE_DIST}"
    TMP_DIR="$(mktemp -d)"

    curl "${CURL_NET_FLAGS[@]}" "$NODE_URL" -o "$TMP_DIR/node.tar.xz"
    mkdir -p "$NODE_INSTALL_DIR"
    tar -xJf "$TMP_DIR/node.tar.xz" --strip-components=1 -C "$NODE_INSTALL_DIR"
    rm -rf "$TMP_DIR"

    export PATH="$NODE_INSTALL_DIR/bin:$HOME/.local/bin:$PATH"

    if command -v sudo >/dev/null 2>&1; then
        sudo mkdir -p /usr/local/bin
        sudo ln -sf "$NODE_INSTALL_DIR/bin/node" /usr/local/bin/node
        sudo ln -sf "$NODE_INSTALL_DIR/bin/npm" /usr/local/bin/npm
        sudo ln -sf "$NODE_INSTALL_DIR/bin/npx" /usr/local/bin/npx
    fi
fi

if ! command -v npm >/dev/null 2>&1; then
    echo "[ERR] npm is not available after Node.js installation." >&2
    exit 1
fi

echo "[PROC] Installing Pi CLI..."
npm install -g --loglevel=silent --yes --ignore-scripts "${NPM_NET_FLAGS[@]}" \
    "@earendil-works/pi-coding-agent"

echo "[PROC] Installing Pi runtime helpers (fd, ripgrep)..."
if command -v sudo >/dev/null 2>&1; then
    sudo apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 install -y -qq fd-find ripgrep
    if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
        sudo ln -sf "$(command -v fdfind)" /usr/local/bin/fd
    fi
else
    apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 update -qq
    DEBIAN_FRONTEND=noninteractive apt-get -o Acquire::Retries=5 -o Acquire::http::Timeout=30 install -y -qq fd-find ripgrep
fi

if ! command -v pi >/dev/null 2>&1; then
    echo "[ERR] pi installation did not produce an executable in PATH." >&2
    exit 1
fi

if command -v sudo >/dev/null 2>&1; then
    sudo mkdir -p /usr/local/bin
    sudo ln -sf "$HOME/.local/bin/pi" /usr/local/bin/pi
fi

echo "[PROC] Generating Pi configuration..."
mkdir -p "$HOME/.pi/agent"

JSON_MODEL_NAME="$(printf '%s' "$MODEL_NAME" | sed 's/\\/\\\\/g; s/"/\\"/g')"
JSON_OPENAI_URL="$(printf '%s' "$OPENAI_URL" | sed 's/\\/\\\\/g; s/"/\\"/g')"

cat > "$HOME/.pi/agent/models.json" << EOF
{
  "providers": {
    "tnk": {
      "baseUrl": "${JSON_OPENAI_URL}",
      "api": "openai-completions",
      "apiKey": "sandbox-isolated-token",
      "models": [
        {
          "id": "${JSON_MODEL_NAME}",
          "name": "${JSON_MODEL_NAME}",
          "reasoning": true,
          "input": ["text"],
          "contextWindow": ${CTX_WINDOW},
          "maxTokens": 8192,
          "cost": {
            "input": 0,
            "output": 0,
            "cacheRead": 0,
            "cacheWrite": 0
          }
        }
      ]
    }
  }
}
EOF

cat > "$HOME/.pi/agent/settings.json" << EOF
{
  "defaultProvider": "tnk",
  "defaultModel": "${JSON_MODEL_NAME}",
  "defaultProjectTrust": "always",
  "enableInstallTelemetry": false
}
EOF

PATH_SNIPPET='export PATH="$HOME/.local/bin:$PATH"'
if ! grep -q 'tnk pi' "$HOME/.bashrc" 2>/dev/null; then
    printf '\n# tnk pi\n%s\n' "$PATH_SNIPPET" >> "$HOME/.bashrc"
fi
if ! grep -q 'tnk pi' "$HOME/.profile" 2>/dev/null; then
    printf '\n# tnk pi\n%s\n' "$PATH_SNIPPET" >> "$HOME/.profile"
fi

chmod 700 "$HOME/.pi"
chmod 700 "$HOME/.pi/agent"
chmod 600 "$HOME/.pi/agent/models.json"
chmod 600 "$HOME/.pi/agent/settings.json"

_lib_finalize_provision_state

echo
echo "▗"
echo "▜▘▛▌▙▘"
echo "▐▖▌▌▛▖"
echo

echo "[ OK ] Pi environment initialized successfully."
echo ""
echo "   Model:        ${MODEL_NAME}"
echo "   Context:      ${CTX_WINDOW} tokens"
echo "   Engine URL:   ${OPENAI_URL}"
echo "   Workspace:    ${WORKSPACE_MOUNT}"
echo ""
echo "   Start Pi with: pi"
