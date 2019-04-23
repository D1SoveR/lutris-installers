#!/bin/bash

PREFIX_GAME=$(protontricks --command 'echo $WINEPREFIX' 22370)
PREFIX_FOMM="$XDG_DATA_HOME/wineprefixes/fomm"

echo "Press [ENTER], then select FOMM installer.\n"
FOMM_INSTALLER=$(zenity --file-selection 2> /dev/null)

if [ -z $FOMM_INSTALLER ]; then
	echo "Need to provide installer for FOMM!"
	exit 1
fi

echo "Setting up FOMM-specific Wine prefix..." &&
WINEDLLOVERRIDES=mscoree=d winetricks --unattended arch=32 prefix=fomm mimeassoc=off isolate_home &&

export WINEARCH=win32 &&
export WINEPREFIX="$PREFIX_FOMM" &&
export WINEDEBUG="-all" &&
echo "Installing .NET 4.0..." &&
winetricks --unattended arch=32 prefix=fomm dotnet40 &&

echo "Linking relevant directories..." &&
mkdir -p "$PREFIX_FOMM/drive_c/users/$USER/Local Settings/Application Data" \
         "$PREFIX_FOMM/drive_c/users/$USER/My Documents/My Games" &&
ln -s "$PREFIX_GAME/drive_c/users/steamuser/Local Settings/Application Data/Fallout3" \
      "$PREFIX_FOMM/drive_c/users/$USER/Local Settings/Application Data/Fallout3" &&
ln -s "$PREFIX_GAME/drive_c/users/steamuser/My Documents/My Games/Fallout3" \
      "$PREFIX_FOMM/drive_c/users/$USER/My Documents/My Games/Fallout3" &&

echo "Installing FOMM..." &&
cp "$FOMM_INSTALLER" "$PREFIX_FOMM/drive_c/FOMM-installer.exe" &&
WINEPREFIX="$PREFIX_FOMM" wine "$PREFIX_FOMM/drive_c/FOMM-installer.exe" /SILENT &&

echo "Cleaning up..." &&

GAME_LOCATION=$(WINEPREFIX="$PREFIX_FOMM" winepath -w "$(protontricks --command pwd 22370)")
cat > "$PREFIX_FOMM/drive_c/fallout-location.reg" << EOF
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Bethesda Softworks\Fallout3]
"Installed Path"="${GAME_LOCATION//\\/\\\\}"

[HKEY_LOCAL_MACHINE\Software\Wow6432Node\Bethesda Softworks\Fallout3]
"Installed Path"="${GAME_LOCATION//\\/\\\\}"
EOF
WINEPREFIX="$PREFIX_FOMM" wine regedit "$PREFIX_FOMM/drive_c/fallout-location.reg"

mv "$(find "$XDG_DATA_HOME/applications" -type f -name "FOMM.desktop")" "$XDG_DATA_HOME/applications" &&
rm -rf "$XDG_DATA_HOME/applications/wine" &&
sed -i'' 's/Name=FOMM/Name=Fallout 3 Mod Manager/' "$XDG_DATA_HOME/applications/FOMM.desktop" &&
echo "Categories=Game;Utility;" >> "$XDG_DATA_HOME/applications/FOMM.desktop" &&
xdg-desktop-menu forceupdate &&
echo "" && echo "FOMM has been successfully installed!"