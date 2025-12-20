#!/bin/bash

set -o pipefail

# ========================================================
# Configuration
# ========================================================
OLD_DB="old_db_name"
NEW_DB="new_db_name"
NEW_USER="new_user_name"
NEW_PASS="YourSecurePassword" # Change this password

BACKUP_FILE="${OLD_DB}_$(date +%F_%H%M%S).sql.zst"

# UI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ========================================================
# Error Handling Function
# ========================================================
check_status() {
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR] $1 failed. Exiting...${NC}"
        exit 1
    else
        echo -e "${GREEN}[SUCCESS] $1 completed.${NC}"
    fi
}

# ========================================================
# Pre-flight Checks
# ========================================================

# Check for zstd
command -v zstd >/dev/null 2>&1 || { 
    echo -e "${RED}[ERROR] 'zstd' is not installed. Exiting...${NC}"; 
    exit 1; 
}

# Check for MariaDB root unix_socket access
mariadb -u root -e "SELECT 1;" >/dev/null 2>&1 || {
    echo -e "${RED}[ERROR] MariaDB root access failed.${NC}"
    echo -e "${YELLOW}Please run this script as root/sudo or ensure unix_socket is configured.${NC}"
    exit 1
}

echo -e "${BLUE}Starting migration: $OLD_DB -> $NEW_DB${NC}"

# 1. Export and compress
echo -e "${YELLOW}Dumping and compressing source database...${NC}"
mariadb-dump --single-transaction --routines --triggers --events --hex-blob "$OLD_DB" | zstd -T0 -o "$BACKUP_FILE"
check_status "Database export"

# 2. Create new database
echo -e "${YELLOW}Creating new database instance...${NC}"
mariadb -e "CREATE DATABASE IF NOT EXISTS \`$NEW_DB\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
check_status "Database creation"

# 3. User management and privileges
echo -e "${YELLOW}Configuring user and permissions...${NC}"
mariadb -e "CREATE USER IF NOT EXISTS '$NEW_USER'@'localhost' IDENTIFIED BY '$NEW_PASS';"
mariadb -e "ALTER USER '$NEW_USER'@'localhost' IDENTIFIED BY '$NEW_PASS';"
mariadb -e "GRANT ALL PRIVILEGES ON \`$NEW_DB\`.* TO '$NEW_USER'@'localhost';"
mariadb -e "FLUSH PRIVILEGES;"
check_status "User and privilege configuration"

# 4. Streamed import
echo -e "${YELLOW}Importing data via zstd stream...${NC}"
zstdcat "$BACKUP_FILE" | mariadb "$NEW_DB"
check_status "Data import"

# 5. Data integrity verification
echo -e "${YELLOW}Verifying data integrity (Tables & Rows)...${NC}"

# 5.1 Detect WordPress table prefix automatically
# Logic: Find the table name ending with '_posts' in the source database
CORE_TABLE=$(mariadb -N -s -e "SELECT table_name FROM information_schema.tables WHERE table_schema = '$NEW_DB' AND table_name LIKE '%options' LIMIT 1;")

if [ -z "$CORE_TABLE" ]; then
    echo -e "${YELLOW}[WARN] Could not detect WordPress prefix. Falling back to 'wp_posts'.${NC}"
    CORE_TABLE="wp_posts"
else
    echo -e "${GREEN}[INFO] Detected core table: $CORE_TABLE${NC}"
fi

# 5.2 Get table counts
OLD_COUNT=$(mariadb -N -s -e "SELECT count(*) FROM information_schema.tables WHERE table_schema = '$OLD_DB';")
NEW_COUNT=$(mariadb -N -s -e "SELECT count(*) FROM information_schema.tables WHERE table_schema = '$NEW_DB';")

# 5.3 Get row counts for core WordPress table
OLD_ROWS=$(mariadb -N -s -e "SELECT count(*) FROM $OLD_DB.$CORE_TABLE;" 2>/dev/null || echo "0")
NEW_ROWS=$(mariadb -N -s -e "SELECT count(*) FROM $NEW_DB.$CORE_TABLE;" 2>/dev/null || echo "0")

if [ "$OLD_COUNT" -eq "$NEW_COUNT" ] && [ "$OLD_ROWS" -eq "$NEW_ROWS" ] && [ "$OLD_COUNT" -ne 0 ]; then
    echo -e "${GREEN}Verification passed!${NC}"
    echo -e "Tables: ${BLUE}$NEW_COUNT${NC}, Rows ($CORE_TABLE): ${BLUE}$NEW_ROWS${NC}"
    
    # 6. Optional: Drop old database
    # echo -e "${YELLOW}Dropping source database...${NC}"
    # mariadb -e "DROP DATABASE $OLD_DB;"
    # check_status "Source database removal"
    
    echo -e "${BLUE}====================================================${NC}"
    echo -e "${GREEN}Migration successfully finished!${NC}"
    echo -e "New Database: ${BLUE}$NEW_DB${NC}"
    echo -e "New User:     ${BLUE}$NEW_USER${NC}"
    echo -e "Backup:       ${BLUE}$BACKUP_FILE${NC}"
    echo -e "${YELLOW}Action Required: Update your wp-config.php settings.${NC}"
    echo -e "${BLUE}====================================================${NC}"
else
    echo -e "${RED}[CRITICAL] Data mismatch!${NC}"
    echo -e "Old: $OLD_COUNT tables, $OLD_ROWS rows | New: $NEW_COUNT tables, $NEW_ROWS rows"
    exit 1
fi
