#!/bin/bash

export WINEARCH="win32"
export WINEPREFIX="prefix-placeholder"

SELECTION=$(zenity --list \
  --title "Select FO3 tool" \
  --text "Select the tool you would like to launch, then click \"OK\"" \
  --width 600 --height 250 \
  --column "Program" --column "Description" \
    "FOMM"          "Mod manager, used to handle mod archives and load order" \
    "LOOT"          "Program to organise the mod load order most effectively" \
    "FO3Edit"       "General-purpose .esp/.esm editor, used for all sorts of fixes" \
    "Merge Plugins" "Tool used to merge multiple .esp files into one")

case "$SELECTION" in
	"FOMM")
		cd "$WINEPREFIX/drive_c/Program Files/FOMM" && wine "./fomm.exe" "$@"
		;;
	"LOOT")
		cd "$WINEPREFIX/drive_c/Program Files/LOOT" && wine "./LOOT.exe" "$@"
		;;
	"FO3Edit")
		cd "$WINEPREFIX/drive_c/Program Files/FO3Edit" && wine "./FO3Edit.exe" "$@"
		;;
	"Merge Plugins")
		cd "$WINEPREFIX/drive_c/Program Files/MergePlugins" && wine "./MergePlugins.exe" "$@"
		;;
esac