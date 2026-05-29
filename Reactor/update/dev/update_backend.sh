#!/usr/bin/env bash
set -e

BASE_DIR="/home/asus/Reactor"

REPO_DIR="$BASE_DIR/staging/deploy"
REPO_URL="https://github.com/KapibaraL/deploy.git"

BIN_SUBDIR="Reactor/Backend/dev"
BIN_NAME="backend"

TARGET_BIN="$BASE_DIR/bin/reactor-backend"
BACKUP_DIR="$BASE_DIR/backup/backend"
LOG_FILE="$BASE_DIR/logs/update_backend.log"

SOURCE_BIN="$REPO_DIR/$BIN_SUBDIR/$BIN_NAME"

LOCAL_VERSION_FILE="$BASE_DIR/bin/reactor-backend.version"
REMOTE_VERSION_FILE="$REPO_DIR/$BIN_SUBDIR/backend.version"

mkdir -p "$BASE_DIR/bin" "$BACKUP_DIR" "$BASE_DIR/logs"

STATE_FILE="$BASE_DIR/data/synthesis_state.json"

STATE_FILE="/home/asus/.config/Carbon_Ukraine/Backend/synthesis_state.json"

if [ -f "$STATE_FILE" ]; then
    if grep -q '"state"[[:space:]]*:[[:space:]]*"running"' "$STATE_FILE"; then
        echo "Synthesis is running. Backend update is forbidden."
        exit 0
    fi
fi
echo "=== Updating backend ===" | tee -a "$LOG_FILE"

if [ ! -d "$REPO_DIR/.git" ]; then
    echo "Cloning repository..." | tee -a "$LOG_FILE"
    git clone "$REPO_URL" "$REPO_DIR" 2>&1 | tee -a "$LOG_FILE"
else
    echo "Pulling repository..." | tee -a "$LOG_FILE"
    cd "$REPO_DIR"
    git pull 2>&1 | tee -a "$LOG_FILE"
fi

echo "Source binary: $SOURCE_BIN" | tee -a "$LOG_FILE"

if [ ! -f "$SOURCE_BIN" ]; then
    echo "ERROR: backend binary not found: $SOURCE_BIN" | tee -a "$LOG_FILE"
    exit 1
fi

if [ ! -f "$REMOTE_VERSION_FILE" ]; then
    echo "ERROR: remote version file not found: $REMOTE_VERSION_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

LOCAL_VERSION="none"
REMOTE_VERSION="$(cat "$REMOTE_VERSION_FILE")"

if [ -f "$LOCAL_VERSION_FILE" ]; then
    LOCAL_VERSION="$(cat "$LOCAL_VERSION_FILE")"
fi

echo "Local version : $LOCAL_VERSION" | tee -a "$LOG_FILE"
echo "Remote version: $REMOTE_VERSION" | tee -a "$LOG_FILE"

if [ "$LOCAL_VERSION" = "$REMOTE_VERSION" ]; then
    echo "Backend already up to date" | tee -a "$LOG_FILE"
    echo "=== Done ===" | tee -a "$LOG_FILE"
    exit 0
fi

echo "Updating backend from $LOCAL_VERSION to $REMOTE_VERSION" | tee -a "$LOG_FILE"

echo "Stopping backend service..." | tee -a "$LOG_FILE"
systemctl --user stop backend.service || true

echo "Killing backend process if still alive..." | tee -a "$LOG_FILE"
pkill -f "$TARGET_BIN" || true

sleep 5

if [ -f "$TARGET_BIN" ]; then
    BACKUP_FILE="$BACKUP_DIR/reactor-backend.$(date +%Y%m%d_%H%M%S)"
    echo "Backing up current backend to $BACKUP_FILE" | tee -a "$LOG_FILE"
    cp -f "$TARGET_BIN" "$BACKUP_FILE"
fi

echo "Installing new backend..." | tee -a "$LOG_FILE"
cp -f "$SOURCE_BIN" "$TARGET_BIN"
chmod +x "$TARGET_BIN"
cp -f "$REMOTE_VERSION_FILE" "$LOCAL_VERSION_FILE"

echo "Starting backend service..." | tee -a "$LOG_FILE"
systemctl --user daemon-reload
systemctl --user start backend.service

echo "Backend status:" | tee -a "$LOG_FILE"
systemctl --user --no-pager status backend.service | tee -a "$LOG_FILE"

echo "=== Done ===" | tee -a "$LOG_FILE"