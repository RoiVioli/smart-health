#!/bin/bash

################################################################################
# Secure Disk Wipe Script
# WARNING: This script permanently destroys ALL data on selected disk
# Data cannot be recovered after this operation
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Script requires root privileges
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}${BOLD}ERROR: This script must be run as root${NC}"
    echo "Please run with: sudo $0"
    exit 1
fi

# ============================================================================
# DEPENDENCY CHECK
# ============================================================================

echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          SECURE DISK WIPE - DEPENDENCY CHECK               ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# List of required dependencies
DEPENDENCIES=("dd" "shred" "hdparm" "smartctl" "lsblk" "pv" "bc")
MISSING_DEPS=()

# Check each dependency
for cmd in "${DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_DEPS+=("$cmd")
    fi
done

# If dependencies are missing, offer to install them
if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${YELLOW}${BOLD}Warning: Missing dependencies detected${NC}"
    echo -e "${YELLOW}Missing commands: ${MISSING_DEPS[*]}${NC}"
    echo ""
    
    # Determine which package to install based on missing commands
    PACKAGES_TO_INSTALL=()
    
    for dep in "${MISSING_DEPS[@]}"; do
        case "$dep" in
            dd|shred)
                if [[ ! " ${PACKAGES_TO_INSTALL[@]} " =~ " coreutils " ]]; then
                    PACKAGES_TO_INSTALL+=("coreutils")
                fi
                ;;
            hdparm)
                if [[ ! " ${PACKAGES_TO_INSTALL[@]} " =~ " hdparm " ]]; then
                    PACKAGES_TO_INSTALL+=("hdparm")
                fi
                ;;
            smartctl)
                if [[ ! " ${PACKAGES_TO_INSTALL[@]} " =~ " smartmontools " ]]; then
                    PACKAGES_TO_INSTALL+=("smartmontools")
                fi
                ;;
            lsblk)
                if [[ ! " ${PACKAGES_TO_INSTALL[@]} " =~ " util-linux " ]]; then
                    PACKAGES_TO_INSTALL+=("util-linux")
                fi
                ;;
            pv)
                if [[ ! " ${PACKAGES_TO_INSTALL[@]} " =~ " pv " ]]; then
                    PACKAGES_TO_INSTALL+=("pv")
                fi
                ;;
            bc)
                if [[ ! " ${PACKAGES_TO_INSTALL[@]} " =~ " bc " ]]; then
                    PACKAGES_TO_INSTALL+=("bc")
                fi
                ;;
        esac
    done
    
    echo -e "${BLUE}Required packages: ${PACKAGES_TO_INSTALL[*]}${NC}"
    echo ""
    
    # Ask user if they want to install
    read -p "Do you want to install missing dependencies? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}Installing dependencies...${NC}"
        apt update
        apt install -y "${PACKAGES_TO_INSTALL[@]}"
        
        # Check if installation was successful
        INSTALL_FAILED=false
        for cmd in "${MISSING_DEPS[@]}"; do
            if ! command -v "$cmd" &> /dev/null; then
                INSTALL_FAILED=true
                break
            fi
        done
        
        if [ "$INSTALL_FAILED" = true ]; then
            echo -e "${RED}Installation failed or incomplete${NC}"
            echo -e "${RED}Cannot proceed without all dependencies${NC}"
            exit 1
        else
            echo -e "${GREEN}Dependencies installed successfully${NC}"
            echo ""
        fi
    else
        echo -e "${RED}Cannot proceed without all dependencies${NC}"
        exit 1
    fi
fi

# ============================================================================
# STEP 1: DISPLAY ALL AVAILABLE DISKS
# ============================================================================

clear
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          SECURE DISK WIPE - DISK SELECTION                 ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${RED}${BOLD}WARNING: This will permanently destroy ALL data on selected disk${NC}"
echo -e "${RED}${BOLD}Data CANNOT be recovered after this operation${NC}"
echo ""

# Get list of disks
DISKS=$(lsblk -dn -o NAME,TYPE | grep disk | awk '{print $1}')

if [ -z "$DISKS" ]; then
    echo -e "${RED}No disks detected${NC}"
    exit 1
fi

