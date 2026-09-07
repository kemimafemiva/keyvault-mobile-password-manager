#!/bin/bash

# ============================================================
# KeyVault Android Session Expiry Integration Test
# Pixel 7 Pro API 34
#
# Verifies that credential encryption is rejected after the
# 300-second Android Keystore authentication validity period
# and succeeds after one biometric reauthentication.
# ============================================================

FINGERPRINT_ID=1
AUTHENTICATION_VALIDITY_SECONDS=300
EXPIRY_WAIT_SECONDS=310
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

wait_for_text_to_disappear() {
    local expected="$1"
    local elapsed=0

    while (( elapsed < MAX_WAIT * 10 )); do
        if ! ui_contains "$expected"; then
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
        matched = text == expected or content_desc == expected
    else:
        matched = expected in text or expected in content_desc

    if not matched:
        continue

    bounds = node.attrib.get("bounds", "")

    match = re.match(
        r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]",
        bounds
    )

    if not match:
        continue

    left, top, right, bottom = map(int, match.groups())

    print(f"{(left + right) // 2} {(top + bottom) // 2}")
    sys.exit(0)

sys.exit(1)
' "$expected" "$match_type"
}

tap_element_exact() {
    local expected="$1"
    local coordinates

    coordinates=$(find_element_coordinates "$expected" "exact")

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

bounds = fields[field_index].attrib.get("bounds", "")

match = re.match(
    r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]",
    bounds
)

if not match:
    sys.exit(1)

left, top, right, bottom = map(int, match.groups())

print(f"{(left + right) // 2} {(top + bottom) // 2}")
' "$field_index"
}

tap_edit_text() {
    local field_index="$1"
    local coordinates

    coordinates=$(find_edit_text_coordinates "$field_index")

    if [[ -z "$coordinates" ]]; then
        echo "ERROR: Could not find EditText index $field_index"
        return 1
    fi

    local x
    local y

    read -r x y <<< "$coordinates"

    adb -e shell input tap "$x" "$y"
}

enter_text() {
    local field_index="$1"
    local value="$2"

    if ! tap_edit_text "$field_index"; then
        return 1
    fi

    adb -e shell input text "$value"
}

# ------------------------------------------------------------
# Authentication
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
    echo "TEST FAILED"
    echo "The expected KeyVault state was not reached."
    echo "===================================================="
    exit 1
}

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

echo
echo "===================================================="
echo "KeyVault Android Session Expiry Integration Test"
echo "===================================================="
echo "Keystore validity: $AUTHENTICATION_VALIDITY_SECONDS seconds"
echo "Test wait: $EXPIRY_WAIT_SECONDS seconds"
echo
echo "Required starting state:"
echo "  - KeyVault locked"
echo "  - Lock screen visible"
echo "  - Vault empty"
echo "  - Fingerprint $FINGERPRINT_ID enrolled"
echo
echo "Do not interact with the emulator during the test."
echo "Do not background KeyVault during the wait."
echo "===================================================="
echo

# ------------------------------------------------------------
# INITIAL UNLOCK
# ------------------------------------------------------------

echo "Verifying locked state..."

if ! wait_for_text "KeyVault is locked"; then
    abort_test
fi

if ! tap_element_exact "Unlock"; then
    abort_test
fi

if ! authenticate; then
    abort_test
fi

if ! wait_for_text_to_disappear "KeyVault is locked"; then
    abort_test
fi

if ! wait_for_text "Your vault is empty"; then
    abort_test
fi

echo "Initial authentication successful"

# ------------------------------------------------------------
# ADD CREDENTIAL
# ------------------------------------------------------------

echo "Opening Add Credential"

if ! tap_element_exact "Add credential"; then
    abort_test
fi

if ! wait_for_text "Add Credential"; then
    abort_test
fi

echo "Entering credential"

if ! enter_text 0 'Session%sExpiry'; then
    abort_test
fi

if ! enter_text 1 'expiry@example.com'; then
    abort_test
fi

if ! enter_text 2 'TestPassword123!'; then
    abort_test
fi

if ! enter_text 3 'https://example.com'; then
    abort_test
fi

# ------------------------------------------------------------
# WAIT FOR KEYSTORE AUTHORIZATION TO EXPIRE
# ------------------------------------------------------------

echo
echo "Waiting $EXPIRY_WAIT_SECONDS seconds for Keystore authorization to expire..."
echo "Do not interact with the emulator."

for ((remaining=EXPIRY_WAIT_SECONDS; remaining>0; remaining--)); do
    if (( remaining % 60 == 0 || remaining <= 10 )); then
        echo "$remaining second(s) remaining..."
    fi

    sleep 1
done

echo
echo "Authentication validity period has expired."

# ------------------------------------------------------------
# SAVE AFTER EXPIRY
# ------------------------------------------------------------

echo "Attempting to save credential after expiry"

if ! tap_element_exact "Save"; then
    abort_test
fi

# Saving must now require authentication. If the credential
# appears immediately, the expected Keystore expiry was not
# enforced and the test must fail.
sleep 0.5

if ui_contains "Session Expiry"; then
    echo "ERROR: Credential was saved without reauthentication after expiry."
    abort_test
fi

if ! authenticate; then
    echo "ERROR: Expected biometric reauthentication after expiry."
    abort_test
fi

# ------------------------------------------------------------
# VERIFY AUTOMATIC RETRY
# ------------------------------------------------------------

echo "Verifying automatic save retry"

if ! wait_for_text "Session Expiry"; then
    echo "ERROR: Credential was not saved after reauthentication."
    abort_test
fi

echo
echo "===================================================="
echo "TEST PASSED"
echo "Android Keystore authorization expired after the"
echo "$AUTHENTICATION_VALIDITY_SECONDS-second validity period."
echo
echo "KeyVault:"
echo "  - rejected the first save attempt"
echo "  - requested biometric authentication"
echo "  - retried the save automatically"
echo "  - successfully stored the credential"
echo "===================================================="