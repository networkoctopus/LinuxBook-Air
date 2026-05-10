#!/bin/bash

# ===== USER CONFIG =====
ROOT_COMPLEXES=("00:1c.0" "00:1c.4")
ENDPOINT="02:00.0"
ASPM_SETTING=3
# ======================

GREEN="\033[01;32m"
YELLOW="\033[01;33m"
NORMAL="\033[00m"
BLUE="\033[34m"
RED="\033[31m"
CYAN="\033[36m"

MAX_SEARCH=20
ASPM_BYTE_ADDRESS="INVALID"

# Ensure root
if [[ $(id -u) != 0 ]]; then
    echo "This needs to be run as root"
    exit 1
fi

device_present() {
    /usr/bin/lspci | grep -q "$1"
    return $?
}

find_aspm_byte_address() {
    local DEV=$1
    local SEARCH_COUNT=1

    SEARCH=$(/usr/bin/setpci -s $DEV 34.b)

    while [[ $SEARCH != 10 && $SEARCH_COUNT -le $MAX_SEARCH ]]; do
        END_SEARCH=$(/usr/bin/setpci -s $DEV ${SEARCH}.b)

        SEARCH_UPPER=$(printf "%X" 0x${SEARCH})

        if [[ $END_SEARCH = 10 ]]; then
            ASPM_BYTE_ADDRESS=$(echo "obase=16; ibase=16; $SEARCH_UPPER + 10" | bc)
            return 0
        fi

        SEARCH=$(echo "obase=16; ibase=16; $SEARCH + 1" | bc)
        SEARCH=$(/usr/bin/setpci -s $DEV ${SEARCH}.b)

        SEARCH_COUNT=$((SEARCH_COUNT+1))
    done

    echo "Failed to find ASPM register for $DEV"
    return 1
}

enable_aspm_byte() {
    local DEV=$1

    if ! device_present $DEV; then
        echo -e "Device ${BLUE}${DEV}${NORMAL} ${RED}not present${NORMAL}"
        return
    fi

    find_aspm_byte_address $DEV || return

    ASPM_BYTE_HEX=$(/usr/bin/setpci -s $DEV ${ASPM_BYTE_ADDRESS}.b)
    ASPM_BYTE_HEX=$(printf "%X" 0x${ASPM_BYTE_HEX})

    DESIRED_ASPM_BYTE_HEX=$(printf "%X" $(( (0x${ASPM_BYTE_HEX} & ~0x7) | ASPM_SETTING )))

    echo -e "$(lspci -s $DEV)"
    echo -en "\t0x${ASPM_BYTE_ADDRESS}: 0x${ASPM_BYTE_HEX} -> 0x${DESIRED_ASPM_BYTE_HEX} ... "

    if [[ $ASPM_BYTE_HEX = $DESIRED_ASPM_BYTE_HEX ]]; then
        echo -e "[${GREEN}ALREADY SET${NORMAL}]"
        return
    fi

    # 🔁 Retry logic (3 attempts, 2s apart)
    for i in {1..3}; do
        /usr/bin/setpci -s $DEV ${ASPM_BYTE_ADDRESS}.b=${ASPM_SETTING}:3
        sleep 2

        ACTUAL=$(/usr/bin/setpci -s $DEV ${ASPM_BYTE_ADDRESS}.b)
        ACTUAL=$(printf "%X" 0x${ACTUAL})

        if [[ $ACTUAL == $DESIRED_ASPM_BYTE_HEX ]]; then
            echo -e "[${GREEN}SUCCESS${NORMAL}] (attempt $i)"
            return 0
        fi

        echo -en "[retry $i: got 0x${ACTUAL}] "
    done

    echo -e "[${RED}FAIL${NORMAL}] (final 0x${ACTUAL})"
    return 1
}

# ===== RUN =====

echo -e "${CYAN}Root complexes:${NORMAL}"
for ROOT in "${ROOT_COMPLEXES[@]}"; do
    echo -e "${YELLOW}Processing $ROOT${NORMAL}"
    enable_aspm_byte $ROOT
    echo
done

echo -e "${CYAN}Endpoint:${NORMAL}"
enable_aspm_byte $ENDPOINT
echo
