#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

# shellcheck source=sandbox.d/container/provision.d/lib/provision-lib.sh
source "$(dirname "$0")/lib/provision-lib.sh"

PROFILE_REV="2026-07-06.7"

# Runtime values injected by tnk at execution time:
#   TNK_INFERENCE_URL   http://<backend-gateway>:8080/v1
#   TNK_OPENAI_URL      http://<backend-gateway>:8080/v1
#   TNK_MODEL_NAME      01-qwen3-6-35b-a3b
#   TNK_CTX_WINDOW      262144
#   TNK_WORKSPACE_MOUNT /workspace
#   TNK_SPECS_REV       sha256 of provision script content
#   TNK_SEARXNG_URL      http://<container-gateway>:18766
#   TNK_ENGINE_RUNTIME   inference runtime provider key (mlxcel, llama)

OPENAI_URL="${TNK_INFERENCE_URL:-${TNK_OPENAI_URL:-}}"
if [[ -z "$OPENAI_URL" ]]; then
    echo "[ERR] TNK_INFERENCE_URL (or TNK_OPENAI_URL) is required" >&2
    exit 1
fi
MODEL_NAME="${TNK_MODEL_NAME:?TNK_MODEL_NAME is required}"
CTX_WINDOW="${TNK_CTX_WINDOW:?TNK_CTX_WINDOW is required}"
WORKSPACE_MOUNT="${TNK_WORKSPACE_MOUNT:-/workspace}"
SEARXNG_URL="${TNK_SEARXNG_URL:?TNK_SEARXNG_URL is required}"
ENGINE="${TNK_ENGINE_RUNTIME:?TNK_ENGINE_RUNTIME is required}"

echo "[PROC] Commencing opencode workspace provision for target container..."

_lib_init_provision_state "opencode" "$PROFILE_REV" "$OPENAI_URL" "$MODEL_NAME" "$CTX_WINDOW" "$WORKSPACE_MOUNT"

export DEBIAN_FRONTEND=noninteractive
export NPM_CONFIG_PREFIX="$HOME/.local"
mkdir -p "$HOME/.local/bin" "$HOME/.local/lib"
export PATH="$HOME/.local/bin:$PATH"
NPM_NET_FLAGS=(--fetch-retries=5 --fetch-retry-mintimeout=2000 --fetch-retry-maxtimeout=120000 --fetch-timeout=600000)
CURL_NET_FLAGS=(--fail --show-error --location --connect-timeout 15 --max-time 180 --retry 4 --retry-delay 2 --retry-all-errors)

REQUIRED_NODE_VERSION="22.19.0"
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

echo "[PROC] Installing OpenAI-compatible provider package..."
npm install -g --loglevel=silent --yes "${NPM_NET_FLAGS[@]}" \
    "@ai-sdk/openai-compatible"

echo "[PROC] Installing SearXNG MCP server package..."
npm install -g --loglevel=silent --yes "${NPM_NET_FLAGS[@]}" mcp-searxng

echo "[PROC] Installing Astral UV package manager..."
UV_INSTALL_SCRIPT="$(mktemp)"
curl "${CURL_NET_FLAGS[@]}" "https://astral.sh/uv/install.sh" -o "$UV_INSTALL_SCRIPT"
sh "$UV_INSTALL_SCRIPT"
rm -f "$UV_INSTALL_SCRIPT"

echo "[PROC] Installing OpenCode CLI..."
OPENCODE_INSTALL_SCRIPT="$(mktemp)"
curl "${CURL_NET_FLAGS[@]}" "https://opencode.ai/install" -o "$OPENCODE_INSTALL_SCRIPT"
bash "$OPENCODE_INSTALL_SCRIPT"
rm -f "$OPENCODE_INSTALL_SCRIPT"

if [ -x "$HOME/.opencode/bin/opencode" ]; then
  export PATH="$HOME/.opencode/bin:$PATH"
fi

if ! command -v opencode >/dev/null 2>&1 && [ -x "$HOME/.local/bin/opencode" ]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

if ! command -v opencode >/dev/null 2>&1; then
  echo "[ERR] opencode installation did not produce an executable in PATH." >&2
  exit 1
fi

echo "[PROC] Generating OpenCode configuration..."
mkdir -p "$HOME/.opencode"

