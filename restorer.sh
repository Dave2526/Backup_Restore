#!/bin/bash
# ============================================
# Raspberry Pi Restore | Image -> SD-Karte
# ============================================

# ============================================
# Start- und Root-Erzwingung: ./ + sudo
# ============================================
if [[ "$0" != */* ]] || [ "$EUID" -ne 0 ]; then
    echo ""
    echo "Skript wird automatisch korrekt gestartet..."
    echo "Hinweis: muss mit Root-Rechten und Pfadangabe (./) laufen."
    echo ""
    SCRIPT_PATH="./${0##*/}"  
    exec sudo "$SCRIPT_PATH" "$@"
fi

# ============================================
# Variablen
# ============================================
HDD_MOUNT="/mnt/usb"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PISHRINK="$SCRIPT_DIR/PiShrink/pishrink.sh"

echo ""
echo "################################"
echo "# Restorer | Image -> SD-Karte #"
echo "################################"

# ============================================
# USB-HDD suchen
# ============================================
mapfile -t USB_DISKS < <(lsblk -d -o NAME,TRAN | awk '$2=="usb"{print $1}')
if [ ${#USB_DISKS[@]} -eq 0 ]; then
    echo "Keine USB-Datenträger gefunden."
    exit 1
fi

echo "Gefundene USB-Datenträger:"
for i in "${!USB_DISKS[@]}"; do
    DEV="/dev/${USB_DISKS[$i]}"
    SIZE=$(lsblk -dn -o SIZE "$DEV")
    FREE=$(df -h | awk -v dev="${DEV}1" '$1==dev {print $4}')
    echo "$((i+1))) $DEV (Größe: $SIZE, Frei: ${FREE:-unbekannt})"
done

read -p "Wähle die HDD mit dem Backup aus (Nummer): " HDD_CHOICE
HDD_DEVICE="/dev/${USB_DISKS[$((HDD_CHOICE-1))]}"

sudo mkdir -p "$HDD_MOUNT"
if mountpoint -q "$HDD_MOUNT"; then
    sudo umount "$HDD_MOUNT"
fi
sudo mount "${HDD_DEVICE}1" "$HDD_MOUNT"
if ! mountpoint -q "$HDD_MOUNT"; then
    echo "Mount fehlgeschlagen."
    exit 1
fi
echo "USB-HDD erfolgreich gemountet."

# ============================================
# Backup-Image auswählen
# ============================================
echo "Verfügbare Backup-Ordner:"
mapfile -t DIRS < <(find "$HDD_MOUNT" -maxdepth 1 -mindepth 1 -type d ! -name "Dateien")
for i in "${!DIRS[@]}"; do
    echo "$((i+1))) ${DIRS[$i]##*/}"
done

read -p "Ordner wählen oder Namen eingeben: " DIR_INPUT
if [[ "$DIR_INPUT" =~ ^[0-9]+$ ]] && [ "$DIR_INPUT" -le "${#DIRS[@]}" ]; then
    BACKUP_DIR="${DIRS[$((DIR_INPUT-1))]}"
else
    BACKUP_DIR="$HDD_MOUNT/$DIR_INPUT"
fi

mapfile -t IMAGES < <(find "$BACKUP_DIR" -maxdepth 1 -type f -name "*.img")
if [ ${#IMAGES[@]} -eq 0 ]; then
    echo "Keine Backup-Images gefunden!"
    exit 1
fi

echo "Gefundene Backup-Images:"
for i in "${!IMAGES[@]}"; do
    echo "$((i+1))) ${IMAGES[$i]##*/}"
done

read -p "Backup-Image wählen (Nummer): " IMG_CHOICE
IMAGE_FILE="${IMAGES[$((IMG_CHOICE-1))]}"

# ============================================
# Ziel-SD-Karte auswählen
# ============================================
echo "Mögliche Ziel-SD-Karten:"
mapfile -t SD_CARDS < <(lsblk -d -o NAME,TYPE,TRAN | awk '$2=="disk" && $3=="usb"')
if [ ${#SD_CARDS[@]} -eq 0 ]; then
    echo "Keine SD-Karten gefunden!"
    exit 1
fi

for i in "${!SD_CARDS[@]}"; do
    SIZE=$(lsblk -dn -o SIZE "/dev/${SD_CARDS[$i]}")
    MODEL=$(lsblk -dn -o MODEL "/dev/${SD_CARDS[$i]}")
    echo "$((i+1))) /dev/${SD_CARDS[$i]} ($SIZE) - $MODEL"
done

read -p "Ziel-SD-Karte wählen (Nummer): " SD_CHOICE
DEVICE_PATH="/dev/${SD_CARDS[$((SD_CHOICE-1))]}"

echo ""
echo "================================================="
echo " Image       : $IMAGE_FILE"
echo " Zielgerät   : $DEVICE_PATH"
echo "================================================="
read -p "Fortfahren? ALLE DATEN AUF DER SD-KARTE GEHEN VERLOREN! (j/N): " FINAL_CONFIRM
if [[ "$FINAL_CONFIRM" != "j" && "$FINAL_CONFIRM" != "J" ]]; then
    echo "Abbruch."
    exit 1
fi

# ============================================
# Restore starten: dd mit status=progress
# ============================================
echo "Starte Wiederherstellung auf $DEVICE_PATH..."
sudo dd if="$IMAGE_FILE" of="$DEVICE_PATH" bs=4M status=progress conv=fsync
sync

echo "Restore abgeschlossen!"