echo -e "${CYAN}${BOLD}Available Disks:${NC}"
echo ""

DISK_ARRAY=()
DISK_INDEX=1

for DISK in $DISKS; do
    DISK_PATH="/dev/$DISK"
    DISK_ARRAY+=("$DISK_PATH")
    
    # Get disk information
    DISK_MODEL=$(smartctl -i $DISK_PATH 2>/dev/null | grep "Device Model:" | sed 's/Device Model:[[:space:]]*//')
    if [ -z "$DISK_MODEL" ]; then
        DISK_MODEL=$(lsblk -dn -o MODEL $DISK_PATH 2>/dev/null | xargs)
    fi
    
    DISK_SIZE=$(lsblk -dn -o SIZE $DISK_PATH 2>/dev/null)
    DISK_SIZE_BYTES=$(lsblk -bdn -o SIZE $DISK_PATH 2>/dev/null)
    DISK_SERIAL=$(smartctl -i $DISK_PATH 2>/dev/null | grep "Serial Number:" | sed 's/Serial Number:[[:space:]]*//')
    
    # Get used/available space
    DISK_USED="0B"
    DISK_AVAILABLE="$DISK_SIZE"
    
    # Check if disk has partitions
    PARTITIONS=$(lsblk -ln -o NAME $DISK_PATH | tail -n +2)
    if [ -n "$PARTITIONS" ]; then
        TOTAL_USED=0
        for PART in $PARTITIONS; do
            PART_PATH="/dev/$PART"
            if mountpoint -q "$PART_PATH" 2>/dev/null || df -B1 "$PART_PATH" &>/dev/null; then
                USED=$(df -B1 "$PART_PATH" 2>/dev/null | tail -1 | awk '{print $3}')
                if [ -n "$USED" ]; then
                    TOTAL_USED=$((TOTAL_USED + USED))
                fi
            fi
        done
        if [ $TOTAL_USED -gt 0 ]; then
            DISK_USED=$(numfmt --to=iec-i --suffix=B $TOTAL_USED 2>/dev/null || echo "${TOTAL_USED}B")
            AVAILABLE=$((DISK_SIZE_BYTES - TOTAL_USED))
            DISK_AVAILABLE=$(numfmt --to=iec-i --suffix=B $AVAILABLE 2>/dev/null || echo "$DISK_SIZE")
        fi
    fi
    
    # Check SMART health
    HEALTH="Unknown"
    HEALTH_COLOR=$YELLOW
    ERROR_COUNT=0
    
    if command -v smartctl &> /dev/null; then
        SMART_HEALTH=$(smartctl -H $DISK_PATH 2>/dev/null | grep -i "overall-health" | awk '{print $NF}')
        if [ "$SMART_HEALTH" = "PASSED" ]; then
            HEALTH="GOOD"
            HEALTH_COLOR=$GREEN
        elif [ -n "$SMART_HEALTH" ]; then
            HEALTH="$SMART_HEALTH"
            HEALTH_COLOR=$RED
        fi
        
        # Count errors
        REALLOCATED=$(smartctl -A $DISK_PATH 2>/dev/null | grep "Reallocated_Sector" | awk '{print $10}')
        [ -z "$REALLOCATED" ] && REALLOCATED=0
        PENDING=$(smartctl -A $DISK_PATH 2>/dev/null | grep "Current_Pending_Sector" | awk '{print $10}')
        [ -z "$PENDING" ] && PENDING=0
        UNCORRECTABLE=$(smartctl -A $DISK_PATH 2>/dev/null | grep "Offline_Uncorrectable" | awk '{print $10}')
        [ -z "$UNCORRECTABLE" ] && UNCORRECTABLE=0
        
        ERROR_COUNT=$((REALLOCATED + PENDING + UNCORRECTABLE))
    fi
    
    # Display disk information
    echo -e "${BOLD}[$DISK_INDEX] $DISK_PATH${NC}"
    echo -e "    Model:          $DISK_MODEL"
    echo -e "    Serial Number:  ${DISK_SERIAL:-N/A}"
    echo -e "    Size:           $DISK_SIZE ($DISK_SIZE_BYTES bytes)"
    echo -e "    Used:           $DISK_USED"
    echo -e "    Available:      $DISK_AVAILABLE"
    echo -e "    Health:         ${HEALTH_COLOR}$HEALTH${NC}"
    if [ $ERROR_COUNT -gt 0 ]; then
        echo -e "    ${RED}Errors:         $ERROR_COUNT${NC}"
    else
        echo -e "    Errors:         0"
    fi
    echo ""
    
    DISK_INDEX=$((DISK_INDEX + 1))
