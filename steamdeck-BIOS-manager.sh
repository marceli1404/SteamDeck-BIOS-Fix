#!/bin/bash

clear

echo Steam Deck BIOS Manager - script by ryanrudolf
echo https://github.com/ryanrudolfoba/SteamDeck-BIOS-Manager
echo Easily unlock, download, flash, create BIOS backups, and block / unblock BIOS updates!
sleep 2

# Validate sudo without storing the password in a shell variable.
if [ "$(passwd --status "$(whoami)" | tr -s " " | cut -d " " -f 2)" != "P" ]
then
	echo "Sudo password is blank! Set a sudo password first and then re-run this script."
	passwd
	exit 1
fi

if ! sudo -v
then
	zenity --warning --title "Steam Deck BIOS Manager" --text \
		"Sudo authentication failed. Re-run the script and enter your sudo password in the terminal." --width 500 --height 75
	exit 1
fi

# Return a removable/USB disk chosen explicitly by the user. The caller must
# still confirm the destructive operation before wiping it.
select_crisis_usb()
{
	local rows=()
	local device size model selected typed

	while read -r device
	do
		[ -n "$device" ] || continue
		size=$(lsblk -dn -o SIZE "$device" 2>/dev/null | xargs)
		model=$(lsblk -dn -o MODEL "$device" 2>/dev/null | xargs)
		rows+=(FALSE "$device" "${size:-Unknown}" "${model:-Unknown}")
	done < <(lsblk -dpno NAME,TYPE,RM,TRAN | awk '$2 == "disk" && ($3 == "1" || $4 == "usb") { print $1 }')

	if [ ${#rows[@]} -eq 0 ]
	then
		zenity --warning --title "Steam Deck BIOS Manager" --text \
			"No removable USB disk was detected. Plug in the recovery USB drive and try again." --width 500 --height 75
		return 1
	fi

	selected=$(zenity --width 700 --height 320 --list --radiolist \
		--title "Select Crisis Mode USB drive" \
		--column "Select" --column "Device" --column "Size" --column "Model" \
		--print-column=2 "${rows[@]}")

	[ -n "$selected" ] || return 1

	# Reject anything currently hosting critical filesystems even if lsblk marks
	# it removable because of unusual enclosure/firmware reporting.
	if lsblk -nrpo NAME,MOUNTPOINT "$selected" 2>/dev/null | awk '$2 == "/" || $2 == "/home" || $2 == "/boot" || $2 == "/boot/efi" { found=1 } END { exit !found }'
	then
		zenity --error --title "Steam Deck BIOS Manager" --text \
			"Refusing to erase $selected because it contains a critical mounted filesystem." --width 550 --height 75
		return 1
	fi

	typed=$(zenity --entry --title "Confirm destructive USB erase" --text \
		"ALL DATA on $selected will be erased.\n\nType the exact device path below to continue:\n$selected")
	if [ "$typed" != "$selected" ]
	then
		zenity --warning --title "Steam Deck BIOS Manager" --text "Confirmation did not match. Nothing was erased." --width 450 --height 75
		return 1
	fi

	printf '%s\n' "$selected"
}

# display warning / disclaimer
zenity --question --title "Steam Deck BIOS Manager" --text \
	"WARNING: This is for educational and research purposes only! \
	\n\nThe script has been tested with Steam Deck LCD and Steam Deck OLED. \
	\nBefore attempting to DOWNGRADE / FLASH BIOS, make sure to restore your BIOS settings to DEFAULT as pre-caution. \
	\n\nThe author of this script takes no responsibility if something goes wrong! \
	\nA BIOS backup is automatically created so you can restore to a working state. \
       	\nBackup is located in /home/deck/BIOS_Backup. You will need a hardware flasher to recover. \
	\n\nDo you agree to the terms and conditions ?" --width 650 --height 75
			if [ $? -eq 1 ]
			then
				echo User pressed NO. Exit immediately.
				exit
			else
				echo User pressed YES. Continue with the script
			fi

# capture the BOARD name
MODEL=$(cat /sys/class/dmi/id/board_name)

# capture the BIOS version
BIOS_VERSION=$(cat /sys/class/dmi/id/bios_version)

# Crisis Mode USB devices are detected at the moment the destructive action
# is requested; never assume a fixed /dev/sdX device name.

# sanity check - make sure LCD or OLED!
if [ $MODEL = "Jupiter" ]
then
	zenity --question --title "Steam Deck BIOS Manager" --text \
	"The script detected that you are using a Steam Deck LCD Model. \n\nIs this correct ?" --width 450 --height 75
			if [ $? -eq 1 ]
			then
				echo User pressed NO. Exit immediately.
				exit
			else
				echo User pressed YES. Continue with the script
			fi

elif [ $MODEL = "Galileo" ]
then
	zenity --question --title "Steam Deck BIOS Manager" --text \
	"The script detected that you are using a Steam Deck OLED Model. \n\nIs this correct ?" --width 460 --height 75
			if [ $? -eq 1 ]
			then
				echo User pressed NO. Exit immediately.
				exit
			else
				echo User pressed YES. Continue with the script
			fi
else
	zenity --warning --title "Steam Deck BIOS Manager" --text \
		"The script can't determine if its an OLED or LCD.\n\nPlease file a bug report on the Github repo!" --width 400 --height 75
	exit
fi

while true
do
Choice=$(zenity --width 750 --height 400 --list --radiolist --multiple \
	--title "Steam Deck BIOS Manager  - https://github.com/ryanrudolfoba/SteamDeck-BIOS-Manager"\
	--column "Select One" \
	--column "Option" \
	--column="Description - Read this carefully!"\
	FALSE BACKUP "Create a backup of the current BIOS installed."\
	FALSE BLOCK "Prevent SteamOS from automatically installing new BIOS update."\
	FALSE UNBLOCK "Allow SteamOS to automatically install new BIOS update."\
	FALSE SREP "Unlock PBS / CBS BIOS menu using SREP method."\
	FALSE SMOKELESS "Unlock the BIOS v110 to v116 and allow for Smokeless utility."\
	FALSE RYZENADJ "Download ryzenadj and install to /usr/bin."\
	FALSE DOWNLOAD "Download BIOS update from evlaV gitlab repository for manual flashing."\
	FALSE FLASH "Backup and flash BIOS downloaded from evlaV gitlab repository."\
	FALSE CRISIS "Prepare a USB flash drive for Crisis Mode BIOS flashing."\
	TRUE EXIT "***** Exit this script *****")

if [ $? -eq 1 ] || [ "$Choice" == "EXIT" ]
then
	echo User pressed CANCEL / EXIT. Goodbye!
	rm -f $(pwd)/BIOS/F*.fd &> /dev/null
	exit

elif [ "$Choice" == "CRISIS" ]
then
ls $(pwd)/BIOS/F7?????_sign.fd &> /dev/null
if [ $? -eq 0 ]
then
	# create usb flash drive for crisis mode
	clear
	USB_DEVICE=$(select_crisis_usb) || {
		echo "No USB device selected. Go back to main menu."
		continue
	}
	USB_MODEL=$(lsblk -dn -o MODEL "$USB_DEVICE" 2>/dev/null | xargs)
	USB_SIZE=$(lsblk -dn -o SIZE "$USB_DEVICE" 2>/dev/null | xargs)

	zenity --question --title "Steam Deck BIOS Manager" --text \
	"This will prepare the selected drive for Crisis Mode BIOS flashing. \
	\n\nSelected device: $USB_DEVICE \
	\nModel: ${USB_MODEL:-Unknown} \
	\nSize: ${USB_SIZE:-Unknown} \
	\n\nALL CONTENTS OF THIS DRIVE WILL BE DELETED. \
	\n\nDo you want to continue?" --width 650 --height 75
	if [ $? -eq 1 ]
	then
		echo User pressed NO. Go back to main menu.
	else
		echo "User confirmed destructive erase of $USB_DEVICE."

		# Unmount every existing partition on the selected device.
		while read -r partition
		do
			[ -n "$partition" ] && sudo umount "$partition" &> /dev/null || true
		done < <(lsblk -lnpo NAME,TYPE "$USB_DEVICE" | awk '$2 == "part" { print $1 }')

		if ! sudo wipefs -a "$USB_DEVICE"
		then
			zenity --error --title "Steam Deck BIOS Manager" --text "Failed to erase partition signatures on $USB_DEVICE. Nothing else was written." --width 550 --height 75
			continue
		fi

		if ! echo ',,b;' | sudo sfdisk "$USB_DEVICE"
		then
			zenity --error --title "Steam Deck BIOS Manager" --text "Failed to create a partition on $USB_DEVICE." --width 500 --height 75
			continue
		fi

		sudo partprobe "$USB_DEVICE" &> /dev/null || true
		sleep 1
		USB_PART=$(lsblk -lnpo NAME,TYPE "$USB_DEVICE" | awk '$2 == "part" { print $1; exit }')
		if [ -z "$USB_PART" ]
		then
			zenity --error --title "Steam Deck BIOS Manager" --text "The new USB partition could not be detected. No filesystem was created." --width 550 --height 75
			continue
		fi

		if ! sudo mkfs.vfat "$USB_PART"
		then
			zenity --error --title "Steam Deck BIOS Manager" --text "Failed to format $USB_PART as FAT32." --width 500 --height 75
			continue
		fi

		TEMP_MOUNT=$(mktemp -d)
		if ! sudo mount "$USB_PART" "$TEMP_MOUNT"
		then
			rmdir "$TEMP_MOUNT"
			zenity --error --title "Steam Deck BIOS Manager" --text "Failed to mount $USB_PART." --width 500 --height 75
			continue
		fi

		COPY_OK=0
		if [ "$MODEL" = "Jupiter" ]
		then
			sudo cp "$(pwd)/BIOS/F7A0120_sign.fd" "$TEMP_MOUNT/F7ARecovery.fd" && COPY_OK=1
		else
			sudo cp "$(pwd)/BIOS/F7G0107_sign.fd" "$TEMP_MOUNT/F7GRecovery.fd" && COPY_OK=1
		fi

		sync
		sudo umount "$TEMP_MOUNT"
		rmdir "$TEMP_MOUNT"

		if [ "$COPY_OK" -ne 1 ]
		then
			zenity --error --title "Steam Deck BIOS Manager" --text "Failed to copy the recovery BIOS to $USB_PART." --width 500 --height 75
			continue
		fi

		zenity --warning --title "Steam Deck BIOS Manager" --text "USB flash drive for Crisis Mode BIOS flashing has been created on $USB_DEVICE. \
			\n\nThanks to Stanto / www.stanto.com for the writeup regarding Crisis Mode BIOS flashing!" --width 500 --height 75
	fi
else
	zenity --warning --title "Steam Deck BIOS Manager" --text \
		"BIOS files does not exist.\n\nPerform a DOWNLOAD operation first." --width 400 --height 75
fi
elif [ "$Choice" == "BACKUP" ]
then
	clear
	# create BIOS backup and then flash the BIOS
	mkdir ~/BIOS_backup 2> /dev/null
	sudo /usr/share/jupiter_bios_updater/h2offt \
		~/BIOS_backup/jupiter-$BIOS_VERSION-bios-backup-$(date +%B%d).bin -O
	zenity --warning --title "Steam Deck BIOS Manager" --text "BIOS backup has been completed! \
		\n\nBackup is saved in BIOS_backup folder." --width 400 --height 75

elif [ "$Choice" == "BLOCK" ]
then
	clear
	# this will prevent BIOS updates to be applied automatically by SteamOS
	sudo steamos-readonly disable
	sudo systemctl mask jupiter-biosupdate
	sudo mkdir -p /foxnet/bios/ &> /dev/null
	sudo touch /foxnet/bios/INHIBIT &> /dev/null
	sudo mkdir /usr/share/jupiter_bios/bak &> /dev/null
	sudo mv /usr/share/jupiter_bios/F* /usr/share/jupiter_bios/bak &> /dev/null
	sudo steamos-readonly enable
	zenity --warning --title "Steam Deck BIOS Manager" --text "BIOS updates has been blocked!" --width 400 --height 75

elif [ "$Choice" == "UNBLOCK" ]
then
	clear
	sudo steamos-readonly disable
	sudo systemctl unmask jupiter-biosupdate
	sudo rm -rf /foxnet &> /dev/null
	sudo mv /usr/share/jupiter_bios/bak/F* /usr/share/jupiter_bios &> /dev/null
	sudo rmdir /usr/share/jupiter_bios/bak &> /dev/null
	sudo steamos-readonly enable
	zenity --warning --title "Steam Deck BIOS Manager" --text "BIOS updates has been unblocked!" --width 400 --height 75

elif [ "$Choice" == "SREP" ]
then
	# display SREP warning and additional info
	zenity --question --title "Steam Deck BIOS Manager" --text \
		"WARNING: This is for educational and research purposes only! \
		\n\nSREP override config is from https://stanto.com \
		\n\nIt is suggested to familiarize yourself with what the SREP does by visiting his blog. \
		\n\n\nDo you want to open browser window to read more details on https://stanto.com ? \
		\n\nOnce you are done reading on https://stanto.com you can close the browser window and return to this script." --width 650 --height 75

		if [ $? -eq 1 ]
		then
			echo User pressed NO. Proceed with the script.
		else
			echo User pressed YES. Launch browser window and continue with the script.
			xdg-open https://www.stanto.com/steam-deck/how-to-unlock-the-lcd-and-oled-steam-deck-bios-for-increased-tdp-and-other-features/ &> /dev/null
		fi

	clear
	SREP_Choice=$(zenity --width 660 --height 220 --list --radiolist --multiple --title "Waydroid Toolbox" \
		--column "Select One" --column "Option" --column="Description - Read this carefully!"\
		FALSE ENABLE "Copy SREP files to the ESP."\
		FALSE DISABLE "Remove SREP files from the ESP."\
		TRUE MENU "***** Go back to Steam Deck BIOS Manager Main Menu *****")

		if [ $? -eq 1 ] || [ "$SREP_Choice" == "MENU" ]
		then
			echo User pressed CANCEL. Going back to main menu.

		elif [ "$SREP_Choice" == "ENABLE" ]
		then
			# cleanup old SREP config files
			sudo rm -rf /esp/efi/$MODEL-SREP /esp/SREP.log /esp/SREP_Config.cfg

			# Download SREP files
			echo Downloading Steam Deck SREP  files. Please wait.
			curl -s -o $MODEL-SREP.zip --referer https://www.stanto.com https://www.stanto.com/files/toolkittounlock-stanto.zip
			# Unzip the SREP files
			mkdir $(pwd)/$MODEL-SREP
			unzip -j -d $(pwd)/$MODEL-SREP $(pwd)/$MODEL-SREP.zip

			# check if there is error when unzipping
			if [ $? -eq 0 ]
			then
				# Copy SREP files to the ESP
				sudo cp -R $(pwd)/$MODEL-SREP /esp/efi
				sudo cp $(pwd)/$MODEL-SREP/SREP_Config.cfg /esp

				# delete the SREP files
				rm -rf $(pwd)/$MODEL-SREP $(pwd)/$MODEL-SREP.zip
				zenity --warning --title "Steam Deck BIOS Manager" --text "SREP files has been copied to the ESP!" --width 350 --height 75
			else
				# delete the SREP files
				rm -rf $(pwd)/$MODEL-SREP $(pwd)/$MODEL-SREP.zip
				zenity --warning --title "Steam Deck BIOS Manager" --text "There was an error downloading / unzipping the SREP files!" \
					--width 350 --height 75

			fi

		elif [ "$SREP_Choice" == "DISABLE" ]
		then
			# Delete SREP files from ESP
			sudo rm -rf /esp/efi/$MODEL-SREP /esp/SREP.log /esp/SREP_Config.cfg

			zenity --warning --title "Steam Deck BIOS Manager" --text "SREP files has been removed from the ESP!" --width 350 --height 75
		fi

elif [ "$Choice" == "RYZENADJ" ]
then
	clear
	RYZENADJ_Choice=$(zenity --width 660 --height 220 --list --radiolist --multiple --title "Waydroid Toolbox" \
		--column "Select One" --column "Option" --column="Description - Read this carefully!"\
		FALSE INSTALL "Download and install ryzenadj to /usr/bin"\
		FALSE UNINSTALL "Remove ryzenadj."\
		TRUE MENU "***** Go back to Steam Deck BIOS Manager Main Menu *****")

		if [ $? -eq 1 ] || [ "$RYZENADJ_Choice" == "MENU" ]
		then
			echo User pressed CANCEL. Going back to main menu.

		elif [ "$RYZENADJ_Choice" == "INSTALL" ]
		then
			# Download latest ryzenadj from github
			wget -q https://github.com/ryanrudolfoba/SteamDeck-BIOS-Manager/raw/main/extras/ryzenadj
			chmod +x ryzenadj

			# Copy ryzenadj to /usr/bin
			sudo steamos-readonly disable
			sudo mv ryzenadj /usr/bin/ryzenadj
			sudo steamos-readonly enable

		elif [ "$RYZENADJ_Choice" == "UNINSTALL" ]
		then
			# Delete ryzenadj from /usr/bin
			sudo steamos-readonly disable
			sudo rm /usr/bin/ryzenadj
			sudo steamos-readonly enable

			zenity --warning --title "Steam Deck BIOS Manager" --text "ryzenadj has been removed!" --width 350 --height 75
		fi


elif [ "$Choice" == "SMOKELESS" ]
then
	clear
	if [ "$MODEL" == "Galileo" ]
	then
		zenity --warning --title "Steam Deck BIOS Manager" --text "Steam Deck OLED can\'t be unlocked using Smokeless." --width 400 --height 75
	else
		if [ "$BIOS_VERSION" == "F7A0110" ] || [ "$BIOS_VERSION" == "F7A0113" ] || \
			[ "$BIOS_VERSION" == "F7A0115" ] || [ "$BIOS_VERSION" == "F7A0116" ]
		then
			curl -s -O --output-dir $(pwd)/ -L https://gitlab.com/evlaV/jupiter-PKGBUILD/-/raw/master/bin/jupiter-bios-unlock
			chmod +x $(pwd)/jupiter-bios-unlock
			sudo $(pwd)/jupiter-bios-unlock
			zenity --warning --title "Steam Deck BIOS Manager" --text "BIOS has been unlocked using Smokeless. \
				\n\nYou can now use Smokeless or access the AMD PBS CBS menu in the BIOS." --width 400 --height 75
		else
			zenity --warning --title "Steam Deck BIOS Manager" --text "BIOS $BIOS_VERSION can\'t be unlocked using Smokeless. \
				\n\nFlash BIOS v110 - v116 only for Smokeless unlock tool to work." --width 400 --height 75
		fi
	fi

elif [ "$Choice" == "DOWNLOAD" ]
then
	clear
	# create BIOS directory where the signed BIOS files will be downloaded
	mkdir $(pwd)/BIOS &> /dev/null

	# if there are existing signed BIOS files then delete them and download fresh copies
	echo cleaning up BIOS directory
	rm -f $(pwd)/BIOS/F*.fd &> /dev/null
	sleep 2

	# start download from gitlab repository
	if [ $MODEL = "Jupiter" ]
	then
		echo Downloading Steam Deck LCD - Jupiter BIOS files. Please wait.
		echo downloading Steam Deck LCD - Jupiter BIOS F7A0110
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/0660b2a5a9df3bd97751fe79c55859e3b77aec7d/usr/share/jupiter_bios/F7A0110_sign.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0113
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/bf77354719c7a74097a23bed4fb889df4045aec4/usr/share/jupiter_bios/F7A0113_sign.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0115
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/5644a5692db16b429b09e48e278b484a2d1d4602/usr/share/jupiter_bios/F7A0115_sign.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0116
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/38f7bdc2676421ee11104926609b4cc7a4dbc6a3/usr/share/jupiter_bios/F7A0116_sign.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0118
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/f79ccd15f68e915cc02537854c3b37f1a04be9c3/usr/share/jupiter_bios/F7A0118_sign.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0119
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/bc5ca4c3fc739d09e766a623efd3d98fac308b3e/usr/share/jupiter_bios/F7A0119_sign.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0120
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/a43e38819ba20f363bdb5bedcf3f15b75bf79323/usr/share/jupiter_bios/F7A0120_sign.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0121
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/7ffc22a4dc083c005e26676d276bdbd90dd1de5e/usr/share/jupiter_bios/F7A0121_sign.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0131
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/eb91bebf4c2e5229db071720250d80286368e4e2/usr/share/jupiter_bios/F7A0131_sign.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0133
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/5c14655a762870754f9d8574682b6727cb640904/usr/share/jupiter_bios/F7A0133_sign.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0110_DeckHD
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://www.deckhd.com/downloads/F7A0110_DeckHD.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0113_DeckHD
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://www.deckhd.com/downloads/F7A0113_DeckHD.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0115_DeckHD
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://www.deckhd.com/downloads/F7A0115_DeckHD.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0116_DeckHD
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://www.deckhd.com/downloads/F7A0116_DeckHD.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0118_DeckHD
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://www.deckhd.com/downloads/F7A0118_DeckHD.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0119_DeckHD
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://www.deckhd.com/downloads/F7A0119_DeckHD.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0120_DeckHD
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://www.deckhd.com/downloads/F7A0120_DeckHD.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0121_DeckHD
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://www.deckhd.com/downloads/F7A0121_DeckHD.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0131_DeckHD
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://www.deckhd.com/downloads/F7A0131_DeckHD.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0110_DeckHD_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0110_DeckHD_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0113_DeckHD_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0113_DeckHD_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0115_DeckHD_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0115_DeckHD_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0116_DeckHD_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0116_DeckHD_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0118_DeckHD_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0118_DeckHD_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0119_DeckHD_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0119_DeckHD_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0120_DeckHD_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0120_DeckHD_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0121_DeckHD_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0121_DeckHD_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0131_DeckHD_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0131_DeckHD_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0110_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0110_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0113_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0113_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0115_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0115_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0116_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0116_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0118_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0118_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0119_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0119_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0120_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0120_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0121_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0121_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS F7A0131_32GB
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://balika011.hu/deck_32gb/F7A0131_32GB.fd

		echo downloading Steam Deck LCD - Jupiter BIOS from ShadeTechnik / DeckSight
  		curl -s https://api.github.com/repos/ShadeTechnik/DeckSight-Public/releases/latest | \
			grep "browser_download_url" | cut -d "\"" -f4 | wget --quiet --no-clobber --input-file -

  		tar -xvf DeckSight.tar.gz -C $(pwd)/BIOS --strip-components=1 bios/F*.fd
  		
		echo Steam Deck LCD - Jupiter BIOS download complete!
	
	elif [ $MODEL = "Galileo" ]
	then
		echo Downloading Steam Deck OLED - Galileo BIOS files. Please wait.
		echo downloading Steam Deck OLED - Galileo BIOS F7G0112
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/6101a30a621a2119e8c5213e872b268973659964/usr/share/jupiter_bios/F7G0112_sign.fd
		
		echo downloading Steam Deck OLED - Galileo BIOS F7G0107
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/a43e38819ba20f363bdb5bedcf3f15b75bf79323/usr/share/jupiter_bios/F7G0107_sign.fd
		
		echo downloading Steam Deck OLED - Galileo BIOS F7G0109
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/7ffc22a4dc083c005e26676d276bdbd90dd1de5e/usr/share/jupiter_bios/F7G0109_sign.fd
		
		echo downloading Steam Deck OLED - Galileo BIOS F7G0110
		curl -s -O --output-dir $(pwd)/BIOS/ -L \
			https://gitlab.com/evlaV/jupiter-hw-support/-/raw/eb91bebf4c2e5229db071720250d80286368e4e2/usr/share/jupiter_bios/F7G0110_sign.fd
		
		echo Steam Deck OLED - Galileo BIOS download complete!
	fi

	# verify the BIOS md5 hash is good
	for BIOS_FD in $(pwd)/BIOS/*.fd
	do 
		grep $(md5sum "$BIOS_FD" | cut -d " " -f 1) $(pwd)/md5.txt &> /dev/null
		if [ $? -eq 0 ]
		then
			echo $BIOS_FD md5 hash is good!
		else
			echo $BIOS_FD md5 hash error! 
			echo md5 hash check failed! This could be due to corrupted downloads.
			echo Perform the DOWNLOAD operation again!
			rm $(pwd)/BIOS/*.fd
		fi
	done

elif [ "$Choice" == "FLASH" ]
then
	clear
	ls $(pwd)/BIOS/F7?????_*.fd &> /dev/null
	if [ $? -eq 0 ]
	then
		BIOS_Choice=$(zenity --title "Steam Deck BIOS Manager" --width 400 --height 400 --list \
			--column "BIOS Version" $(ls -l $(pwd)/BIOS/F7?????_*.fd | sed s/^.*\\/\//) )
		if [ $? -eq 1 ]
		then
			echo User pressed CANCEL. Go back to main menu!
		else
			zenity --question --title "Steam Deck BIOS Manager" --text \
			"Do you want to backup the current BIOS before updating to $BIOS_Choice?\n\nProceed?" --width 400 --height 75
			if [ $? -eq 1 ]
			then
				echo User pressed NO. Ask again before updating the BIOS just to be sure.
				zenity --question --title "Steam Deck BIOS Manager" --text \
					"Current BIOS will be updated to $BIOS_Choice!\n\nProceed?" --width 400 --height 75
				if [ $? -eq 1 ]
				then
					echo User pressed NO. Go back to main menu. 
				else
					echo User pressed YES. Flash $BIOS_Choice immediately!

					# this will prevent BIOS updates to be applied automatically by SteamOS
					sudo steamos-readonly disable
					sudo systemctl mask jupiter-biosupdate
					sudo mkdir -p /foxnet/bios/ 2> /dev/null
					sudo touch /foxnet/bios/INHIBIT 2> /dev/null
					sudo mkdir /usr/share/jupiter_bios/bak 2> /dev/null
					sudo mv /usr/share/jupiter_bios/F* /usr/share/jupiter_bios/bak 2> /dev/null
					sudo steamos-readonly enable

					# flash the BIOS
					sudo /usr/share/jupiter_bios_updater/h2offt $(pwd)/BIOS/$BIOS_Choice -all
				fi
			else
				echo User pressed YES. Perform BIOS backup and then flash $BIOS_Choice!
				
				# this will prevent BIOS updates to be applied automatically by SteamOS
				sudo steamos-readonly disable
				sudo systemctl mask jupiter-biosupdate
				sudo mkdir -p /foxnet/bios/ 2> /dev/null
				sudo touch /foxnet/bios/INHIBIT 2> /dev/null
				sudo mkdir /usr/share/jupiter_bios/bak 2> /dev/null
				sudo mv /usr/share/jupiter_bios/F* /usr/share/jupiter_bios/bak 2> /dev/null
				sudo steamos-readonly enable

				# create BIOS backup and then flash the BIOS
				mkdir ~/BIOS_backup 2> /dev/null
				sudo /usr/share/jupiter_bios_updater/h2offt \
					~/BIOS_backup/jupiter-$BIOS_VERSION-bios-backup-$(date +%B%d).bin -O
				sudo /usr/share/jupiter_bios_updater/h2offt $(pwd)/BIOS/$BIOS_Choice -all
			fi
		fi
	else
		zenity --warning --title "Steam Deck BIOS Manager" --text \
			"BIOS files does not exist.\n\nPerform a DOWNLOAD operation first." --width 400 --height 75
	fi
fi
done
