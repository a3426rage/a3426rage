#!/bin/bash

set -e

# Check root privileges
if [[ $EUID -ne 0 ]]; then
  echo "Dit script moet als root worden uitgevoerd." >&2
  exit 1
fi

echo "Controleren of growpart, pvresize, lvextend en resize2fs beschikbaar zijn..."
# Controleer of de benodigde tools zijn geïnstalleerd
for cmd in growpart pvresize lvextend resize2fs; do
  if ! command -v $cmd &> /dev/null; then
    echo "Fout: $cmd is niet geïnstalleerd. Installeer het met: apt install $cmd" >&2
    exit 1
  fi
done

PARTITION="/dev/sda2"
DISK="/dev/sda"

echo "Huidige configuratie:"
lsblk

# Vergroot de partitie
echo "Uitbreiden van partitie $PARTITION naar maximale grootte..."
growpart "$DISK" 2

# Controleer of /dev/sda2 een Physical Volume is
if ! pvs | grep -q "$PARTITION"; then
  echo "Fout: $PARTITION is geen Physical Volume (LVM). Controleer de configuratie." >&2
  exit 1
fi

echo "Uitbreiden van het Physical Volume $PARTITION..."
pvresize "$PARTITION"

# Geef een overzicht van Volume Groups
echo "Beschikbare Volume Groups:"
vgs

# Vraag om de naam van de Volume Group
read -rp "Voer de naam van de Volume Group in: " VG

# Controleer of de VG bestaat
if ! vgs | grep -q "^$VG"; then
  echo "Fout: Volume Group $VG bestaat niet. Controleer de naam." >&2
  exit 1
fi

echo "Beschikbare ruimte in $VG:"
vgdisplay "$VG" | grep "Free  PE"

# Vraag om de naam van het Logical Volume
read -rp "Voer de naam van het Logical Volume in (bijv. root): " LV

LV_PATH="/dev/$VG/$LV"

# Controleer of het LV bestaat
if ! lvs | grep -q "$LV_PATH"; then
  echo "Fout: Logical Volume $LV_PATH bestaat niet. Controleer de naam." >&2
  exit 1
fi

# Vergroot het Logical Volume
echo "Uitbreiden van $LV_PATH naar maximale grootte..."
lvextend -l +100%FREE "$LV_PATH"

# Controleer het bestandssysteem
echo "Controleren op bestandssysteem van $LV_PATH..."
FS_TYPE=$(lsblk -no FSTYPE "$LV_PATH")

if [[ "$FS_TYPE" =~ ^(ext4|ext3)$ ]]; then
  echo "Bestandssysteem is $FS_TYPE. Bestandssysteem uitbreiden..."
  resize2fs "$LV_PATH"
elif [[ "$FS_TYPE" == "xfs" ]]; then
  echo "Bestandssysteem is XFS. Bestandssysteem uitbreiden..."
  xfs_growfs "$LV_PATH"
else
  echo "Fout: Ondersteund bestandssysteem ($FS_TYPE) niet gedetecteerd. Ondersteund: ext4, ext3, xfs." >&2
  exit 1
fi

echo "De uitbreiding is voltooid. Huidige configuratie:"
lsblk