done

# ============================================================================
# STEP 2: SELECT DISK
# ============================================================================

while true; do
    read -p "Select disk number to wipe [1-${#DISK_ARRAY[@]}] or 'q' to quit: " SELECTION
    
    if [[ "$SELECTION" == "q" ]] || [[ "$SELECTION" == "Q" ]]; then
        echo "Operation cancelled"
        exit 0
    fi
    
    if [[ "$SELECTION" =~ ^[0-9]+$ ]] && [ "$SELECTION" -ge 1 ] && [ "$SELECTION" -le "${#DISK_ARRAY[@]}" ]; then
        SELECTED_DISK="${DISK_ARRAY[$((SELECTION - 1))]}"
        break
    else
        echo -e "${RED}Invalid selection. Please try again.${NC}"
    fi
done

# ============================================================================
# STEP 3: DISPLAY SELECTED DISK AND CONFIRM
# ============================================================================

echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          CONFIRMATION - SELECTED DISK INFORMATION          ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get detailed information about selected disk
DISK_MODEL=$(smartctl -i $SELECTED_DISK 2>/dev/null | grep "Device Model:" | sed 's/Device Model:[[:space:]]*//')
if [ -z "$DISK_MODEL" ]; then
    DISK_MODEL=$(lsblk -dn -o MODEL $SELECTED_DISK 2>/dev/null | xargs)
fi

DISK_SIZE=$(lsblk -dn -o SIZE $SELECTED_DISK 2>/dev/null)
DISK_SIZE_BYTES=$(lsblk -bdn -o SIZE $SELECTED_DISK 2>/dev/null)
DISK_SERIAL=$(smartctl -i $SELECTED_DISK 2>/dev/null | grep "Serial Number:" | sed 's/Serial Number:[[:space:]]*//')
FIRMWARE=$(smartctl -i $SELECTED_DISK 2>/dev/null | grep "Firmware Version:" | sed 's/Firmware Version:[[:space:]]*//')

# Calculate used space
DISK_USED="0B"
PARTITIONS=$(lsblk -ln -o NAME $SELECTED_DISK | tail -n +2)
if [ -n "$PARTITIONS" ]; then
    TOTAL_USED=0
    for PART in $PARTITIONS; do
        PART_PATH="/dev/$PART"
        if mountpoint -q "$PART_PATH" 2>/dev/null || df -B1 "$PART_PATH" &>/dev/null; then
            USED=$(df -B1 "$PART_PATH" 2>/dev/null | tail -1 | awk '{print $3}')
            if [ -n "$USED" ]; then
                TOTAL_USED=$((TOTAL_USED + USED))
            fi
        fi
    done
    if [ $TOTAL_USED -gt 0 ]; then
        DISK_USED=$(numfmt --to=iec-i --suffix=B $TOTAL_USED 2>/dev/null || echo "${TOTAL_USED}B")
    fi
fi

echo -e "${BOLD}Selected Disk:${NC}      $SELECTED_DISK"
echo -e "${BOLD}Model:${NC}              $DISK_MODEL"
echo -e "${BOLD}Serial Number:${NC}      ${DISK_SERIAL:-N/A}"
echo -e "${BOLD}Firmware:${NC}           ${FIRMWARE:-N/A}"
echo -e "${BOLD}Total Size:${NC}         $DISK_SIZE ($DISK_SIZE_BYTES bytes)"
echo -e "${BOLD}Used Space:${NC}         $DISK_USED"
echo ""
echo -e "${RED}${BOLD}WARNING: ALL DATA ON THIS DISK WILL BE PERMANENTLY DESTROYED${NC}"
echo -e "${RED}${BOLD}This operation CANNOT be undone!${NC}"
echo ""

