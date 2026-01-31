# System Health and Disk Management Scripts

A collection of professional bash scripts for monitoring system health and securely wiping disks on Linux systems.

---

## Table of Contents

- [Overview](#overview)
- [Scripts](#scripts)
  - [smartcheck.sh](#smartchecksh)
  - [diskwipe.sh](#diskwipesh)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Security Considerations](#security-considerations)
- [License](#license)

---

## Overview

This repository contains two complementary scripts designed for system administrators and power users:

1. **smartcheck.sh** - A system health monitoring tool that provides detailed information about RAM, CPU, and disk status with SMART diagnostics.

2. **diskwipe.sh** - A secure disk wiping utility that permanently destroys all data on selected disks using DoD 5220.22-M compliant methods.

---

## Scripts

### smartcheck.sh

**Purpose:** Monitor and report system health status including RAM usage, CPU information, and disk health via SMART diagnostics.

**Key Features:**

- **Automatic Dependency Detection**
  - Checks for required tools: `smartctl`, `lsblk`, `free`, `lscpu`
  - Offers to install missing dependencies via package manager
  - Continues with reduced functionality if installation is declined

- **RAM Monitoring**
  - Displays total, used, and available memory
  - Human-readable format (GB/TB, not bytes)

- **CPU Information**
  - Processor model and specifications
  - Core count and architecture

- **Disk Health Analysis**
  - Enumerates all physical disks
  - Displays model, serial number, and size for each disk
  - SMART health status with color coding:
    - GREEN: Healthy disk (0 errors)
    - RED: Disk with errors detected
    - YELLOW: SMART not available
  - Detailed error reporting:
    - Reallocated sectors
    - Pending sectors
    - Uncorrectable sectors
    - Error log entries
  - Individual disk numbering for easy identification

**Output Format:**

```
[RAM]
  Total: 16Gi
  Used: 8.2Gi
  Available: 7.8Gi

[CPU]
  Model: Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz
  Cores: 8
  Architecture: x86_64

[DISKS]

Disk #1:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Device:        /dev/sda
  Model:         Samsung SSD 860 EVO 500GB
  Size:          465.8G
  Serial Number: S3Z9NB0K123456
  Status:        GOOD
  Error count:   0
```

---

### diskwipe.sh

**Purpose:** Securely and permanently erase all data from selected disk drives using military-grade wiping methods.

**WARNING:** This script irreversibly destroys all data. Use with extreme caution.

**Key Features:**

- **Root Privilege Enforcement**
  - Requires root/sudo access
  - Prevents accidental execution without proper permissions

- **Comprehensive Dependency Check**
  - Verifies availability of: `dd`, `shred`, `hdparm`, `smartctl`, `lsblk`, `pv`, `bc`
  - Interactive installation prompt for missing packages
  - Refuses to proceed without all required tools

- **Interactive Disk Selection**
  - Lists all available physical disks
  - Displays detailed information for each disk:
    - Model and serial number
    - Total size in bytes and human-readable format
    - Current space usage (used/available)
    - SMART health status
    - Error count
  - Numbered selection interface
  - Option to quit at any time

- **Multi-Level Confirmation**
  - Displays complete disk information before wiping
  - Shows mounted partitions if any
  - Requires typing 'ERASE' in capital letters to confirm
  - Prevents accidental data loss

- **Automatic Partition Management**
  - Detects and unmounts all partitions on selected disk
  - Ensures no filesystem is in use during wipe

- **DoD 5220.22-M Compliant Wiping**
  - **Pass 1:** Write zeros to entire disk
  - **Pass 2:** Write random data to entire disk
  - **Pass 3:** Final zero pass
  - Three-pass method ensures data is unrecoverable by any standard recovery tool

- **Progress Monitoring**
  - Real-time progress bars using `pv` (pipe viewer)
  - ETA (Estimated Time of Arrival) for each pass
  - Fallback to `dd status=progress` if `pv` unavailable
  - Total elapsed time calculation

- **Post-Wipe Verification**
  - Samples disk data to verify successful wipe
  - Checks for remaining non-zero data
  - Reports verification results

- **Comprehensive Final Report**
  - Operation status (SUCCESS/WARNING)
  - Total time elapsed
  - Wiping method used
  - Final disk status and health
  - SMART diagnostic results
  - Disk readiness confirmation

**Wiping Process:**

```
Pass 1/3: Writing zeros...
[===================>                    ] 45% ETA 0:15:30

Pass 2/3: Writing random data...
[===================================>    ] 82% ETA 0:05:20

Pass 3/3: Final zero pass...
[========================================] 100%
```

**Security Note:** The three-pass method (zero-random-zero) meets DoD 5220.22-M standards for secure data erasure and makes data recovery practically impossible with standard tools.

---

## Requirements

### System Requirements

- Linux-based operating system (Debian, Ubuntu, Proxmox, etc.)
- Bash shell (version 4.0 or higher recommended)
- Root/sudo access (for diskwipe.sh and dependency installation)

### Software Dependencies

**smartcheck.sh requires:**
- `smartmontools` - SMART monitoring tools
- `util-linux` - Disk utilities (lsblk)
- `procps` - System utilities (free, lscpu)

**diskwipe.sh requires:**
- `coreutils` - Core utilities (dd, shred)
- `hdparm` - Hard disk parameter utility
- `smartmontools` - SMART monitoring tools
- `util-linux` - Disk utilities (lsblk)
- `pv` - Pipe viewer for progress monitoring
- `bc` - Basic calculator for time calculations

**Note:** Both scripts automatically detect missing dependencies and offer to install them.

---

## Installation

### Quick Start

```bash
# Download scripts
git clone https://github.com/RoiVioli/smart-health.git
cd YOUR_REPO

# Make scripts executable
chmod +x smartcheck.sh diskwipe.sh

# Run system health check
./smartcheck.sh

# Run secure wipe (requires root)
sudo ./diskwipe.sh
```

### Manual Installation

```bash
# Install dependencies manually (Debian/Ubuntu)
sudo apt update
sudo apt install -y smartmontools util-linux procps coreutils hdparm pv bc

# Download scripts individually
wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/smartcheck.sh](https://github.com/RoiVioli/smart-health/blob/main/testsmart.sh
wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/diskwipe.sh](https://github.com/RoiVioli/smart-health/blob/main/diskwipe.sh

# Set execute permissions
chmod +x smartcheck.sh diskwipe.sh
```

### System-Wide Installation

```bash
# Copy to /usr/local/bin for system-wide access
sudo cp smartcheck.sh /usr/local/bin/smartcheck
sudo cp diskwipe.sh /usr/local/bin/diskwipe

# Use from anywhere
smartcheck
sudo diskwipe
```

---

## Usage

### smartcheck.sh

**Basic Usage:**

```bash
./smartcheck.sh
```

**With Dependency Auto-Install:**

```bash
# Script will prompt if dependencies are missing
./smartcheck.sh

# Output:
# Warning: Missing dependencies detected
# Missing commands: smartctl
# Required packages: smartmontools
# 
# Do you want to install missing dependencies? (y/n):
```

**Without Root (if dependencies already installed):**

```bash
# No root required for checking system health
./smartcheck.sh
```

**Automated Monitoring:**

```bash
# Run daily at 8 AM via cron
crontab -e

# Add this line:
0 8 * * * /path/to/smartcheck.sh > /var/log/smartcheck_$(date +\%Y\%m\%d).log 2>&1
```

---

### diskwipe.sh

**Basic Usage:**

```bash
sudo ./diskwipe.sh
```

**Complete Workflow:**

1. **Start Script (as root):**
   ```bash
   sudo ./diskwipe.sh
   ```

2. **Review Available Disks:**
   - Script displays all disks with details
   - Note the disk number you want to wipe

3. **Select Disk:**
   ```
   Select disk number to wipe [1-3] or 'q' to quit: 2
   ```

4. **Review Confirmation:**
   - Verify disk information is correct
   - Check serial number and model match expected disk

5. **Final Confirmation:**
   ```
   Type 'ERASE' in capital letters to confirm: ERASE
   ```

6. **Wait for Completion:**
   - Three passes will execute sequentially
   - Progress bars show real-time status
   - Do not interrupt the process

7. **Review Final Report:**
   - Check operation status
   - Verify disk health
   - Confirm disk is ready for reuse

**Important Notes:**

- Always double-check disk selection
- Ensure you have the correct serial number
- Process cannot be interrupted safely once started
- Keep system powered on during entire operation
- Large disks (multiple TB) may take many hours

---

## Security Considerations

### smartcheck.sh

**Privacy:**
- Script only reads disk information
- No data is modified or transmitted
- SMART data remains on local system
- Safe to run on production systems

**Permissions:**
- Can run without root if dependencies installed
- Root required only for dependency installation
- Read-only access to disk information

### diskwipe.sh

**Data Destruction:**
- ALL data on selected disk is permanently destroyed
- Recovery is impossible after completion
- No "undo" or recovery option exists
- Backups must be made before running

**Operational Security:**
- Requires root privileges
- Multi-level confirmation prevents accidents
- Displays serial numbers for verification
- Shows mounted partitions as warning

**Wiping Standards:**
- DoD 5220.22-M compliant (3-pass method)
- Suitable for:
  - Decommissioning disks
  - Preparing drives for sale/disposal
  - Repurposing storage
  - Security-required data destruction

**Not Suitable For:**
- Top secret/classified data (requires physical destruction)
- SSD wear leveling areas (some data may remain in over-provisioned space)
- Firmware areas (not accessible by this method)

**Best Practices:**
- Verify disk serial number before confirming
- Disconnect other disks if possible
- Run from live USB for system disk wiping
- Perform SMART test after wiping to verify disk health
- Keep system on stable power (UPS recommended)

---

## Troubleshooting

### smartcheck.sh Issues

**"smartctl command not available"**
```bash
# Install smartmontools
sudo apt install smartmontools
```

**"No disk detected"**
```bash
# Check if running in VM or container
lsblk

# Verify permissions
sudo ./smartcheck.sh
```

**SMART not supported**
- Some virtual disks don't support SMART
- USB enclosures may not pass through SMART data
- Script will display basic disk info only

### diskwipe.sh Issues

**"This script must be run as root"**
```bash
# Always use sudo
sudo ./diskwipe.sh
```

**"Cannot proceed without all dependencies"**
```bash
# Install all required packages
sudo apt install coreutils hdparm smartmontools util-linux pv bc
```

**Wipe completed with warnings**
- Check final SMART status
- Run smartcheck.sh to verify disk health
- May indicate hardware issues

**Process interrupted**
- Disk may be in inconsistent state
- Re-run diskwipe.sh completely
- Check for hardware errors

---

## Exit Codes

### smartcheck.sh
- `0` - Success, all checks completed
- `1` - Error (no disks detected, dependencies missing, etc.)

### diskwipe.sh
- `0` - Successful wipe, no errors
- `1` - Error (not root, missing dependencies, wipe failed, etc.)

---

## Changelog

### Version 1.0.0
- Initial release
- smartcheck.sh: System health monitoring with SMART diagnostics
- diskwipe.sh: DoD-compliant secure disk wiping

---

## Contributing

Contributions are welcome. Please ensure:
- All comments remain in English
- Code style matches existing scripts
- No emojis in code or output
- Security best practices are followed
- Changes are tested on multiple systems

---

## Disclaimer

**IMPORTANT:** 

These scripts are provided "as is" without warranty of any kind. The authors are not responsible for:
- Data loss from improper use
- Hardware damage
- System downtime
- Any other consequences of using these scripts

**diskwipe.sh specifically:**
- Permanently destroys data
- Cannot be undone
- User assumes all responsibility
- Always verify disk selection before confirming
- Maintain backups of important data

---

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Check existing documentation
- Review troubleshooting section

---

## Author

Created for system administrators who need reliable disk health monitoring and secure data erasure capabilities.

---

**Last Updated:** January 2026
