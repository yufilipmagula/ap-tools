#!/bin/bash

# --- Color Definitions ---
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 1. Extract L4T Release & Revision (Improved parsing)
if [ -f /etc/nv_tegra_release ]; then
    L4T_RAW=$(head -n 1 /etc/nv_tegra_release)
    # This pulls "R35 (release), REVISION: 4.1" and cleans it up
    L4T_REL=$(echo "$L4T_RAW" | sed -E 's/.*(R[0-9]+) \(release\), REVISION: ([0-9.]+).*/\1 REV \2/')
else
    L4T_REL="Not Found"
fi

# 2. Extract JetPack Version
JP_VER=$(apt-cache show nvidia-l4t-core 2>/dev/null | grep Version | head -n 1 | awk '{print $2}' || echo "N/A")

# 3. Extract Bootloader Info
BL_INFO=$(sudo nvbootctrl dump-slots-info 2>/dev/null)
BL_VER=$(echo "$BL_INFO" | grep "Current version" | cut -d ':' -f2 | xargs || echo "N/A")
BL_SLOT=$(echo "$BL_INFO" | grep "Active bootloader slot" | cut -d ':' -f2 | xargs || echo "N/A")

# 4. Kernel
KERNEL=$(uname -r)

# 5. Storage Logic
STORAGE_INFO=$(df -h / | tail -1)
DISK_USAGE_PCT=$(echo "$STORAGE_INFO" | awk '{print $5}' | sed 's/%//')
DISK_FREE=$(echo "$STORAGE_INFO" | awk '{print $4}")

# Color storage red if usage is > 90%
if [ "$DISK_USAGE_PCT" -gt 90 ]; then
    STORAGE_VAL="${RED}${DISK_USAGE_PCT}% / ${DISK_FREE}${NC}"
else
    STORAGE_VAL="${DISK_USAGE_PCT}% / ${DISK_FREE}"
fi

# 6. BIOS and Chip SKU
CHIP_SKU=$(sudo hexdump -s 16 -n 4 -e '1/4 "%08x"' /sys/bus/nvmem/devices/fuse/nvmem 2>/dev/null || echo "N/A")
BIOS_VER=$(cat /sys/class/dmi/id/bios_version 2>/dev/null | xargs || echo "N/A")

# --- BUILD THE TABLE ---
echo -e "${CYAN}========================================================${NC}"
echo -e "${YELLOW}           JETSON SYSTEM INFORMATION BASELINE           ${NC}"
echo -e "${CYAN}========================================================${NC}"
printf "| %-22s | %-27s |\n" "Component" "Value"
echo -e "${CYAN}--------------------------------------------------------${NC}"
printf "| %-22s | %-27b |\n" "L4T Release" "$L4T_REL"
printf "| %-22s | %-27b |\n" "JetPack Version" "$JP_VER"
printf "| %-22s | %-27b |\n" "Bootloader Version" "$BL_VER"
printf "| %-22s | %-27b |\n" "Active Slot" "$BL_SLOT"
printf "| %-22s | %-27b |\n" "Kernel" "$KERNEL"
printf "| %-22s | %-36b |\n" "Storage Used / Free" "$STORAGE_VAL"
printf "| %-22s | %-27b |\n" "Chip SKU (Fuses)" "$CHIP_SKU"
printf "| %-22s | %-27b |\n" "BIOS Version" "$BIOS_VER"
echo -e "${CYAN}========================================================${NC}"