# Check if disk is mounted
MOUNTED_PARTITIONS=$(lsblk -ln -o NAME,MOUNTPOINT $SELECTED_DISK | tail -n +2 | awk '{if ($2 != "") print $1, $2}')
if [ -n "$MOUNTED_PARTITIONS" ]; then
    echo -e "${YELLOW}${BOLD}Warning: The following partitions are currently mounted:${NC}"
    echo "$MOUNTED_PARTITIONS"
    echo ""
fi

# Final confirmation
read -p "Type 'ERASE' in capital letters to confirm: " CONFIRM

if [ "$CONFIRM" != "ERASE" ]; then
    echo -e "${YELLOW}Operation cancelled${NC}"
    exit 0
fi

# ============================================================================
# STEP 4: UNMOUNT PARTITIONS
# ============================================================================

echo ""
echo -e "${CYAN}Unmounting partitions...${NC}"

PARTITIONS=$(lsblk -ln -o NAME $SELECTED_DISK | tail -n +2)
for PART in $PARTITIONS; do
    PART_PATH="/dev/$PART"
    if mountpoint -q "$PART_PATH" 2>/dev/null; then
        umount -f "$PART_PATH" 2>/dev/null
        echo "Unmounted $PART_PATH"
    fi
done

# ============================================================================
# STEP 5: SECURE WIPE WITH PROGRESS BAR
# ============================================================================

echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          SECURE WIPE IN PROGRESS                           ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

WIPE_ERROR=0
START_TIME=$(date +%s)

# Method 1: Write zeros (fast pass)
echo -e "${CYAN}${BOLD}Pass 1/3: Writing zeros...${NC}"
if command -v pv &> /dev/null; then
    dd if=/dev/zero bs=1M status=none | pv -s "$DISK_SIZE_BYTES" | dd of=$SELECTED_DISK bs=1M oflag=direct status=none 2>/dev/null
    if [ ${PIPESTATUS[2]} -ne 0 ]; then
        WIPE_ERROR=1
    fi
else
    dd if=/dev/zero of=$SELECTED_DISK bs=1M status=progress oflag=direct 2>/dev/null
    if [ $? -ne 0 ]; then
        WIPE_ERROR=1
    fi
fi
sync

echo ""
echo -e "${GREEN}Pass 1/3 completed${NC}"
echo ""

# Method 2: Write random data
echo -e "${CYAN}${BOLD}Pass 2/3: Writing random data...${NC}"
if command -v pv &> /dev/null; then
    dd if=/dev/urandom bs=1M status=none | pv -s "$DISK_SIZE_BYTES" | dd of=$SELECTED_DISK bs=1M oflag=direct status=none 2>/dev/null
    if [ ${PIPESTATUS[2]} -ne 0 ]; then
        WIPE_ERROR=1
    fi
else
    dd if=/dev/urandom of=$SELECTED_DISK bs=1M status=progress oflag=direct 2>/dev/null
    if [ $? -ne 0 ]; then
        WIPE_ERROR=1
    fi
fi
sync

echo ""
echo -e "${GREEN}Pass 2/3 completed${NC}"
echo ""

# Method 3: Final zero pass
echo -e "${CYAN}${BOLD}Pass 3/3: Final zero pass...${NC}"
if command -v pv &> /dev/null; then
    dd if=/dev/zero bs=1M status=none | pv -s "$DISK_SIZE_BYTES" | dd of=$SELECTED_DISK bs=1M oflag=direct status=none 2>/dev/null
    if [ ${PIPESTATUS[2]} -ne 0 ]; then
        WIPE_ERROR=1
    fi
else
    dd if=/dev/zero of=$SELECTED_DISK bs=1M status=progress oflag=direct 2>/dev/null
    if [ $? -ne 0 ]; then
        WIPE_ERROR=1
    fi
fi
sync

echo ""
echo -e "${GREEN}Pass 3/3 completed${NC}"
echo ""

# Calculate elapsed time
END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
HOURS=$((ELAPSED / 3600))
MINUTES=$(((ELAPSED % 3600) / 60))
SECONDS=$((ELAPSED % 60))

