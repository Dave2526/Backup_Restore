#!/bin/bash
# ============================================
# Raspberry Pi SD-Backup | SD-Karte -> Image (mit PiShrink)
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
echo "###############################"
echo "# Backup | SD-Karte -> Image #"
echo "###############################"

# ============================================
# USB-HDD suchen und anzeigen
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

read -p "Wähle die Ziel-HDD aus (Nummer): " HDD_CHOICE
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
# Ordner auswählen oder neu erstellen
# ============================================
echo "Vorhandene Ordner auf der HDD:"
mapfile -t DIRS < <(find "$HDD_MOUNT" -maxdepth 1 -mindepth 1 -type d ! -name "Dateien")
for i in "${!DIRS[@]}"; do
    echo "$((i+1))) ${DIRS[$i]##*/}"
done

read -p "Neuen Ordnernamen eingeben oder Nummer wählen: " DIR_INPUT
if [[ "$DIR_INPUT" =~ ^[0-9]+$ ]] && [ "$DIR_INPUT" -le "${#DIRS[@]}" ]; then
    TARGET_DIR="${DIRS[$((DIR_INPUT-1))]}"
else
    TARGET_DIR="$HDD_MOUNT/$DIR_INPUT"
    sudo mkdir -p "$TARGET_DIR"
fi

# ============================================
# SD-Karten-Erkennung: nur USB, nicht HDD
# ============================================
echo "Mögliche Quell-SD-Karten:"
mapfile -t SD_CARDS < <(
    lsblk -dn -o NAME,TYPE,TRAN |
    awk -v HDD="$(basename "$HDD_DEVICE")" '$2=="disk" && $3=="usb" && $1!=HDD {print $1}'
)
if [ ${#SD_CARDS[@]} -eq 0 ]; then
    echo "Keine SD-Karten gefunden!"
    exit 1
fi

for i in "${!SD_CARDS[@]}"; do
    SIZE=$(lsblk -dn -o SIZE "/dev/${SD_CARDS[$i]}")
    MODEL=$(lsblk -dn -o MODEL "/dev/${SD_CARDS[$i]}")
    echo "$((i+1))) /dev/${SD_CARDS[$i]} ($SIZE) - $MODEL"
done

DEVICE="${SD_CARDS[0]}"
DEVICE_PATH="/dev/$DEVICE"
read -p "Quellgerät wählen oder ENTER für Vorschlag (/dev/$DEVICE): " USER_CHOICE
if [[ -n "$USER_CHOICE" ]]; then
    DEVICE_PATH="$USER_CHOICE"
fi
if [ ! -b "$DEVICE_PATH" ]; then
    echo "Ungültiges Gerät."
    exit 1
fi
echo "Ausgewähltes Quellgerät: $DEVICE_PATH"

# ============================================
# Dateiname generieren
# ============================================
DATE=$(date +%Y-%m-%d_%H-%M)
IMAGE_FILE="$TARGET_DIR/backup_$DATE.img"

# ============================================
# Größenprüfung
# ============================================
SD_SIZE_BYTES=$(sudo blockdev --getsize64 "$DEVICE_PATH")
if ! [[ "$SD_SIZE_BYTES" =~ ^[0-9]+$ ]]; then
    echo "Fehler: Konnte Gerätegröße nicht ermitteln."
    exit 1
fi

FREE_BYTES=$(df --output=avail -B1 "$TARGET_DIR" | tail -n1)
if [ "$FREE_BYTES" -lt "$SD_SIZE_BYTES" ]; then
    echo ""
    echo "WARNUNG: Auf $TARGET_DIR ist vermutlich nicht genug Platz!"
    read -p "Trotzdem fortfahren? (j/N): " SIZE_CONFIRM
    if [[ "$SIZE_CONFIRM" != "j" && "$SIZE_CONFIRM" != "J" ]]; then
        echo "Abbruch."
        exit 1
    fi
fi

# ============================================
# Finale Bestätigung
# ============================================
SOURCE_SIZE=$(lsblk -dn -o SIZE "$DEVICE_PATH")
echo ""
echo "================================================="
echo " Quelle       : $DEVICE_PATH ($SOURCE_SIZE)"
echo " Zieldatei    : $IMAGE_FILE"
echo "================================================="
read -p "Fortfahren? (j/N): " FINAL_CONFIRM
if [[ "$FINAL_CONFIRM" != "j" && "$FINAL_CONFIRM" != "J" ]]; then
    echo "Abbruch."
    exit 1
fi

# ============================================
# Backup starten: dd -> PiShrink
# ============================================
echo "Starte Backup..."
sudo dd if="$DEVICE_PATH" of="$IMAGE_FILE" bs=4M status=progress conv=fsync
sync

echo "Shrinke Image mit PiShrink..."
sudo "$PISHRINK" "$IMAGE_FILE"

# ============================================
# Backup abgeschlossen: Größe anzeigen
# ============================================
FINAL_SIZE=$(du -h "$IMAGE_FILE" | awk '{print $1}')
echo "Backup abgeschlossen: $IMAGE_FILE ($FINAL_SIZE)"
