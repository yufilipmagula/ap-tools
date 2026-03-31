#!/bin/bash

# Define variables
MOUNT_POINT="/esp_mount"
DEVICE="/dev/mmcblk0p10"
TOOLS_DIR="/home/orin/ap-tools"
FILES=("VerFix.efi" "startup.nsh")

# Function to check the status of the last command
check_status() {
    if [ $? -ne 0 ]; then
        echo "ERROR: $1 failed. Exiting script."
        exit 1
    else
        echo "SUCCESS: $1 completed."
    fi
}

# 1. Ensure the script is run with sudo/root
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root (use sudo)."
    exit 1
fi

# 2. Update and Install efibootmgr
echo "Updating package lists..."
apt update
check_status "apt update"

echo "Installing efibootmgr..."
apt install -y efibootmgr
check_status "apt install efibootmgr"

# 3. Handle mounting
echo "Creating mount point and mounting $DEVICE..."
mkdir -p "$MOUNT_POINT"
mount "$DEVICE" "$MOUNT_POINT"
check_status "Mounting $DEVICE"

# 4. Copy files
for file in "${FILES[@]}"; do
    if [ -f "$TOOLS_DIR/$file" ]; then
        cp "$TOOLS_DIR/$file" "$MOUNT_POINT/."
        check_status "Copying $file"
    else
        echo "ERROR: Source file $TOOLS_DIR/$file not found!"
        umount "$MOUNT_POINT"
        exit 1
    fi
done

# 5. Unmount
umount "$MOUNT_POINT"
check_status "Unmounting $MOUNT_POINT"

# 6. Identify EFI Shell entry
echo "Searching for EFI Shell boot entry..."
SHELL_ENTRY=$(efibootmgr | grep -i "shell" | head -n1 | grep -oP 'Boot\K[0-9A-Fa-f]{4}')

if [ -z "$SHELL_ENTRY" ]; then
    echo "ERROR: Could not find an EFI Shell boot entry."
    efibootmgr
    exit 1
fi

echo "Found Shell entry: $SHELL_ENTRY"

# 7. Set BootNext
efibootmgr --bootnext "$SHELL_ENTRY"
check_status "Setting BootNext to $SHELL_ENTRY"

# 8. User Confirmation for Reboot
echo "----------------------------------------------------"
efibootmgr | grep "BootNext"
echo "----------------------------------------------------"
read -p "The next boot is set to Shell. Do you want to reboot now? (y/n): " confirm

if [[ "$confirm" == [yY] || "$confirm" == [yY][eE][sS] ]]; then
    echo "Rebooting..."
    reboot
else
    echo "Reboot canceled. Please reboot manually when ready."
fi
