#!/bin/bash

# Zorg ervoor dat het script met rootrechten draait
if [ "$EUID" -ne 0 ]; then
  echo "Dit script moet met root-rechten worden uitgevoerd."
  exit 1
fi

# Installeer vereiste tools als ze niet aanwezig zijn
for cmd in growpart pvresize lvextend resize2fs xfsgrowfs; do
  if ! command -v $cmd &> /dev/null; then
    if [ "$cmd" == "growpart" ]; then
      echo "$cmd is niet geïnstalleerd. Installeer het met: sudo apt install cloud-guest-utils"
      sudo apt install cloud-guest-utils -y
    elif [ "$cmd" == "pvresize" ]; then
      echo "$cmd is niet geïnstalleerd. Installeer het met: sudo apt install lvm2"
      sudo apt install lvm2 -y
    else
      echo "$cmd is niet geïnstalleerd. Installeer het met: sudo apt install $cmd"
      sudo apt install $cmd -y
    fi
  fi
done

# Vergroot de partitie (/dev/sda2) met beschikbare vrije ruimte
growpart /dev/sda 2

# Resize Physical Volume (PV) naar de nieuwe schijfruimte
pvresize /dev/sda2

# Verkrijg de naam van de Volume Group (VG) automatisch
VG_NAME=$(vgs --noheadings -o vg_name | awk '{print $1}')
if [ -z "$VG_NAME" ]; then
  echo "Fout: Geen Volume Group gevonden!" >&2
  exit 1
fi

# Verkrijg de naam van het Logical Volume (LV) automatisch
LV_NAME=$(lvs --noheadings -o lv_name | awk '{print $1}')
if [ -z "$LV_NAME" ]; then
  echo "Fout: Geen Logical Volume gevonden!" >&2
  exit 1
fi

# Vergroot het Logical Volume met de nieuwe beschikbare ruimte
lvextend -l +100%FREE /dev/$VG_NAME/$LV_NAME

# Verkrijg het bestandssysteemtype automatisch
FS_TYPE=$(blkid -o value -s TYPE /dev/$VG_NAME/$LV_NAME)

# Vergroot het bestandssysteem afhankelijk van het type
if [[ "$FS_TYPE" =~ ^(ext4|ext3)$ ]]; then
  echo "Bestandssysteem is $FS_TYPE. Uitbreiden van het bestandssysteem..."
  resize2fs /dev/$VG_NAME/$LV_NAME
elif [[ "$FS_TYPE" == "xfs" ]]; then
  echo "Bestandssysteem is XFS. Uitbreiden van het bestandssysteem..."
  mount_point=$(findmnt -n -o TARGET -S /dev/$VG_NAME/$LV_NAME)
  if [ -z "$mount_point" ]; then
    echo "Fout: Geen mountpoint gevonden voor $LV_NAME" >&2
    exit 1
  fi
  xfsgrowfs "$mount_point"
else
  echo "Fout: Ondersteund bestandssysteem ($FS_TYPE) niet gedetecteerd. Ondersteund: ext4, ext3, xfs." >&2
  exit 1
fi

# Toon de nieuwe schijfruimte en LVM-configuratie
lsblk
vgs
lvs
