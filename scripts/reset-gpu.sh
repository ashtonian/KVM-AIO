#!/bin/sh

GUEST_NAME="$1"
HOOK_NAME="$2"
STATE_NAME="$3"
# MISC="${@:4}"

touch /tmp/hook-${GUEST_NAME}-${HOOK_NAME}-${STATE_NAME}.ran
# if [[ "${HOOK_NAME}" == "start" ]] && [[ "${GUEST_NAME}" == "macOS" ]]; then
    echo 'device_specific' > /sys/bus/pci/devices/0000:0c:00.0/reset_method
# fi