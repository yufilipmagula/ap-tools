#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAPSULE_SRC="$SCRIPT_DIR/TEGRA_BL.Cap"
ESP_PATH="/esp_mount"
CAPSULE_DEST="$ESP_PATH/EFI/UpdateCapsule"
EFI_VAR="/sys/firmware/efi/efivars/OsIndications-8be4df61-93ca-11d2-aa0d-00e098032b8c"

echo "--- Starting Firmware Update Process ---"

# 1. Check if the source file exists first
if [ ! -f "$CAPSULE_SRC" ]; then
    echo "ERROR: $CAPSULE_SRC not found in script directory."
    exit 1
fi
echo "✓ Found source capsule file."

# 2. Create mount point and mount
sudo mkdir -p "$ESP_PATH" && echo "✓ Mount point ready." || { echo "Failed to create mount point"; exit 1; }

sudo mount /dev/mmcblk0p10 "$ESP_PATH" && echo "✓ Partition mounted successfully." || { echo "Failed to mount /dev/mmcblk0p10"; exit 1; }

# 3. Create UpdateCapsule directory
sudo mkdir -p "$CAPSULE_DEST" && echo "✓ UpdateCapsule directory verified/created." || { echo "Failed to create destination directory"; exit 1; }

# 4. Copy the file
sudo cp "$CAPSULE_SRC" "$CAPSULE_DEST/" && echo "✓ Capsule file copied to EFI partition." || { echo "Failed to copy capsule file"; exit 1; }

# 5. Trigger the update via EFI vars
printf "\x07\x00\x00\x00\x04\x00\x00\x00\x00\x00\x00\x00" > /tmp/var_tmp.bin
if sudo dd if=/tmp/var_tmp.bin of="$EFI_VAR" bs=12 2>/dev/null; then
    echo "✓ EFI OsIndications set successfully."
else
    echo "ERROR: Failed to write to EFI variables. Are you booted in UEFI mode?"
    exit 1
fi

echo "--- All steps completed successfully ---"

# 6. Final confirmation before reboot
echo ""
read -p "The firmware update is staged. Would you like to reboot now to apply? (y/N): " confirm
if [[ "$confirm" =~ ^[yY](es|ES|s|S)?$ ]]; then
    echo "Rebooting..."
    sudo reboot
else
    echo "Reboot aborted. The update will trigger on your next manual reboot."
fi
