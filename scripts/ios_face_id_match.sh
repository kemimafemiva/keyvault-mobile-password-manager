#!/bin/bash

FACE_ID_REQUESTS=${1:-21}
SIGNAL="/tmp/keyvault_faceid_request"

echo "Starting KeyVault iOS Face ID helper"
echo "Expected Face ID requests: $FACE_ID_REQUESTS"
echo

rm -f "$SIGNAL"

for ((i=1; i<=FACE_ID_REQUESTS; i++)); do

    echo "Waiting for Face ID request — $i of $FACE_ID_REQUESTS"

    while [ ! -f "$SIGNAL" ]; do
        sleep 0.05
    done

    # Give the native Face ID sheet a moment to become active
    # after KeyVault requested authentication.
    sleep 0.3
    echo "Supplying Matching Face — $i of $FACE_ID_REQUESTS"

    osascript -e '
    tell application "Simulator" to activate
    tell application "System Events"
        keystroke "m" using {option down, command down}
    end tell
    '

    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to trigger Matching Face."
        exit 1
    fi

    rm -f "$SIGNAL"

    echo "Face ID match supplied."
    echo

done

echo "Face ID helper complete."