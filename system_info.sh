#!/bin/bash

# --- Color Definitions ---
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# 1. System Versions & Board ID
L4T_REL="N/A"
BOARD_ID="N/A"
if [ -f /etc/nv_tegra_release ]; then
    L4T_RAW=$(head -n 1 /etc/nv_tegra_release)
    L4T_REL=$(echo "$L4T_RAW" | sed -E 's/.*(R[0-9]+) \(release\), REVISION: ([0-9.]+).*/\1 REV \2/')
    BOARD_ID=$(echo "$L4T_RAW" | grep -o "BOARD: [^,]*" | cut -d ' ' -f2)
fi

# 2. Bootloader & Power Mode
BL_VER=$(sudo nvbootctrl dump-slots-info 2>/dev/null | grep "Current version" | cut -d ':' -f2 | xargs || echo "N/A")
PWR_MODE=$(nvpmodel -q 2>/dev/null | grep "NV Power Mode" | cut -d ':' -f2 | xargs || echo "N/A")

# 3. Device Model & Connectivity
MODEL=$(cat /proc/device-tree/model 2>/dev/null | tr -d '\0' | xargs)
ping -c 1 8.8.8.8 >/dev/null 2>&1
[ $? -eq 0 ] && NET_STATUS="${GREEN}ONLINE${NC}" || NET_STATUS="${RED}OFFLINE${NC}"

# 4. A/B Slot & Docker Status
# Cleaned up Active Slot capture to prevent line breaks
ACTIVE_SLOT=$(sudo nvbootctrl dump-slots-info 2>/dev/null | grep "Active bootloader slot" | cut -d ':' -f2 | xargs)
SLOT_CONFIRM=$(sudo nvbootctrl dump-slots-info 2>/dev/null | grep -A 3 "slot: ${ACTIVE_SLOT:-0}" | grep "status" | awk '{print $2}' | tr -d ',' | xargs)
SLOT_DISPLAY="${ACTIVE_SLOT} (${SLOT_CONFIRM})"

DOCKER_COUNT=$(docker ps -q 2>/dev/null | wc -l)
if [ "$DOCKER_COUNT" -gt 0 ]; then
    DOCKER_STATUS="${RED}$DOCKER_COUNT Running${NC}"
else
    DOCKER_STATUS="${GREEN}None${NC}"
fi

# 5. Storage Logic
STORAGE_INFO=$(df -h / | tail -1)
DISK_USAGE_PCT=$(echo "$STORAGE_INFO" | awk '{print $5}' | sed 's/%//')
DISK_FREE=$(echo "$STORAGE_INFO" | awk '{print $4}')
if [ "$DISK_USAGE_PCT" -gt 85 ]; then
    STORAGE_VAL="${RED}${DISK_USAGE_PCT}% / ${DISK_FREE}${NC}"
else
    STORAGE_VAL="${DISK_USAGE_PCT}% / ${DISK_FREE}"
fi

# 6. Hardware IDs
CHIP_SKU=$(sudo hexdump -s 16 -n 4 -e '1/4 "%08x"' /sys/bus/nvmem/devices/fuse/nvmem 2>/dev/null)
BIOS_VER=$(cat /sys/class/dmi/id/bios_version 2>/dev/null | xargs)

# --- BUILD THE TABLE ---
# Padding note: Colored strings need ~11 extra spaces in the printf width to align correctly.
echo -e "\n${CYAN}========================================================${NC}"
echo -e "${YELLOW}           PRE-OTA DEVICE READINESS REPORT               ${NC}"
echo -e "${CYAN}========================================================${NC}"
printf "| %-22s | %-27s |\n" "Component" "Value"
echo -e "${CYAN}--------------------------------------------------------${NC}"
printf "| %-22s | %-27s |\n" "Device Model" "$MODEL"
printf "| %-22s | %-27s |\n" "Board ID" "$BOARD_ID"
printf "| %-22s | %-27s |\n" "L4T Release" "$L4T_REL"
printf "| %-22s | %-27s |\n" "Bootloader Version" "$BL_VER"
printf "| %-22s | %-27s |\n" "Power Mode" "$PWR_MODE"
printf "| %-22s | %-27s |\n" "Active Slot" "$SLOT_DISPLAY"
printf "| %-22s | %-38b |\n" "Internet Status" "$NET_STATUS"
printf "| %-22s | %-38b |\n" "Active Containers" "$DOCKER_STATUS"
printf "| %-22s | %-38b |\n" "Storage (Used/Free)" "$STORAGE_VAL"
printf "| %-22s | %-27s |\n" "Chip SKU" "$CHIP_SKU"
printf "| %-22s | %-27s |\n" "BIOS Version" "$BIOS_VER"
echo -e "${CYAN}========================================================${NC}"

# Logic Warnings
if [ "$DISK_USAGE_PCT" -gt 85 ]; then
    echo -e "${RED}!! WARNING: Low disk space! Free up space before OTA.${NC}"
fi
echo ""
