#!/usr/bin/env bash
set -e
set -o pipefail

BASE_DIR="$HOME/Reactor"

REPO_DIR="$BASE_DIR/staging/deploy"
REPO_URL="https://github.com/KapibaraL/deploy.git"

AVRDUDE_DIR="$BASE_DIR/tools/avrdude"
AVRDUDE="$AVRDUDE_DIR/avrdude"

LOG_FILE="$BASE_DIR/logs/update_controllers.log"
STATE_FILE="$HOME/.config/Carbon_Ukraine/Backend/synthesis_state.json"

LOCAL_FW_DIR="$BASE_DIR/firmware"

MEGA_SUBDIR="Reactor/ControlHydraulicUnit/dev"
NANO_SUBDIR="Reactor/ControlReactorUnit/dev"

MEGA_HEX="$REPO_DIR/$MEGA_SUBDIR/firmware.hex"
NANO_HEX="$REPO_DIR/$NANO_SUBDIR/firmware.hex"

MEGA_REMOTE_VERSION_FILE="$REPO_DIR/$MEGA_SUBDIR/ControlHydraulicUnit.version"
NANO_REMOTE_VERSION_FILE="$REPO_DIR/$NANO_SUBDIR/ControlReactorUnit.version"

MEGA_LOCAL_VERSION_FILE="$LOCAL_FW_DIR/mega.version"
NANO_LOCAL_VERSION_FILE="$LOCAL_FW_DIR/nano.version"

mkdir -p "$BASE_DIR/logs" "$LOCAL_FW_DIR"

echo "=== Updating controllers ===" | tee -a "$LOG_FILE"

if [ -f "$STATE_FILE" ]; then
    if grep -q '"state"[[:space:]]*:[[:space:]]*"running"' "$STATE_FILE"; then
        echo "Synthesis is running. Controllers update is forbidden." | tee -a "$LOG_FILE"
        exit 0
    fi
fi

if [ ! -x "$AVRDUDE" ]; then
    echo "ERROR: avrdude not found or not executable: $AVRDUDE" | tee -a "$LOG_FILE"
    exit 1
fi

if [ ! -d "$REPO_DIR/.git" ]; then
    echo "Cloning repository..." | tee -a "$LOG_FILE"
    git clone "$REPO_URL" "$REPO_DIR" 2>&1 | tee -a "$LOG_FILE"
else
    echo "Pulling repository..." | tee -a "$LOG_FILE"
    cd "$REPO_DIR"
    git pull 2>&1 | tee -a "$LOG_FILE"
fi

if [ ! -f "$MEGA_HEX" ]; then
    echo "ERROR: Mega firmware not found: $MEGA_HEX" | tee -a "$LOG_FILE"
    exit 1
fi

if [ ! -f "$NANO_HEX" ]; then
    echo "ERROR: Nano firmware not found: $NANO_HEX" | tee -a "$LOG_FILE"
    exit 1
fi

if [ ! -f "$MEGA_REMOTE_VERSION_FILE" ]; then
    echo "ERROR: Mega version file not found: $MEGA_REMOTE_VERSION_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

if [ ! -f "$NANO_REMOTE_VERSION_FILE" ]; then
    echo "ERROR: Nano version file not found: $NANO_REMOTE_VERSION_FILE" | tee -a "$LOG_FILE"
    exit 1
fi

MEGA_LOCAL_VERSION="none"
NANO_LOCAL_VERSION="none"

MEGA_REMOTE_VERSION="$(cat "$MEGA_REMOTE_VERSION_FILE")"
NANO_REMOTE_VERSION="$(cat "$NANO_REMOTE_VERSION_FILE")"

if [ -f "$MEGA_LOCAL_VERSION_FILE" ]; then
    MEGA_LOCAL_VERSION="$(cat "$MEGA_LOCAL_VERSION_FILE")"
fi

if [ -f "$NANO_LOCAL_VERSION_FILE" ]; then
    NANO_LOCAL_VERSION="$(cat "$NANO_LOCAL_VERSION_FILE")"
fi

echo "Mega local version : $MEGA_LOCAL_VERSION" | tee -a "$LOG_FILE"
echo "Mega remote version: $MEGA_REMOTE_VERSION" | tee -a "$LOG_FILE"
echo "Nano local version : $NANO_LOCAL_VERSION" | tee -a "$LOG_FILE"
echo "Nano remote version: $NANO_REMOTE_VERSION" | tee -a "$LOG_FILE"

NEED_MEGA=0
NEED_NANO=0

if [ "$MEGA_LOCAL_VERSION" != "$MEGA_REMOTE_VERSION" ]; then
    NEED_MEGA=1
fi

if [ "$NANO_LOCAL_VERSION" != "$NANO_REMOTE_VERSION" ]; then
    NEED_NANO=1
fi

if [ "$NEED_MEGA" -eq 0 ] && [ "$NEED_NANO" -eq 0 ]; then
    echo "Controllers already up to date" | tee -a "$LOG_FILE"
    echo "=== Done ===" | tee -a "$LOG_FILE"
    exit 0
fi

echo "Stopping backend service..." | tee -a "$LOG_FILE"
systemctl --user stop backend.service || true

sleep 3

if [ "$NEED_MEGA" -eq 1 ]; then
    echo "Updating Mega from $MEGA_LOCAL_VERSION to $MEGA_REMOTE_VERSION" | tee -a "$LOG_FILE"

(
    cd "$AVRDUDE_DIR"

    "$AVRDUDE" 22 0 23 1 5 \
        -p m2560 \
        -D \
        -c wiring \
        -v \
        -P /dev/ttyAMA0 \
        -b 115200 \
        -U flash:w:"$MEGA_HEX":i
) 2>&1 | tee -a "$LOG_FILE"

    cp -f "$MEGA_REMOTE_VERSION_FILE" "$MEGA_LOCAL_VERSION_FILE"
fi

if [ "$NEED_NANO" -eq 1 ]; then
    echo "Updating Nano from $NANO_LOCAL_VERSION to $NANO_REMOTE_VERSION" | tee -a "$LOG_FILE"

(
    cd "$AVRDUDE_DIR"

    "$AVRDUDE" 22 1 23 0 5 \
        -p m328p \
        -c arduino \
        -v \
        -P /dev/ttyAMA0 \
        -b 57600 \
        -U flash:w:"$NANO_HEX":i
) 2>&1 | tee -a "$LOG_FILE"		

    cp -f "$NANO_REMOTE_VERSION_FILE" "$NANO_LOCAL_VERSION_FILE"
fi

echo "Starting backend service..." | tee -a "$LOG_FILE"
systemctl --user daemon-reload
systemctl --user start backend.service

echo "=== Done ===" | tee -a "$LOG_FILE"