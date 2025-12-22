#!/bin/bash

# --- Configuration ---
GOGS_PORT=25131
GOGS_MEM_LIMIT="512M"
CURRENT_USER=$(whoami)
QUADLET_DIR="$HOME/.config/containers/systemd"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
GOGS_IMAGE="ghcr.io/gogs/gogs:latest"
QUADLET_MIN_VERSION="4.4.0"

# ANSI Color Codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# 1. Privilege Check
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Run as non-root user.${NC}"
    exit 1
fi

# 2. Deployment Mode Selection
PODMAN_VERSION=$(podman version --format '{{.Client.Version}}')
if [ "$(printf '%s\n%s' "$QUADLET_MIN_VERSION" "$PODMAN_VERSION" | sort -V | head -n1)" == "$QUADLET_MIN_VERSION" ]; then
    DEPLOY_MODE="QUADLET"
    echo -e "${GREEN}Mode: Quadlet (Podman $PODMAN_VERSION)${NC}"
else
    DEPLOY_MODE="LEGACY"
    echo -e "${YELLOW}Mode: Legacy Service (Podman $PODMAN_VERSION)${NC}"
fi

# 3. Pull Image
echo -e "${CYAN}Step 1: Pulling image...${NC}"
podman pull "$GOGS_IMAGE"

# 4. Volume Management
if ! podman volume exists gogs; then
    echo -e "${CYAN}Step 2: Creating volume 'gogs'...${NC}"
    podman volume create gogs
else
    echo -e "${GREEN}Info: Volume 'gogs' exists.${NC}"
fi

# 5. File Generation
echo -e "${CYAN}Step 3: Generating config files...${NC}"

if [ "$DEPLOY_MODE" == "QUADLET" ]; then
    echo -e "Creating Quadlet file: $QUADLET_DIR/gogs.container"
    mkdir -p "$QUADLET_DIR"
    cat <<EOF > "$QUADLET_DIR/gogs.container"
[Unit]
Description=Gogs Git Service (Quadlet)

[Container]
ContainerName=gogs
Image=$GOGS_IMAGE
Volume=gogs:/data:Z
PublishPort=$GOGS_PORT:3000
Annotation=io.containers.autoupdate=registry

[Service]
Restart=always
MemoryMax=$GOGS_MEM_LIMIT

[Install]
WantedBy=default.target
EOF
else
    echo -e "Creating Service file: $SYSTEMD_USER_DIR/gogs.service"
    mkdir -p "$SYSTEMD_USER_DIR"
    podman rm -f gogs &>/dev/null || true

    cat <<EOF > "$SYSTEMD_USER_DIR/gogs.service"
[Unit]
Description=Gogs Git Service (Legacy)

[Service]
Restart=always
ExecStartPre=-/usr/bin/podman stop gogs
ExecStartPre=-/usr/bin/podman rm -f gogs
ExecStart=/usr/bin/podman run --name gogs \\
    -v gogs:/data:Z \\
    -p $GOGS_PORT:3000 \\
    --label "io.containers.autoupdate=registry" \\
    --memory=$GOGS_MEM_LIMIT \\
    $GOGS_IMAGE
ExecStop=/usr/bin/podman stop gogs
ExecStopPost=/usr/bin/podman rm -f gogs
Type=simple

[Install]
WantedBy=default.target
EOF
fi

# 6. Systemd Reload & Start
echo -e "${CYAN}Step 4: Reloading systemd and starting service...${NC}"

# Pre-check: Ensure daemon-reload is successful before proceeding
if ! systemctl --user daemon-reload; then
    echo -e "${RED}Error: systemctl daemon-reload failed.${NC}"
    exit 1
fi

if [ "$DEPLOY_MODE" == "LEGACY" ]; then
    systemctl --user enable gogs.service
fi

systemctl --user restart gogs.service &
pid=$! 
spin='-\|/'
echo -n "Starting Gogs... "
while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\rStarting Gogs... ${spin:$i:1}"
    sleep 0.1
done
printf "\r${GREEN}Service command executed!${NC}\n"

# 7. Deployment Summary
echo -e "\n${GREEN}===================================================${NC}"
if systemctl --user is-active --quiet gogs.service; then
    echo -e "${GREEN}SUCCESS: Gogs is running!${NC}"
    echo -e "${YELLOW}URL: http://$(hostname -I | awk '{print $1}'):$GOGS_PORT${NC}"
else
    echo -e "${RED}FAILURE: Service failed to start.${NC}"
    journalctl --user -u gogs.service --no-pager -n 20
fi
echo -e "${GREEN}===================================================${NC}"

# Linger Check
if [ ! -f /var/lib/systemd/linger/"$CURRENT_USER" ]; then
    echo -e "${YELLOW}Notice: Run 'sudo loginctl enable-linger $CURRENT_USER' to keep service alive after logout.${NC}"
fi
