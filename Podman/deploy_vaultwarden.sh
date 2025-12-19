#!/bin/bash

# --- Configuration ---
VW_PORT=22929
CURRENT_USER=$(whoami)
QUADLET_DIR="$HOME/.config/containers/systemd"
VW_IMAGE="ghcr.io/dani-garcia/vaultwarden:latest"
REQUIRED_VERSION="4.4.0"

# ANSI Color Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 1. Environment & Privilege Check
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: This script must be run as a non-root user.${NC}"
    exit 1
fi

# 2. Quadlet Support Check
PODMAN_VERSION=$(podman version --format '{{.Client.Version}}')
if [ "$(printf '%s\n%s' "$REQUIRED_VERSION" "$PODMAN_VERSION" | sort -V | head -n1)" != "$REQUIRED_VERSION" ]; then
    echo -e "${RED}Error: Podman version ($PODMAN_VERSION) < $REQUIRED_VERSION. Quadlet is not supported.${NC}"
    exit 1
fi

# 3. Argon2 Dependency Check
if ! command -v argon2 &> /dev/null; then
    echo -e "${RED}Error: 'argon2' is not installed.${NC}"
    echo -e "${YELLOW}Please install it using: sudo apt update && sudo apt install argon2${NC}"
    exit 1
fi

# 4. Pull Container Image
echo -e "${CYAN}Step 1: Pulling latest Vaultwarden image...${NC}"
podman pull "$VW_IMAGE"

# 5. Named Volume Management
if ! podman volume exists vaultwarden; then
    echo -e "${CYAN}Step 2: Creating persistent volume 'vaultwarden'...${NC}"
    podman volume create vaultwarden
else
    echo -e "${GREEN}Info: Volume 'vaultwarden' already exists.${NC}"
fi

# 6. Admin Token Generation
echo -e "${CYAN}Step 3: Configuring Admin Token...${NC}"
read -rs -p "Enter Vaultwarden admin panel password: " ADMIN_PASS
echo
read -rs -p "Confirm admin panel password: " ADMIN_PASS_CONFIRM
echo

if [ "$ADMIN_PASS" != "$ADMIN_PASS_CONFIRM" ]; then
    echo -e "${RED}Error: Passwords do not match. Exiting.${NC}"
    exit 1
fi

# Generate Argon2 hash and escape '$' for Systemd (requires '$$')
RAW_HASH=$(echo -n "$ADMIN_PASS" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4)
ESCAPED_HASH=$(echo "$RAW_HASH" | sed 's/\$/\$\$/g')

# 7. Generate Quadlet File
echo -e "${CYAN}Step 4: Generating Quadlet configuration...${NC}"
mkdir -p "$QUADLET_DIR"

cat <<EOF > "$QUADLET_DIR/vaultwarden.container"
[Unit]
Description=Vaultwarden Password Manager (Quadlet)
After=network-online.target

[Container]
Image=$VW_IMAGE
Volume=vaultwarden:/data:Z
PublishPort=$VW_PORT:$VW_PORT
Environment=ROCKET_PORT=$VW_PORT
Environment=ADMIN_TOKEN=$ESCAPED_HASH
Annotation=io.containers.autoupdate=registry

[Service]
Restart=always
MemoryMax=512M

[Install]
WantedBy=default.target
EOF

# 8. Systemd Reload & Service Restart
echo -e "${CYAN}Step 5: Reloading systemd and restarting service...${NC}"
systemctl --user daemon-reload

systemctl --user restart vaultwarden.service &
pid=$! 
spin='-\|/'
echo -n "Waiting for service to stabilize... "
while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\rWaiting for service to stabilize... ${spin:$i:1}"
    sleep 0.1
done
printf "\r${GREEN}Service stabilized!                     ${NC}\n"

# 9. Check Linger Status
LINGER_STATUS=$(ls /var/lib/systemd/linger/"$CURRENT_USER" 2>/dev/null)

# 10. Deployment Summary
echo -e "\n${GREEN}===================================================${NC}"
if systemctl --user is-active --quiet vaultwarden.service; then
    echo -e "${GREEN}SUCCESS: Vaultwarden deployment is complete!${NC}"
    echo -e "${YELLOW}URL: http://$(hostname -I | awk '{print $1}'):$VW_PORT${NC}"
    echo -e "${YELLOW}Admin Panel: http://$(hostname -I | awk '{print $1}'):$VW_PORT/admin${NC}"
    echo -e "\n${CYAN}NOTICE: HTTPS is required for Vaultwarden to function correctly.${NC}"
    echo -e "${CYAN}Please configure an Nginx Reverse Proxy with an SSL certificate.${NC}"
else
    echo -e "${RED}FAILURE: Service failed to start.${NC}"
    echo -e "Check logs with: journalctl --user -u vaultwarden.service"
fi
echo -e "${GREEN}===================================================${NC}"

if [ -z "$LINGER_STATUS" ]; then
    echo -e "${YELLOW}WARNING: User Linger is NOT enabled.${NC}"
    echo -e "To keep the container running after logout, run:"
    echo -e "  ${CYAN}sudo loginctl enable-linger $CURRENT_USER${NC}"
    echo -e "${GREEN}===================================================${NC}"
fi
