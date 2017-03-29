#!/bin/bash

#
# Determine platform and then open build settings file appropriately.
# $1 = The path to the project folder (Eclipse-formatted in OS-specific path nomenclature)
# $2 = Name of the build settings file
#

function realpath {
    local p=$(cd "$1" && echo "$PWD")
    
    echo "${p}"
}

localScriptDir="${0%/*}"

# Verify that path to project directory was passed in and is valid.
if (( $# != 2 )); then
    echo "Incorrect number of incoming parameters; expected path to project directory and name of build settings file."
    echo "Exiting script."
    exit 1
fi

buildSettingsDir="$1"
buildSettingsFile="$2"

# If using Windows, generate Windows-friendly path name for display purposes and insure the actual path is in Cygwin format.
if [[ "$(uname -s)" == CYGWIN* ]]; then
    buildSettingsDir=$(cygpath -u "${buildSettingsDir}")
    buildSettings="${buildSettingsDir}/${buildSettingsFile}"
    buildSettingsDisplay=$(cygpath -w "${buildSettings}")
else
    buildSettings="${buildSettingsDir}/${buildSettingsFile}"
    buildSettingsDisplay=$buildSettings
fi

if [[ ! -d "${buildSettingsDir}" ]]; then
    echo "The build settings (project) directory '${buildSettingsDir}' does not exist. Exiting script."
    exit 1
fi

# Create a build settings file, if it doesn't already exist, defaulting the local source code path to the passed-in directory.
if [[ ! -f "${buildSettings}" ]]; then
    echo "No build settings file exists at '${buildSettingsDisplay}'."
    echo "(Perhaps this is the first run?)"
    echo "Created new settings file with default values."
    sed -e "s|^\(localSourceDir\)=.*|\1=\"${buildSettingsDir}/\"|" ./buildsettings.sh.dist > "${buildSettings}"

	# Add .buildsettings file to .gitignore, if .gitignore already exists.
	if [[ -f "${buildSettingsDir}/.gitignore" ]]; then
		if ! grep -q "${buildSettingsFile}" "${buildSettingsDir}/.gitignore"; then
			echo "${buildSettingsFile}" >> "${buildSettingsDir}/.gitignore"
			echo "'${buildSettingsFile}' added to .gitignore."
		fi
	fi
fi

# Record hash of settings file to later see if something changed.
settingsHash=$(openssl sha1 "${buildSettings}")

# Since we're likely called in the background from an editor, open the settings file in a new window (this part is OS-specific)
case "$(uname -s)" in
    Darwin)
        echo "Launching Build Settings editor.  Please set values to fit your environment, then press control-x, 'y', Enter to save and exit."
        sed -e "s|^buildSettings=.*|buildSettings=\"${buildSettings}\"|" "Launch Nano.sh" >"/tmp/Launch Nano.sh"
        chmod +x "/tmp/Launch Nano.sh"
        open -a Terminal.app "/tmp/Launch Nano.sh"
        while [[ -f "/tmp/Launch Nano.sh" ]]; do
            sleep .1
        done
        ;;
    
    CYGWIN*)
        if [[ -d /cygdrive/c/cygwin64 ]]; then
            cygwin='cygwin64'
        elif [[ -d /cygdrive/c/cygwin ]]; then
            cygwin='cygwin'
        else
            echo 'Cygwin directory not found (neither C:\cygwin or C:\cygwin64). Exiting script.'
            exit 1
        fi
        
        echo "Launching Build Settings editor.  Please set values to fit your environment, then press control-x, 'y', Enter to save and exit."
        /cygdrive/c/Windows/System32/cmd.exe /C "start /WAIT C:\\${cygwin}\bin\nano.exe '${buildSettingsDisplay}'"
        ;;
    *)
        echo "Support for this OS hasn't yet been implemented."
        ;;
esac

# Note if settings actually changed.
newSettingsHash=$(openssl sha1 "${buildSettings}")
echo
if [[ "${settingsHash}" != "${newSettingsHash}" ]]; then
    echo "New settings detected!"
else
    echo "No settings were changed."
fi
