#!/bin/bash
# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
# Configuration
HOSTNAME=$(hostname)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="backup_${HOSTNAME}_${TIMESTAMP}"
STAGING_DIR="/tmp/${BACKUP_NAME}"
FINAL_TAR="./${BACKUP_NAME}.tar.gz"
FINAL_ENC="./${BACKUP_NAME}.tar.gz.gpg"
# Check for Environment Variable
if [ -z "$BACKUP_PASS" ]; then
    echo -e "${RED}ERROR: Environment variable BACKUP_PASS is not set.${NC}"
    exit 1
fi
# 1. Create staging structure
mkdir -p "${STAGING_DIR}/openvpn_clients"
mkdir -p "${STAGING_DIR}/data_access"
mkdir -p "${STAGING_DIR}/dmp_config"
mkdir -p "${STAGING_DIR}/flow_runtime"
# 2. Perform actions
echo "Starting backup process..."
cp -r /etc/openvpn/clients/* "${STAGING_DIR}/openvpn_clients/" 2>/dev/null
STATUS_OVPN=$?
cp -r /k3s/persistent/data-access/* "${STAGING_DIR}/data_access/" 2>/dev/null
STATUS_K3S=$?
cp -r /etc/yu-ap-dmp-client/conf/* "${STAGING_DIR}/dmp_config/" 2>/dev/null
STATUS_DMP=$?
FLOW_SRC="/data/FLOW/runtime"
for pattern in "*.json" "*.pem" "cube_*" "*.info" "*.key" "td.ini"; do
    cp -r ${FLOW_SRC}/${pattern} "${STAGING_DIR}/flow_runtime/" 2>/dev/null
done
[ "$(ls -A ${STAGING_DIR}/flow_runtime 2>/dev/null)" ] && STATUS_FLOW=0 || STATUS_FLOW=1
kubectl describe configmap advanced-perception--rules-evaluator -n advanced-perception > "${STAGING_DIR}/rules_evaluator_describe.txt" 2>&1
STATUS_KUBE=$?
# 3. Final Compression & Encryption
# Create the tar.gz first
tar -czf "${FINAL_TAR}" -C /tmp "${BACKUP_NAME}" 2>/dev/null
STATUS_TAR=$?
# Encrypt the tar.gz using the password from env
if [ $STATUS_TAR -eq 0 ]; then
    echo "$BACKUP_PASS" | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 -o "${FINAL_ENC}" "${FINAL_TAR}" 2>/dev/null
    STATUS_ENC=$?
    rm -f "${FINAL_TAR}" # Remove the unencrypted original
else
    STATUS_ENC=1
fi
# 4. Cleanup staging
rm -rf "${STAGING_DIR}"
# --- Helper Function ---
check_status() {
    if [ $1 -eq 0 ]; then echo -e "${GREEN}SUCCESS${NC}"; else echo -e "${RED}FAILED${NC}"; fi
}
# --- RESULTS TABLE ---
echo -e "\nBackup Summary for ${HOSTNAME}:"
echo "--------------------------------------------------------"
printf "| %-35s | %-21s |\n" "Action" "Status"
echo "--------------------------------------------------------"
printf "| %-35s | %-21b |\n" "Copy OpenVPN Clients" "$(check_status $STATUS_OVPN)"
printf "| %-35s | %-21b |\n" "Copy K3s Data Access" "$(check_status $STATUS_K3S)"
printf "| %-35s | %-21b |\n" "Copy DMP Config" "$(check_status $STATUS_DMP)"
printf "| %-35s | %-21b |\n" "Copy FLOW Runtime (Filtered)" "$(check_status $STATUS_FLOW)"
printf "| %-35s | %-21b |\n" "Kubectl Describe ConfigMap" "$(check_status $STATUS_KUBE)"
printf "| %-35s | %-21b |\n" "Encryption (AES-256)" "$(check_status $STATUS_ENC)"
echo "--------------------------------------------------------"
if [ $STATUS_ENC -eq 0 ]; then
    echo -e "Result: ${GREEN}${FINAL_ENC}${NC}\n"
else
    echo -e "Result: ${RED}Backup/Encryption failed.${NC}\n"
fi
