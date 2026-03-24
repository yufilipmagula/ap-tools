#!/bin/sh
set -e

echo "--------------------------------"
echo "== OTA Update Preparation =="
 
# Download tools (Corrected curl command to save file)
curl -SL https://developer.nvidia.com/downloads/embedded/l4t/r35_release_v5.0/release/ota_tools_R35.5.0_aarch64.tbz2 -o ota_tools_R35.5.0_aarch64.tbz2
 
sudo mkdir -p /home/orin/ota-tools-dir
sudo tar -xvf ota_tools_R35.5.0_aarch64.tbz2 -C /home/orin/ota-tools-dir/
 
sudo mkdir -p /ota
sudo rm -f /ota/*
payload_copied=false
 
# Browse current directory and choose OTA payload package
set -- ota_payload*.tar.gz

if [ "$1" = "ota_payload*.tar.gz" ]; then
    echo "Warning: No payload package matching ota_payload*.tar.gz found in current directory."
else
    echo "Available OTA payload packages in current directory:"
    index=1
    for payload_file in "$@"; do
        printf "  [%d] %s\n" "$index" "$payload_file"
        index=$((index + 1))
    done

    while :; do
        printf "Select payload number (1-%d) or 0 to cancel: " "$#"
        if ! IFS= read -r selected_index; then
            echo "Input aborted."
            break
        fi

        case "$selected_index" in
            ''|*[!0-9]*)
                echo "Invalid selection. Please enter a valid number."
                continue
                ;;
        esac

        if [ "$selected_index" -eq 0 ]; then
            echo "Payload selection canceled by user."
            break
        fi

        if [ "$selected_index" -lt 1 ] || [ "$selected_index" -gt "$#" ]; then
            echo "Invalid selection. Please enter a valid number."
            continue
        fi

        index=1
        selected_payload=""
        for payload_file in "$@"; do
            if [ "$index" -eq "$selected_index" ]; then
                selected_payload="$payload_file"
                break
            fi
            index=$((index + 1))
        done

        printf "Use '%s'? [y/N]: " "$selected_payload"
        if ! IFS= read -r confirm_payload; then
            echo "Input aborted."
            break
        fi

        case "$confirm_payload" in
            y|Y)
                sudo cp "$selected_payload" /ota/ota_payload_package_AGX.tar.gz
                echo "Copied '$selected_payload' to /ota/ota_payload_package_AGX.tar.gz"
                payload_copied=true
                break
                ;;
            *)
                echo "Selection not confirmed. Please choose again."
                ;;
        esac
    done
fi

version_upgrade_dir="/home/orin/ota-tools-dir/Linux_for_Tegra/tools/ota_tools/version_upgrade"

if [ "$payload_copied" = true ]; then
    echo "== Preparation Complete =="
    echo "Starting OTA update automatically..."

    if [ -d "$version_upgrade_dir" ]; then
        cd "$version_upgrade_dir"
        sudo chattr -i /data/FLOW/runtime/*pem || true
        sudo ./nv_ota_start.sh /ota/ota_payload_package_AGX.tar.gz
    else
        echo "Error: OTA tools directory not found: $version_upgrade_dir"
        exit 1
    fi
else
    echo "== Preparation Incomplete =="
    echo "OTA update start skipped because no payload was copied."
fi
