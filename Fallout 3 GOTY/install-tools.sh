#!/bin/bash

PREFIX_NAME="fo3tools"
PREFIX_PATH="$XDG_DATA_HOME/wineprefixes/$PREFIX_NAME"

LOCATION_GAME=$(protontricks --command 'pwd' 22370)
LOCATION_GAME_PREFIX=$(protontricks --command 'echo $WINEPREFIX' 22370)

WINETRICKS_PARAMS="--unattended arch=32 prefix=$PREFIX_NAME mimeassoc=off"

# Mark start of script run, so that we can use the timestamp
# and remove unneeded shortcuts and icons
touch "$XDG_RUNTIME_DIR/$PREFIX_NAME-timestamp"

cat << EOF
You will need to provide installers for several tools:
 * Fallout 3 Mod Manager (FOMM)
 * Load Order Optimisation Tool (LOOT)
 * FO3Edit
 * Merge Plugins tool

Once those installers have been provided, this script will take care of
setting up the Wine prefix, linking it against the Fallout 3 GOTY Steam installation,
and creating all the required bits to have them operable.

Press [ENTER] to continue
EOF
read

if (zenity --question --title="Linking FO3 local settings" --text="Would you like to have the save directories and config in custom location?" &> /dev/null); then
    LOCATION_SETTINGS=$(zenity --file-selection --directory --title="Select location for Fallout 3 data" 2> /dev/null)
    if [ -z "$LOCATION_SETTINGS" ]; then
        echo "Need to provide valid location for Fallout 3 data!"
        exit 1
    fi
fi

INSTALLER_FOMM=$(zenity --file-selection --title="Select FOMM installer (.exe file)" --file-filter '*.exe' 2> /dev/null)
if [ -z "$INSTALLER_FOMM" ]; then
    echo "Need to provide installer for FOMM!"
    exit 1
fi

INSTALLER_LOOT=$(zenity --file-selection --title="Select LOOT installer (.exe file)" --file-filter '*.exe' 2> /dev/null)
if [ -z "$INSTALLER_LOOT" ]; then
    echo "Need to provide installer for LOOT!"
    exit 1
fi

INSTALLER_FO3EDIT=$(zenity --file-selection --title="Select FO3Edit archive (.7z file)" --file-filter '*.7z' 2> /dev/null)
if [ -z "$INSTALLER_FO3EDIT" ]; then
    echo "Need to provide archive containing FO3Edit!"
    exit 1
fi

INSTALLER_MERGE=$(zenity --file-selection --title="Select Merge Plugins archive (.zip file)" --file-filter '*.zip' 2> /dev/null)
if [ -z "$INSTALLER_MERGE" ]; then
    echo "Need to provide archive containing Merge Plugins!"
    exit 1
fi

echo "About to set up Fallout 3 tooling environment with following settings:"
if [ -n "$LOCATION_SETTINGS" ]; then echo "* Fallout 3 settings at        \"$LOCATION_SETTINGS\""; fi   
echo "* FOMM installed from          \"$INSTALLER_FOMM\""
echo "* LOOT installed from          \"$INSTALLER_LOOT\""
echo "* FO3Edit installed from       \"$INSTALLER_FO3EDIT\""
echo "* Merge Plugins installed from \"$INSTALLER_MERGE\""
echo ""
echo "Press [ENTER] to continue with the installation."
read

# ==== Moving settings to new locations ====

if [ -n "$LOCATION_SETTINGS" ]; then

    echo "Moving Fallout 3 settings and user data to new location and linking it..."

    TEMP_VAR="$LOCATION_GAME_PREFIX/drive_c/users/steamuser/My Documents/My Games/Fallout3"
    if [ -d "$TEMP_VAR" ]; then
        mv "$TEMP_VAR" "$LOCATION_SETTINGS/User Data" &&
        ln -s "$LOCATION_SETTINGS/User Data" "$TEMP_VAR"
    else
        echo "User data location is not a valid directory!"
        exit 1
    fi

    TEMP_VAR="$LOCATION_GAME_PREFIX/drive_c/users/steamuser/Local Settings/Application Data/Fallout3"
    if [ -d "$TEMP_VAR" ]; then
        mv "$TEMP_VAR" "$LOCATION_SETTINGS/Local Settings"
        ln -s "$LOCATION_SETTINGS/Local Settings" "$TEMP_VAR"
    else
        echo "Local settings location is not a valid directory!"
        exit 1
    fi

    mkdir "$LOCATION_SETTINGS/Mods"
    mkdir "$LOCATION_SETTINGS/Install Info"

fi

# ==== Creating the prefix ====

echo "Setting up Wine prefix for tooling (install Wine Gecko when prompted)..." &&
WINEDLLOVERRIDES=mscoree=d winetricks $WINETRICKS_PARAMS isolate_home &&

export WINEARCH=win32 &&
export WINEPREFIX="$PREFIX_PATH" &&
export WINEDEBUG="-all" &&
echo "Installing .NET 4.0..." &&
winetricks $WINETRICKS_PARAMS dotnet40 &&

