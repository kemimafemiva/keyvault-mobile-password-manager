#!/bin/bash

# ============================================================
# KeyVault Automated Authentication Performance Test
# Pixel 7 Pro API 34
#
# KeyVault UI elements are located dynamically from the
# Android accessibility hierarchy.
# ============================================================

FINGERPRINT_ID=1
TRIALS=10
MAX_WAIT=5

# ------------------------------------------------------------
# UI hierarchy
# ------------------------------------------------------------

dump_ui() {
    adb -e shell uiautomator dump /sdcard/window.xml \
        >/dev/null 2>&1

    adb -e shell cat /sdcard/window.xml 2>/dev/null
}

wait_for_text() {
    local expected="$1"
    local elapsed=0

    while (( elapsed < MAX_WAIT * 10 )); do
        if dump_ui | grep -q "$expected"; then
            return 0
        fi

        sleep 0.1
        ((elapsed++))
    done

    echo "ERROR: Timed out waiting for: $expected"
    return 1
}

wait_for_text_to_disappear() {
    local expected="$1"
    local elapsed=0

    while (( elapsed < MAX_WAIT * 10 )); do
        if ! dump_ui | grep -q "$expected"; then
            return 0
        fi

        sleep 0.1
        ((elapsed++))
    done

    echo "ERROR: Timed out waiting for disappearance of: $expected"
    return 1
}

# ------------------------------------------------------------
# Dynamic element lookup
# ------------------------------------------------------------

tap_element() {
    local expected="$1"
    local coordinates

    coordinates=$(
        dump_ui |
        python3 -c '
import re
import sys
import xml.etree.ElementTree as ET

expected = sys.argv[1]
xml = sys.stdin.read()

try:
    root = ET.fromstring(xml)
except Exception:
    sys.exit(1)

for node in root.iter("node"):
    text = node.attrib.get("text", "")
    content_desc = node.attrib.get("content-desc", "")

    if text == expected or content_desc == expected:
        bounds = node.attrib.get("bounds", "")

        match = re.match(
            r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]",
            bounds
        )

        if match:
            left, top, right, bottom = map(
                int,
                match.groups()
            )

            x = (left + right) // 2
            y = (top + bottom) // 2

            print(f"{x} {y}")
            sys.exit(0)

sys.exit(1)
' "$expected"
    )

    if [[ -z "$coordinates" ]]; then
        echo "ERROR: Could not find element: $expected"
        return 1
    fi

    local x
    local y

    read -r x y <<< "$coordinates"

    adb -e shell input tap "$x" "$y"
}

# ------------------------------------------------------------
# Authentication
# ------------------------------------------------------------

authenticate() {
    # Give the Android biometric prompt enough time to appear.
    sleep 0.5

    adb -e emu finger touch "$FINGERPRINT_ID" \
        >/dev/null 2>&1
}

# ------------------------------------------------------------
# Failure handling
# ------------------------------------------------------------

abort_test() {
    echo
    echo "===================================================="
    echo "TEST ABORTED"
    echo "The expected KeyVault UI state was not reached."
    echo "Do not use incomplete trials in the final dataset."
    echo "===================================================="
    exit 1
}

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

echo
echo "===================================================="
echo "KeyVault Automated Authentication Performance Test"
echo "===================================================="
echo "Trials: $TRIALS"
echo "Fingerprint: $FINGERPRINT_ID"
echo
echo "Required starting state:"
echo "  - KeyVault locked"
echo "  - Lock screen visible"
echo "  - Fingerprint enrolled"
echo
echo "Do not interact with the emulator during the test."
echo "===================================================="
echo

echo "Verifying locked state..."

if ! wait_for_text "KeyVault is locked"; then
    abort_test
fi

if ! wait_for_text "Unlock"; then
    abort_test
fi

# ------------------------------------------------------------
# Authentication trials
# ------------------------------------------------------------

for ((i=1; i<=TRIALS; i++)); do

    echo
    echo "========== TRIAL $i OF $TRIALS =========="

    # ========================================================
    # UNLOCK
    # ========================================================

    echo "[$i] Unlocking KeyVault"

    if ! tap_element "Unlock"; then
        abort_test
    fi

    authenticate

    if ! wait_for_text_to_disappear "KeyVault is locked"; then
        abort_test
    fi

    if ! wait_for_text "Lock vault"; then
        abort_test
    fi

    echo "[$i] Authentication successful"

    # ========================================================
    # LOCK
    # ========================================================

    echo "[$i] Locking KeyVault"

    if ! tap_element "Lock vault"; then
        abort_test
    fi

    if ! wait_for_text "KeyVault is locked"; then
        abort_test
    fi

    if ! wait_for_text "Unlock"; then
        abort_test
    fi

    echo "[$i] COMPLETE"

done

echo
echo "===================================================="
echo "AUTHENTICATION TEST COMPLETE"
echo "$TRIALS trial(s) successfully completed."
echo "KeyVault returned to the locked state after every trial."
echo "===================================================="