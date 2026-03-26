#!/bin/zsh
set -euo pipefail

SESSION_NAME="${1:-servers}"
WINDOW_NAME="${TESPRESSE_VOICE_WINDOW:-tespresse-voice}"

if ! tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "tmux session '$SESSION_NAME' does not exist" >&2
  exit 1
fi

if tmux list-windows -t "$SESSION_NAME" -F '#{window_name}' | rg -xq "$WINDOW_NAME"; then
  tmux kill-window -t "$SESSION_NAME:$WINDOW_NAME"
  echo "Stopped MLX-Audio server window '$WINDOW_NAME' in session '$SESSION_NAME'"
else
  echo "Window '$WINDOW_NAME' is not running in session '$SESSION_NAME'"
fi