JSON_MODEL_NAME="$(printf '%s' "$MODEL_NAME" | sed 's/\\/\\\\/g; s/"/\\"/g')"
JSON_ENGINE="$(printf '%s' "$ENGINE" | sed 's/\\/\\\\/g; s/"/\\"/g')"
JSON_OPENAI_URL="$(printf '%s' "$OPENAI_URL" | sed 's/\\/\\\\/g; s/"/\\"/g')"
JSON_WORKSPACE_MOUNT="$(printf '%s' "$WORKSPACE_MOUNT" | sed 's/\\/\\\\/g; s/"/\\"/g')"
JSON_SEARXNG_URL="$(printf '%s' "$SEARXNG_URL" | sed 's/\\/\\\\/g; s/"/\\"/g')"

cat > "$HOME/.opencode/opencode.json" << EOF
{
  "\$schema": "https://opencode.ai/config.json",
  "model": "${JSON_ENGINE}/${JSON_MODEL_NAME}",
  "small_model": "${JSON_ENGINE}/${JSON_MODEL_NAME}",
  "autoupdate": false,

  "disabled_providers": [
    "opencode",
    "github-copilot",
    "openai",
    "anthropic",
    "google"
  ],

  "instructions": [
    "If filesystem_edit_file fails, immediately fallback to write_file to replace the entire content.",
    "CRITICAL ENV CONTEXT: You are running inside an isolated sandbox container (Debian 13 guest).",
    "Your home directory config files are strictly inside /home/user.guest/, and your project workspace is mounted at /workspace.",
    "Always run file and tool operations relative to /workspace or its subdirectories."
  ],

  "compaction": {
    "auto": true,
    "prune": false,
    "reserved": 16384,
    "tail_turns": 6
  },

  "permission": {
    "*": "allow",
    "bash": {
      "rm *": "ask",
      "sudo *": "ask",
      "dd *": "ask",
      "mkfs *": "ask",
      ":() { : | :& }; :": "deny"
    }
  },

  "provider": {
    "${JSON_ENGINE}": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "${JSON_ENGINE} (container)",
      "options": {
          "baseURL": "${JSON_OPENAI_URL}"
      },
      "models": {
        "${JSON_MODEL_NAME}": {
          "name": "${JSON_MODEL_NAME}",
          "tools": true,
          "context_window": ${CTX_WINDOW},
          "limit": {
            "context": ${CTX_WINDOW},
            "output": 8192
          }
        }
      }
    }
  },

  "mcp": {
    "memory": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-memory"],
      "enabled": true
    },
    "fetch": {
      "type": "local",
      "command": ["uvx", "mcp-server-fetch"],
      "enabled": false
    },
    "filesystem": {
      "type": "local",
       "command": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "${JSON_WORKSPACE_MOUNT}"],
      "enabled": true
    },
    "searxng": {
      "type": "local",
      "command": ["mcp-searxng", "--stdio"],
      "enabled": true,
      "environment": {
         "SEARXNG_URL": "${JSON_SEARXNG_URL}"
      }
    }
  },

  "agent": {
    "plan": {
      "mode": "primary",
      "model": "${JSON_ENGINE}/${JSON_MODEL_NAME}"
    },
    "build": {
      "mode": "primary",
      "model": "${JSON_ENGINE}/${JSON_MODEL_NAME}"
    },
    "review": {
      "mode": "subagent",
      "model": "${JSON_ENGINE}/${JSON_MODEL_NAME}",
      "tools": {
        "write": true,
        "edit": true,
        "bash": true
      }
    },
    "explore": {
      "mode": "subagent",
      "model": "${JSON_ENGINE}/${JSON_MODEL_NAME}",
      "tools": {
        "write": true,
        "edit": true,
        "bash": true
      }
    }
  },

  "default_agent": "build"
}
EOF

chmod 700 "$HOME/.opencode"
chmod 600 "$HOME/.opencode/opencode.json"

_lib_finalize_provision_state

echo
echo "▗"
echo "▜▘▛▌▙▘"
echo "▐▖▌▌▛▖"
echo

echo "[ OK ] Opencode environment initialized successfully."
echo ""
echo "   Model:        ${MODEL_NAME}"
echo "   Context:      ${CTX_WINDOW} tokens"
echo "   Engine URL:   ${OPENAI_URL}"
echo "   Workspace:    ${WORKSPACE_MOUNT}"

echo ""
echo "   Start Opencode with: opencode"