echo "Linking relevant directories..." &&
mkdir -p "$PREFIX_PATH/drive_c/users/$USER/Local Settings/Application Data" \
         "$PREFIX_PATH/drive_c/users/$USER/My Documents/My Games" &&
rmdir "$PREFIX_PATH/drive_c/users/$USER/Downloads" &&
ln -s "~/Downloads" "$PREFIX_PATH/drive_c/users/$USER/Downloads" &&
ln -s "$LOCATION_GAME" "$PREFIX_PATH/drive_c/Program Files/Fallout 3"

if [ -n "$LOCATION_SETTINGS" ]; then
    ln -s "$LOCATION_SETTINGS/Local Settings" \
          "$PREFIX_PATH/drive_c/users/$USER/Local Settings/Application Data/Fallout3" &&
    ln -s "$LOCATION_SETTINGS/User Data" \
          "$PREFIX_PATH/drive_c/users/$USER/My Documents/My Games/Fallout3" &&
    ln -s "$LOCATION_SETTINGS/Mods" "$LOCATION_GAME/Mods" &&
    ln -s "$LOCATION_SETTINGS/Install Info" "$LOCATION_GAME/Install Info"
else
    ln -s "$LOCATION_GAME_PREFIX/drive_c/users/steamuser/Local Settings/Application Data/Fallout3" \
          "$PREFIX_PATH/drive_c/users/$USER/Local Settings/Application Data/Fallout3" &&
    ln -s "$LOCATION_GAME_PREFIX/drive_c/users/steamuser/My Documents/My Games/Fallout3" \
          "$PREFIX_PATH/drive_c/users/$USER/My Documents/My Games/Fallout3"
fi

# ==== Installing toolkit ====

echo "Installing FOMM..." &&
WINEPREFIX="$PREFIX_PATH" wine "$INSTALLER_FOMM" /SILENT &&

echo "Installing LOOT..." &&
WINEPREFIX="$PREFIX_PATH" wine "$INSTALLER_LOOT" /SILENT &&

echo "Installing FO3Edit..." &&
mkdir -p "$PREFIX_PATH/drive_c/Program Files/FO3Edit" &&
7z x -o"$PREFIX_PATH/drive_c/Program Files/FO3Edit" "$INSTALLER_FO3EDIT" > /dev/null &&
chmod -R u-rwx+rwX,g-rwx+rX,o-rwx+rX "$PREFIX_PATH/drive_c/Program Files/FO3Edit"

echo "Installing Merge Plugins..." &&
mkdir -p "$PREFIX_PATH/drive_c/Program Files/MergePlugins" &&
unzip "$INSTALLER_MERGE" -d "$PREFIX_PATH/drive_c/Program Files/MergePlugins" > /dev/null &&
chmod -R u-rwx+rwX,g-rwx+rX,o-rwx+rX "$PREFIX_PATH/drive_c/Program Files/MergePlugins"

echo "Removing unneeded menu shortcuts..." &&
find ~/.local/share/applications -type f -newer "$XDG_RUNTIME_DIR/$PREFIX_NAME-timestamp" -delete &&
find ~/.local/share/applications -mindepth 1 -type d -depth -exec rmdir {} \; 2> /dev/null &&
find ~/.local/share/icons -type f -newer "$XDG_RUNTIME_DIR/$PREFIX_NAME-timestamp" -delete &&
find ~/.local/share/icons -mindepth 1 -type d -depth -exec rmdir {} \; 2> /dev/null &&
rm "$XDG_RUNTIME_DIR/$PREFIX_NAME-timestamp"

# ==== Configuring toolkit ====

echo "Configuring toolkit..." &&
cat > "$PREFIX_PATH/drive_c/fallout-location.reg" << EOF
REGEDIT4

[HKEY_LOCAL_MACHINE\Software\Bethesda Softworks\Fallout3]
"Installed Path"="C:\\\\Program Files\\\\Fallout 3"

[HKEY_LOCAL_MACHINE\Software\Wow6432Node\Bethesda Softworks\Fallout3]
"Installed Path"="C:\\\\Program Files\\\\Fallout 3"
EOF
WINEPREFIX="$PREFIX_PATH" wine regedit "$PREFIX_PATH/drive_c/fallout-location.reg" &&
rm "$PREFIX_PATH/drive_c/fallout-location.reg"

echo "Installing toolkit launcher..." &&
cat "$(dirname "$0")/launcher.sh" | sed 's,prefix-placeholder,'"$PREFIX_PATH"',' > "$PREFIX_PATH/drive_c/launcher.sh" &&
chmod +x "$PREFIX_PATH/drive_c/launcher.sh"

LAUNCHER_PATH="$PREFIX_PATH/drive_c/launcher.sh"
cat > "$HOME/.local/share/applications/$PREFIX_NAME.desktop" << EOF
[Desktop Entry]
Name=Fallout 3 Toolkit
Exec=${LAUNCHER_PATH// /\\\\ }
Type=Application
StartupNotify=false
Icon=emblem-system
Categories=Game
Keywords=fallout;fo3;fomm;fo3edit;loot;merge
EOF
xdg-desktop-menu forceupdate

echo "" && echo "Fallout 3 Toolkit has been successfully installed!"