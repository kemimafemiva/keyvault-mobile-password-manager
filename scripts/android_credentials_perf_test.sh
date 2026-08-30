#!/bin/bash

# ============================================================
# KeyVault Credential Performance Test
# Pixel 7 Pro API 34
#
# KeyVault UI elements are located dynamically from the
# Android accessibility hierarchy.
# ============================================================

# Use 1 for validation, then change to 10.
TRIALS=10
FINGERPRINT_ID=1
MAX_WAIT=5

# ------------------------------------------------------------
# UI hierarchy
# ------------------------------------------------------------

dump_ui() {
    adb -e shell uiautomator dump /sdcard/window.xml \
        >/dev/null 2>&1

    adb -e shell cat /sdcard/window.xml 2>/dev/null
}

ui_contains() {
    local expected="$1"

    dump_ui |
        python3 -c '
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

    if expected in text or expected in content_desc:
        sys.exit(0)

sys.exit(1)
' "$expected"
}

wait_for_text() {
    local expected="$1"
    local elapsed=0

    while (( elapsed < MAX_WAIT * 10 )); do
        if ui_contains "$expected"; then
            return 0
        fi

        sleep 0.1
        ((elapsed++))
    done

    echo "ERROR: Timed out waiting for: $expected"
    return 1
}

wait_for_text_quietly() {
    local expected="$1"
    local attempts="$2"
    local elapsed=0

    while (( elapsed < attempts )); do
        if ui_contains "$expected"; then
            return 0
        fi

        sleep 0.1
        ((elapsed++))
    done

    return 1
}

# ------------------------------------------------------------
# Dynamic element lookup
# ------------------------------------------------------------

find_element_coordinates() {
    local expected="$1"
    local match_type="${2:-exact}"

    dump_ui |
        python3 -c '
import re
import sys
import xml.etree.ElementTree as ET

expected = sys.argv[1]
match_type = sys.argv[2]
xml = sys.stdin.read()

try:
    root = ET.fromstring(xml)
except Exception:
    sys.exit(1)

for node in root.iter("node"):
    text = node.attrib.get("text", "")
    content_desc = node.attrib.get("content-desc", "")

    if match_type == "exact":
        matched = (
            text == expected or
            content_desc == expected
        )
    else:
        matched = (
            expected in text or
            expected in content_desc
        )

    if not matched:
        continue

    bounds = node.attrib.get("bounds", "")

    match = re.match(
        r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]",
        bounds
    )

    if not match:
        continue

    left, top, right, bottom = map(
        int,
        match.groups()
    )

    print(
        f"{(left + right) // 2} "
        f"{(top + bottom) // 2}"
    )

    sys.exit(0)

sys.exit(1)
' "$expected" "$match_type"
}

