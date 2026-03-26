#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SESSION_NAME="${1:-servers}"
WINDOW_NAME="${TESPRESSE_VOICE_WINDOW:-tespresse-voice}"
HOST="${TESPRESSE_VOICE_HOST:-127.0.0.1}"
PORT="${TESPRESSE_VOICE_PORT:-8000}"
SERVER_HOME="${TESPRESSE_VOICE_HOME:-$HOME/servers/tespresse-voice}"
VENV_PATH="$SERVER_HOME/.venv"
PREFERRED_PYTHON="${TESPRESSE_VOICE_PYTHON:-$(command -v python3.11 || command -v python3.12 || command -v python3.13 || command -v python3 || true)}"

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "tmux session '$SESSION_NAME' does not exist" >&2
  exit 1
fi

if [ -z "$PREFERRED_PYTHON" ]; then
  echo "Could not find a usable Python interpreter (tried python3.11, python3.12, python3.13, python3)." >&2
  exit 1
fi

if ! command -v espeak-ng >/dev/null 2>&1; then
  echo "Installing espeak-ng via Homebrew..."
  brew install espeak-ng
fi

mkdir -p "$SERVER_HOME"

DESIRED_PYTHON_VERSION="$("$PREFERRED_PYTHON" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
CURRENT_VENV_VERSION=""
if [ -x "$VENV_PATH/bin/python" ]; then
  CURRENT_VENV_VERSION="$("$VENV_PATH/bin/python" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
fi

if [ ! -d "$VENV_PATH" ] || [ "$CURRENT_VENV_VERSION" != "$DESIRED_PYTHON_VERSION" ]; then
  echo "Creating voice server virtualenv at $VENV_PATH with Python $DESIRED_PYTHON_VERSION"
  uv venv --clear --seed --python "$PREFERRED_PYTHON" "$VENV_PATH"
fi

echo "Installing MLX-Audio server dependencies..."
uv pip install --python "$VENV_PATH/bin/python" \
  "setuptools<81" \
  "mlx-audio==0.4.1" \
  "misaki[en]>=0.9" \
  "fastapi>=0.115" \
  "uvicorn>=0.30" \
  "python-multipart>=0.0.9" \
  "webrtcvad>=2.0.10"

if tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' | rg -xq "$WINDOW_NAME"; then
  tmux kill-window -t "$SESSION_NAME:$WINDOW_NAME"
fi

SERVER_COMMAND="cd '$ROOT_DIR' && PATH='$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH' '$VENV_PATH/bin/python' -m uvicorn mlx_audio.server:app --host '$HOST' --port '$PORT'"

tmux new-window -d -t "$SESSION_NAME" -n "$WINDOW_NAME" "$SERVER_COMMAND"

echo "Started MLX-Audio server in tmux session '$SESSION_NAME' window '$WINDOW_NAME'"
echo "Server URL: http://$HOST:$PORT"