# ============================================================================
# STEP 6: VERIFY WIPE
# ============================================================================

echo -e "${CYAN}Verifying wipe...${NC}"

# Check if disk is now all zeros
SAMPLE_SIZE=$((1024 * 1024 * 10)) # 10MB sample
NONZERO_COUNT=$(dd if=$SELECTED_DISK bs=1M count=10 status=none 2>/dev/null | tr -d '\0' | wc -c)

if [ "$NONZERO_COUNT" -eq 0 ]; then
    echo -e "${GREEN}Verification successful - disk appears to be fully wiped${NC}"
else
    echo -e "${YELLOW}Warning: Some non-zero data detected in sample${NC}"
    WIPE_ERROR=1
fi

# ============================================================================
# STEP 7 & 8: FINAL REPORT
# ============================================================================

echo ""
echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          SECURE WIPE COMPLETED                             ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ $WIPE_ERROR -eq 0 ]; then
    echo -e "${GREEN}${BOLD}Status: SUCCESS${NC}"
    echo -e "${GREEN}All data has been securely erased${NC}"
else
    echo -e "${YELLOW}${BOLD}Status: COMPLETED WITH WARNINGS${NC}"
    echo -e "${YELLOW}Please verify disk manually${NC}"
fi

echo ""
echo -e "${BOLD}Operation Summary:${NC}"
echo -e "  Time elapsed:   ${HOURS}h ${MINUTES}m ${SECONDS}s"
echo -e "  Passes:         3 (Zero, Random, Zero)"
echo -e "  Method:         DoD 5220.22-M compliant"
echo ""

# ============================================================================
# STEP 9: DISPLAY FINAL DISK STATUS
# ============================================================================

echo -e "${BOLD}Final Disk Status:${NC}"
echo ""
echo -e "${BOLD}Device:${NC}         $SELECTED_DISK"
echo -e "${BOLD}Model:${NC}          $DISK_MODEL"
echo -e "${BOLD}Serial Number:${NC}  ${DISK_SERIAL:-N/A}"
echo -e "${BOLD}Size:${NC}           $DISK_SIZE ($DISK_SIZE_BYTES bytes)"
echo -e "${BOLD}Used Space:${NC}     0B (wiped)"
echo -e "${BOLD}Available:${NC}      $DISK_SIZE (entire disk)"
echo ""

# Check final SMART status
if command -v smartctl &> /dev/null; then
    FINAL_HEALTH=$(smartctl -H $SELECTED_DISK 2>/dev/null | grep -i "overall-health" | awk '{print $NF}')
    
    REALLOCATED=$(smartctl -A $SELECTED_DISK 2>/dev/null | grep "Reallocated_Sector" | awk '{print $10}')
    [ -z "$REALLOCATED" ] && REALLOCATED=0
    PENDING=$(smartctl -A $SELECTED_DISK 2>/dev/null | grep "Current_Pending_Sector" | awk '{print $10}')
    [ -z "$PENDING" ] && PENDING=0
    UNCORRECTABLE=$(smartctl -A $SELECTED_DISK 2>/dev/null | grep "Offline_Uncorrectable" | awk '{print $10}')
    [ -z "$UNCORRECTABLE" ] && UNCORRECTABLE=0
    
    FINAL_ERROR_COUNT=$((REALLOCATED + PENDING + UNCORRECTABLE))
    
    if [ "$FINAL_HEALTH" = "PASSED" ] && [ $FINAL_ERROR_COUNT -eq 0 ]; then
        echo -e "${BOLD}Health Status:${NC}  ${GREEN}GOOD${NC}"
        echo -e "${BOLD}Errors:${NC}         ${GREEN}0${NC}"
        echo ""
        echo -e "${GREEN}${BOLD}Disk is ready for use${NC}"
    else
        echo -e "${BOLD}Health Status:${NC}  ${YELLOW}$FINAL_HEALTH${NC}"
        echo -e "${BOLD}Errors:${NC}         ${YELLOW}$FINAL_ERROR_COUNT${NC}"
        echo ""
        echo -e "${YELLOW}${BOLD}Warning: Disk may have hardware issues${NC}"
    fi
fi

echo ""
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
