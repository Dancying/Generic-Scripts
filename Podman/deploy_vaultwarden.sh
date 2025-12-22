#!/bin/bash

# --- Configuration ---
VW_PORT=22929
VW_MEM_LIMIT="512M"
CURRENT_USER=$(whoami)
QUADLET_DIR="$HOME/.config/containers/systemd"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
VW_IMAGE="ghcr.io/dani-garcia/vaultwarden:latest"
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

# 3. Dependency Check (Argon2 for security)
if ! command -v argon2 &> /dev/null; then
    echo -e "${RED}Error: 'argon2' command not found. Install it first.${NC}"
    exit 1
fi

# 4. Pull Image
echo -e "${CYAN}Step 1: Pulling image...${NC}"
podman pull "$VW_IMAGE"

# 5. Volume Management
if ! podman volume exists vaultwarden; then
    echo -e "${CYAN}Step 2: Creating volume 'vaultwarden'...${NC}"
    podman volume create vaultwarden
else
    echo -e "${GREEN}Info: Volume 'vaultwarden' exists.${NC}"
fi

# 6. Admin Token Generation
echo -e "${CYAN}Step 3: Configuring Admin Token...${NC}"
read -rs -p "Enter Vaultwarden admin password: " ADMIN_PASS
echo
read -rs -p "Confirm admin password: " ADMIN_PASS_CONFIRM
echo

if [ "$ADMIN_PASS" != "$ADMIN_PASS_CONFIRM" ]; then
    echo -e "${RED}Error: Passwords do not match.${NC}"
    exit 1
fi

# Hash password and escape $ for systemd
RAW_HASH=$(echo -n "$ADMIN_PASS" | argon2 "$(openssl rand -base64 32)" -e -id -k 65540 -t 3 -p 4)
ESCAPED_HASH=$(echo "$RAW_HASH" | sed 's/\$/\$\$/g')

# 7. File Generation
echo -e "${CYAN}Step 4: Generating config files...${NC}"

if [ "$DEPLOY_MODE" == "QUADLET" ]; then
    echo -e "Creating Quadlet file: $QUADLET_DIR/vaultwarden.container"
    mkdir -p "$QUADLET_DIR"
    cat <<EOF > "$QUADLET_DIR/vaultwarden.container"
[Unit]
Description=Vaultwarden Service (Quadlet)

[Container]
ContainerName=vaultwarden
Image=$VW_IMAGE
Volume=vaultwarden:/data:Z
PublishPort=$VW_PORT:$VW_PORT
Environment=ROCKET_PORT=$VW_PORT
Environment=ADMIN_TOKEN=$ESCAPED_HASH
Annotation=io.containers.autoupdate=registry

[Service]
Restart=always
MemoryMax=$VW_MEM_LIMIT

[Install]
WantedBy=default.target
EOF
else
    echo -e "Creating Service file: $SYSTEMD_USER_DIR/vaultwarden.service"
    mkdir -p "$SYSTEMD_USER_DIR"
    podman rm -f vaultwarden &>/dev/null || true

    cat <<EOF > "$SYSTEMD_USER_DIR/vaultwarden.service"
[Unit]
Description=Vaultwarden Service (Legacy)

[Service]
Restart=always
ExecStartPre=-/usr/bin/podman stop vaultwarden
ExecStartPre=-/usr/bin/podman rm -f vaultwarden
ExecStart=/usr/bin/podman run --name vaultwarden \\
    -v vaultwarden:/data:Z \\
    -p $VW_PORT:$VW_PORT \\
    -e ROCKET_PORT=$VW_PORT \\
    -e ADMIN_TOKEN=$ESCAPED_HASH \\
    --label "io.containers.autoupdate=registry" \\
    --memory=$VW_MEM_LIMIT \\
    $VW_IMAGE
ExecStop=/usr/bin/podman stop vaultwarden
ExecStopPost=/usr/bin/podman rm -f vaultwarden
Type=simple

[Install]
WantedBy=default.target
EOF
fi

# 8. Systemd Reload & Start
echo -e "${CYAN}Step 5: Reloading systemd and starting service...${NC}"

if ! systemctl --user daemon-reload; then
    echo -e "${RED}Error: systemctl daemon-reload failed.${NC}"
    exit 1
fi

if [ "$DEPLOY_MODE" == "LEGACY" ]; then
    systemctl --user enable vaultwarden.service
fi

systemctl --user restart vaultwarden.service &
pid=$! 
spin='-\|/'
echo -n "Starting Vaultwarden... "
while kill -0 $pid 2>/dev/null; do
    i=$(( (i+1) % 4 ))
    printf "\rStarting Vaultwarden... ${spin:$i:1}"
    sleep 0.1
done
printf "\r${GREEN}Service command executed!${NC}\n"

# 9. Deployment Summary
echo -e "\n${GREEN}===================================================${NC}"
if systemctl --user is-active --quiet vaultwarden.service; then
    echo -e "${GREEN}SUCCESS: Vaultwarden is running!${NC}"
    echo -e "${YELLOW}URL: http://$(hostname -I | awk '{print $1}'):$VW_PORT${NC}"
    echo -e "${YELLOW}Admin: http://$(hostname -I | awk '{print $1}'):$VW_PORT/admin${NC}"
else
    echo -e "${RED}FAILURE: Service failed to start.${NC}"
    journalctl --user -u vaultwarden.service --no-pager -n 20
fi
echo -e "${GREEN}===================================================${NC}"

# Linger Check
if [ ! -f /var/lib/systemd/linger/"$CURRENT_USER" ]; then
    echo -e "${YELLOW}Notice: Run 'sudo loginctl enable-linger $CURRENT_USER' for persistence.${NC}"
fi
