#!/bin/bash
# 07-backup.sh — Clone your Jetson SSD to a microSD card
# Run on the Jetson with a microSD card inserted

set -e

echo "=== Jetson Flight Setup: SSD Backup ==="

# Find the source SSD (boot drive)
BOOT_DEV=$(findmnt -n -o SOURCE /)
echo "Boot device: $BOOT_DEV"

# Find microSD card
SD_DEV=""
for dev in /dev/mmcblk1p1 /dev/mmcblk0p1; do
    if [ -b "$dev" ]; then
        SD_DEV="$dev"
        break
    fi
done

if [ -z "$SD_DEV" ]; then
    echo "ERROR: No microSD card found."
    echo "Insert a microSD card and try again."
    echo "It should appear as /dev/mmcblk1p1 or /dev/mmcblk0p1"
    exit 1
fi

SD_DISK="${SD_DEV%p*}"
echo "microSD card: $SD_DEV (disk: $SD_DISK)"

# Check microSD has enough space
SD_MOUNT=$(findmnt -n -o TARGET "$SD_DEV" 2>/dev/null)
if [ -z "$SD_MOUNT" ]; then
    echo "Mounting microSD..."
    SD_MOUNT="/mnt/sdcard"
    sudo mkdir -p "$SD_MOUNT"
    sudo mount "$SD_DEV" "$SD_MOUNT"
fi

SD_FREE=$(df -BG "$SD_MOUNT" | tail -1 | awk '{print $4}' | tr -d 'G')
SSD_USED=$(df -BG "/" | tail -1 | awk '{print $3}' | tr -d 'G')

echo ""
echo "SSD used: ${SSD_USED}G"
echo "microSD free: ${SD_FREE}G"
echo ""

if [ "$SD_FREE" -lt "$SSD_USED" ]; then
    echo "WARNING: microSD might not have enough space."
    echo "The compressed image will likely be smaller, but no guarantees."
    read -p "Continue anyway? (yes/no): " CONTINUE
    [ "$CONTINUE" != "yes" ] && exit 1
fi

# Create backup filename
DATE=$(date +%Y%m%d)
BACKUP_FILE="$SD_MOUNT/jetson-ssd-backup-${DATE}.img.gz"

echo "Backup file: $BACKUP_FILE"
echo ""
echo "This will take 10-20 minutes depending on SSD size."
read -p "Start backup? (yes/no): " START
[ "$START" != "yes" ] && exit 0

# Run the backup
echo ""
echo "Backing up $BOOT_DEV → $BACKUP_FILE ..."
echo "Started at: $(date)"

sudo dd if="$BOOT_DEV" bs=4M status=progress | gzip -1 | sudo tee "$BACKUP_FILE" > /dev/null

echo ""
echo "Finished at: $(date)"

# Verify the backup
echo ""
echo "Verifying gzip integrity..."
gzip -t "$BACKUP_FILE" && echo "PASSED" || echo "FAILED — backup may be corrupt"

# Show result
BACKUP_SIZE=$(ls -lh "$BACKUP_FILE" | awk '{print $5}')
echo ""
echo "=== Backup Complete ==="
echo "File: $BACKUP_FILE"
echo "Size: $BACKUP_SIZE"
echo ""
echo "To restore:"
echo "  zcat $BACKUP_FILE | sudo dd of=$BOOT_DEV bs=4M status=progress"
echo "=== Done ==="
