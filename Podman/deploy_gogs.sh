#!/bin/bash

# --- Configuration ---
GOGS_PORT=25131
CURRENT_USER=$(whoami)
QUADLET_DIR="$HOME/.config/containers/systemd"
GOGS_IMAGE="ghcr.io/gogs/gogs:latest"
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

# 3. Pull Container Image
echo -e "${CYAN}Step 1: Pulling latest Gogs image...${NC}"
podman pull "$GOGS_IMAGE"

# 4. Named Volume Management
if ! podman volume exists gogs; then
    echo -e "${CYAN}Step 2: Creating persistent volume 'gogs'...${NC}"
    podman volume create gogs
else
    echo -e "${GREEN}Info: Volume 'gogs' already exists.${NC}"
fi

# 5. Generate Quadlet File
echo -e "${CYAN}Step 3: Generating Quadlet configuration...${NC}"
mkdir -p "$QUADLET_DIR"

cat <<EOF > "$QUADLET_DIR/gogs.container"
[Unit]
Description=Gogs Git Service (Quadlet)
After=network-online.target

[Container]
Image=$GOGS_IMAGE
Volume=gogs:/data:Z
PublishPort=$GOGS_PORT:3000
Annotation=io.containers.autoupdate=registry

[Service]
Restart=always
MemoryMax=256M

[Install]
WantedBy=default.target
EOF

# 6. Systemd Reload & Service Restart
echo -e "${CYAN}Step 4: Reloading systemd and restarting service...${NC}"
systemctl --user daemon-reload

# Progress Spinner for the long-running restart
systemctl --user restart gogs.service &
pid=$! 
spin='-\|/'
echo -n "Waiting for service to stabilize... "
while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\rWaiting for service to stabilize... ${spin:$i:1}"
    sleep 0.1
done
printf "\r${GREEN}Service stabilized!                     ${NC}\n"

# 7. Check Linger Status
LINGER_STATUS=$(ls /var/lib/systemd/linger/"$CURRENT_USER" 2>/dev/null)

# 8. Deployment Summary
echo -e "\n${GREEN}===================================================${NC}"
if systemctl --user is-active --quiet gogs.service; then
    echo -e "${GREEN}SUCCESS: Gogs deployment is complete!${NC}"
    echo -e "${YELLOW}URL: http://$(hostname -I | awk '{print $1}'):$GOGS_PORT${NC}"
else
    echo -e "${RED}FAILURE: Service failed to start.${NC}"
    echo -e "Check logs with: journalctl --user -u gogs.service"
fi
echo -e "${GREEN}===================================================${NC}"

if [ -z "$LINGER_STATUS" ]; then
    echo -e "${YELLOW}WARNING: User Linger is NOT enabled.${NC}"
    echo -e "To keep the container running after logout, run:"
    echo -e "  ${CYAN}sudo loginctl enable-linger $CURRENT_USER${NC}"
    echo -e "${GREEN}===================================================${NC}"
fi
