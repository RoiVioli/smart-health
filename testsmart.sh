#!/bin/bash

################################################################################
# System health check script
# Displays: RAM, CPU, and disk status (green=OK, red=errors)
################################################################################

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║          SYSTEM HEALTH STATUS                              ║${NC}"
echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ============================================================================
# 1. RAM DISPLAY
# ============================================================================
echo -e "${BLUE}${BOLD}[RAM]${NC}"
RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')
RAM_USED=$(free -h | awk '/^Mem:/ {print $3}')
RAM_FREE=$(free -h | awk '/^Mem:/ {print $4}')
echo -e "  Total: ${BOLD}${RAM_TOTAL}${NC}"
echo -e "  Used: ${RAM_USED}"
echo -e "  Available: ${RAM_FREE}"
echo ""

# ============================================================================
# 2. CPU DISPLAY
# ============================================================================
echo -e "${BLUE}${BOLD}[CPU]${NC}"
CPU_MODEL=$(lscpu | grep "Model name:" | sed 's/Model name:[[:space:]]*//')
CPU_CORES=$(nproc)
CPU_ARCH=$(lscpu | grep "Architecture:" | awk '{print $2}')
echo -e "  Model: ${BOLD}${CPU_MODEL}${NC}"
echo -e "  Cores: ${CPU_CORES}"
echo -e "  Architecture: ${CPU_ARCH}"
echo ""

# ============================================================================
# 3. DISK CHECK
# ============================================================================
echo -e "${BLUE}${BOLD}[DISKS]${NC}"

# Get list of disks (excluding partitions and loops)
DISKS=$(lsblk -dn -o NAME,TYPE | grep disk | awk '{print $1}')

if [ -z "$DISKS" ]; then
    echo -e "  ${RED}No disk detected${NC}"
    exit 1
fi

# Check if smartctl is available
if ! command -v smartctl &> /dev/null; then
    echo -e "  ${YELLOW}smartctl not installed - cannot check health${NC}"
    echo -e "  ${YELLOW}  Install with: apt install smartmontools${NC}"
    exit 1
fi

DISK_NUMBER=1

for DISK in $DISKS; do
    DISK_PATH="/dev/$DISK"
    
    echo -e "\n${BOLD}Disk #${DISK_NUMBER}:${NC}"
    echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Get model, size and serial number
    DISK_MODEL=$(smartctl -i $DISK_PATH 2>/dev/null | grep "Device Model:" | sed 's/Device Model:[[:space:]]*//')
    if [ -z "$DISK_MODEL" ]; then
        DISK_MODEL=$(lsblk -dn -o MODEL $DISK_PATH 2>/dev/null | xargs)
    fi
    
    DISK_SIZE=$(lsblk -dn -o SIZE $DISK_PATH 2>/dev/null)
    DISK_SERIAL=$(smartctl -i $DISK_PATH 2>/dev/null | grep "Serial Number:" | sed 's/Serial Number:[[:space:]]*//')
    
    echo -e "  ${BOLD}Device:${NC}        $DISK_PATH"
    echo -e "  ${BOLD}Model:${NC}         $DISK_MODEL"
    echo -e "  ${BOLD}Size:${NC}          $DISK_SIZE"
    echo -e "  ${BOLD}Serial Number:${NC} ${DISK_SERIAL:-N/A}"
    
    # Check if SMART is supported
    SMART_SUPPORT=$(smartctl -i $DISK_PATH 2>/dev/null | grep -i "SMART support is:" | tail -1)
    
    if echo "$SMART_SUPPORT" | grep -q "Enabled"; then
        # Check disk health
        HEALTH=$(smartctl -H $DISK_PATH 2>/dev/null | grep -i "overall-health" | awk '{print $NF}')
        
        # Count errors in error log
        ERROR_LOG_COUNT=$(smartctl -l error $DISK_PATH 2>/dev/null | grep "^Error" | wc -l)
        
        # Check reallocated sectors (ID 5)
        REALLOCATED=$(smartctl -A $DISK_PATH 2>/dev/null | grep "Reallocated_Sector" | awk '{print $10}')
        [ -z "$REALLOCATED" ] && REALLOCATED=0
        
        # Check pending sectors (ID 197)
        PENDING=$(smartctl -A $DISK_PATH 2>/dev/null | grep "Current_Pending_Sector" | awk '{print $10}')
        [ -z "$PENDING" ] && PENDING=0
        
        # Check uncorrectable sectors (ID 198)
        UNCORRECTABLE=$(smartctl -A $DISK_PATH 2>/dev/null | grep "Offline_Uncorrectable" | awk '{print $10}')
        [ -z "$UNCORRECTABLE" ] && UNCORRECTABLE=0
        
        # Check reported uncorrectable errors (ID 187)
        REPORTED_UNCORRECT=$(smartctl -A $DISK_PATH 2>/dev/null | grep "Reported_Uncorrect" | awk '{print $10}')
        [ -z "$REPORTED_UNCORRECT" ] && REPORTED_UNCORRECT=0
        
        # Calculate total errors
        TOTAL_ERRORS=$((REALLOCATED + PENDING + UNCORRECTABLE + REPORTED_UNCORRECT + ERROR_LOG_COUNT))
        
        # Determine if disk has errors
        HAS_ERRORS=false
        
        if [ "$HEALTH" != "PASSED" ] && [ -n "$HEALTH" ]; then
            HAS_ERRORS=true
        fi
        
        if [ "$TOTAL_ERRORS" -gt 0 ]; then
            HAS_ERRORS=true
        fi
        
        # Display with color
        if [ "$HAS_ERRORS" = true ]; then
            echo -e "  ${RED}${BOLD}Status:${NC}        ${RED}ERRORS DETECTED${NC}"
            echo -e "  ${RED}${BOLD}Error count:${NC}   ${RED}$TOTAL_ERRORS${NC}"
            echo ""
            echo -e "  ${RED}Details:${NC}"
            [ "$REALLOCATED" -gt 0 ] && echo -e "    - Reallocated sectors: ${RED}$REALLOCATED${NC}"
            [ "$PENDING" -gt 0 ] && echo -e "    - Pending sectors: ${RED}$PENDING${NC}"
            [ "$UNCORRECTABLE" -gt 0 ] && echo -e "    - Uncorrectable sectors: ${RED}$UNCORRECTABLE${NC}"
            [ "$REPORTED_UNCORRECT" -gt 0 ] && echo -e "    - Reported errors: ${RED}$REPORTED_UNCORRECT${NC}"
            [ "$ERROR_LOG_COUNT" -gt 0 ] && echo -e "    - Log errors: ${RED}$ERROR_LOG_COUNT${NC}"
            [ "$HEALTH" != "PASSED" ] && [ -n "$HEALTH" ] && echo -e "    - SMART status: ${RED}$HEALTH${NC}"
        else
            echo -e "  ${GREEN}${BOLD}Status:${NC}        ${GREEN}GOOD${NC}"
            echo -e "  ${GREEN}${BOLD}Error count:${NC}   ${GREEN}0${NC}"
        fi
    else
        echo -e "  ${YELLOW}${BOLD}Status:${NC}        ${YELLOW}SMART not available${NC}"
        echo -e "  ${YELLOW}${BOLD}Error count:${NC}   ${YELLOW}N/A${NC}"
    fi
    
    DISK_NUMBER=$((DISK_NUMBER + 1))
done

echo ""

echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