tap_element_exact() {
    local expected="$1"
    local coordinates

    coordinates=$(
        find_element_coordinates "$expected" "exact"
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

tap_element_contains() {
    local expected="$1"
    local coordinates

    coordinates=$(
        find_element_coordinates "$expected" "contains"
    )

    if [[ -z "$coordinates" ]]; then
        echo "ERROR: Could not find element containing: $expected"
        return 1
    fi

    local x
    local y

    read -r x y <<< "$coordinates"

    adb -e shell input tap "$x" "$y"
}

# ------------------------------------------------------------
# Dynamic EditText lookup
# ------------------------------------------------------------

find_edit_text_coordinates() {
    local field_index="$1"

    dump_ui |
        python3 -c '
import re
import sys
import xml.etree.ElementTree as ET

field_index = int(sys.argv[1])
xml = sys.stdin.read()

try:
    root = ET.fromstring(xml)
except Exception:
    sys.exit(1)

fields = [
    node
    for node in root.iter("node")
    if node.attrib.get("class") == "android.widget.EditText"
]

if field_index >= len(fields):
    sys.exit(1)

node = fields[field_index]

bounds = node.attrib.get("bounds", "")

match = re.match(
    r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]",
    bounds
)

if not match:
    sys.exit(1)

left, top, right, bottom = map(
    int,
    match.groups()
)

print(
    f"{(left + right) // 2} "
    f"{(top + bottom) // 2}"
)
' "$field_index"
}

tap_edit_text() {
    local field_index="$1"
    local coordinates

    coordinates=$(
        find_edit_text_coordinates "$field_index"
    )

    if [[ -z "$coordinates" ]]; then
        echo "ERROR: Could not find EditText index $field_index"
        return 1
    fi

    local x
    local y

    read -r x y <<< "$coordinates"

    adb -e shell input tap "$x" "$y"
}

# ------------------------------------------------------------
# Form helpers
# ------------------------------------------------------------

enter_text() {
    local field_index="$1"
    local value="$2"

    if ! tap_edit_text "$field_index"; then
        return 1
    fi

    adb -e shell input text "$value"
}

clear_edit_text() {
    local field_index="$1"

    if ! tap_edit_text "$field_index"; then
        return 1
    fi

    sleep 0.05

    adb -e shell input keyevent KEYCODE_MOVE_END

    for ((j=0; j<30; j++)); do
        adb -e shell input keyevent KEYCODE_DEL
    done

    sleep 0.05
}

# ------------------------------------------------------------
# Dynamic authentication
# ------------------------------------------------------------

authenticate() {
    local elapsed=0

    echo "Waiting for authentication prompt..."

    while (( elapsed < MAX_WAIT * 10 )); do

        if ui_contains "Authentication required"; then

            echo "Authentication prompt detected"

            adb -e emu finger touch "$FINGERPRINT_ID" \
                >/dev/null 2>&1

            return 0
        fi

        sleep 0.1
        ((elapsed++))
    done

    echo "ERROR: Authentication prompt did not appear."
    return 1
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
echo "KeyVault Credential Performance Test"
echo "===================================================="
echo "Trials: $TRIALS"
echo
echo "Required starting state:"
echo "  - KeyVault unlocked"
echo "  - Vault empty"
echo "  - Empty Vault screen visible"
echo "  - No dialog open"
echo "  - Keyboard closed"
echo "  - Fingerprint $FINGERPRINT_ID enrolled"
echo
echo "Do not interact with the emulator during the test."
echo "===================================================="
echo

echo "Verifying empty vault..."

if ! wait_for_text "Your vault is empty"; then
    abort_test
fi

# ------------------------------------------------------------
# Trials
# ------------------------------------------------------------

for ((i=1; i<=TRIALS; i++)); do

    echo
    echo "========== TRIAL $i OF $TRIALS =========="

    # ========================================================
    # ADD
    # ========================================================

    echo "[$i] Opening Add Credential"

    if ! tap_element_exact "Add credential"; then
        abort_test
    fi

    if ! wait_for_text "Add Credential"; then
        abort_test
    fi

    echo "[$i] Entering credential"

    # EditText 0 = Service
    if ! enter_text 0 'Performance%sTest'; then
        abort_test
    fi

    # EditText 1 = Username or email
    if ! enter_text 1 'test@example.com'; then
        abort_test
    fi

    # EditText 2 = Password
    if ! enter_text 2 'TestPassword123!'; then
        abort_test
    fi

    # EditText 3 = Website
    if ! enter_text 3 'https://example.com'; then
        abort_test
    fi

    echo "[$i] Saving credential"

    if ! tap_element_exact "Save"; then
        abort_test
    fi

    # Add normally completes without another authentication.
    # If the Android Keystore authorization window has expired,
    # KeyVault requests authentication and retries the save once.
    if wait_for_text_quietly "Performance Test" 10; then

        echo "[$i] Add completed without reauthentication"

    else

        echo "[$i] Add requires Keystore reauthentication"

        if ! authenticate; then
            abort_test
        fi

        if ! wait_for_text "Performance Test"; then
            abort_test
        fi

    fi

    # ========================================================
    # OPEN DETAILS
    # ========================================================

    echo "[$i] Opening credential"

    if ! tap_element_contains "Performance Test"; then
        abort_test
    fi

    if ! wait_for_text "Edit"; then
        abort_test
    fi

    if ! wait_for_text "Delete"; then
        abort_test
    fi

    # ========================================================
    # EDIT
    # ========================================================

    echo "[$i] Opening Edit Credential"

    if ! tap_element_exact "Edit"; then
        abort_test
    fi

    if ! wait_for_text "Edit Credential"; then
        abort_test
    fi

    echo "[$i] Updating credential"

    # EditText 0 = Service
    if ! clear_edit_text 0; then
        abort_test
    fi

    adb -e shell input text 'Performance%sEdit'

    echo "[$i] Saving edited credential"

    if ! tap_element_exact "Save"; then
        abort_test
    fi

    # Edit deliberately requires one biometric
    # reauthentication.
    if ! authenticate; then
        abort_test
    fi

    # Successful Edit returns directly to the Vault.
    if ! wait_for_text "Performance Edit"; then
        abort_test
    fi

    # ========================================================
    # REOPEN UPDATED CREDENTIAL
    # ========================================================

    echo "[$i] Reopening edited credential"

    if ! tap_element_contains "Performance Edit"; then
        abort_test
    fi

    if ! wait_for_text "Edit"; then
        abort_test
    fi

    if ! wait_for_text "Delete"; then
        abort_test
    fi

    # ========================================================
    # DELETE
    # ========================================================

    echo "[$i] Opening Delete dialog"

    if ! tap_element_exact "Delete"; then
        abort_test
    fi

    if ! wait_for_text "Delete credential?"; then
        abort_test
    fi

    echo "[$i] Confirming deletion"

    if ! tap_element_exact "Delete"; then
        abort_test
    fi

    # Delete deliberately requires one biometric
    # reauthentication.
    if ! authenticate; then
        abort_test
    fi

    # Every trial must return to the same baseline.
    if ! wait_for_text "Your vault is empty"; then
        abort_test
    fi

    echo "[$i] COMPLETE"

done

echo
echo "===================================================="
echo "TEST COMPLETE"
echo "$TRIALS trial(s) successfully completed."
echo "Vault returned to empty state after every trial."
echo "===================================================="