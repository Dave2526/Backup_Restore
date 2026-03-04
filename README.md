# Backup_RestoreScript für Backup (mit verkleinern) einer SD-Karte via USB Kartenleser auf eine USB HDD


# Vorbereitung des Raspberry Pi Backup-Systems

Dieses Dokument beschreibt, wie das Backup- und Restore-System auf einem Raspberry Pi eingerichtet wird, inklusive PiShrink, Skripten und Ordnerstruktur.

---

1. Ordnerstruktur erstellen

cd ~

mkdir -p imager

cd imager

Die Struktur sollte danach wie folgt aussehen:

~/imager/

  ├── imager.sh         # Backup-Skript

  ├── restorer.sh       # Restore-Skript

  └── PiShrink/         # PiShrink-Skript von GitHub

---

2. PiShrink / Abhängikeiten installieren

sudo apt install pv git

PiShrink wird über GitHub geklont:

git clone https://github.com/Drewsif/PiShrink.git
chmod +x PiShrink/pishrink.sh

---

3. Skripte vorbereiten

Kopiere die Skripte imager.sh (Backup) und restorer.sh (Restore) in ~/imager und mache sie ausführbar:

chmod +x ~/imager/*.sh

---

4. USB-HDD vorbereiten

1. USB-HDD anschließen.
2. Mountpunkt erstellen:

sudo mkdir -p /mnt/usb


3. Optional: Unterordner für Backups erstellen:

sudo mkdir -p /mnt/usb/arbeits-pi

sudo chown pi:pi /mnt/usb/arbeits-pi

Hinweis: Die Skripte erkennen automatisch vorhandene Ordner, der Ordner „Dateien“ wird ignoriert.

---

5. Berechtigungen prüfen

- PiShrink: chmod +x ~/imager/PiShrink/pishrink.sh
- Skripte: chmod +x ~/imager/*.sh

---

6. Testlauf vorbereiten# Backup und Restore von Raspberry Pi SD-Karten

# Nutzung

1. Backup einer SD-Karte

1. SD-Karte über USB-Kartenleser anschließen.
2. USB-HDD anschließen.
3. Backup-Skript starten:

cd ~/imager
./imager.sh

4. Ablauf des Skripts:

- USB-HDD wird automatisch unter /mnt/usb gemountet.
- Zielordner wählen oder neu erstellen.
- Quell-SD-Karte wird automatisch erkannt (nur USB-Karten, keine interne SD).
- Größenprüfung: Warnung, falls nicht genügend Platz.
- Finale Bestätigung.
- Backup wird erstellt:
  1. Roh-Image mit dd
  2. PiShrink schrumpft das Image
  3. Gzip-Komprimierung
- Ergebnis: /mnt/usb/<Zielordner>/backup_YYYY-MM-DD_HH-MM.img.gz

---

2. Restore einer SD-Karte

1. Ziel-SD-Karte über USB-Kartenleser anschließen.
2. USB-HDD anschließen.
3. Restore-Skript starten:

cd ~/imager
./restorer.sh

4. Ablauf des Skripts:

- USB-HDD mounten.
- Backup-Ordner auswählen.
- Image-Datei auswählen.
- Ziel-SD-Karte wählen.
- Größenprüfung: Warnung, falls Image größer als SD-Karte.
- Finale Bestätigung.
- Restore wird durchgeführt: .img.gz wird entpackt und direkt auf die SD-Karte geschrieben.

---

3. Wichtige Hinweise

- Skripte immer mit ./ und Root-Rechten starten: sudo ./imager.sh oder sudo ./restorer.sh.
- PiShrink reduziert nur Linux-Partitionen, FAT/NTFS auf der HDD wird nicht verändert.
- SD-Karten genau prüfen, um versehentliches Überschreiben zu vermeiden.
- Backup-Images sind portabel und können auf anderen Raspberry Pis wiederhergestellt werden.

---

4. Beispielhafte Ordnerstruktur auf der HDD

/mnt/usb/

└── arbeits-pi/

  ├── backup_2026-03-04_07-29.img.gz  
  
  └── backup_2026-03-10_08-15.img.gz

- SD-Karte über USB-Kartenleser anschließen.
- USB-HDD anschließen.
- Alles ist jetzt bereit für den Backup- und Restore-Prozess.


