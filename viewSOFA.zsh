#!/bin/zsh

#region Comments
# ==============================================================================
# viewSOFA.zsh
# ==============================================================================
#   Created By:
#       Busy Bread
# 
#   Description:    
#       This script uses the MacAdmins Simple Organized Feed for Apple Software 
#       Updates (SOFA)[https://github.com/macadmins/sofa] repo to present the
#       data via a swfitDialog UI
#
#   Requirements:
#       - swiftDialog 2+ or higher
#endregion Comments

#region Parameters / Variables
# Script Parameters
forceCheck=${1:-false}
deleteOldData=${2:-false}

# Script Variables
scriptName=${$(basename $0)%.zsh}
scriptVersion="1.0.0"
currentUser="$(scutil <<< "show State:/Users/ConsoleUser" | awk '/Name :/ && ! /loginwindow/ { print $3 }')"

# Dialog Variables
dialogWidth=600
dialogHeight=850
dialogHelpMessage="$(curl --silent --show-error https://raw.githubusercontent.com/macadmins/sofa/main/README.md | grep "\*\*SOFA\*\*").\n\n\n\n This script provides a user-interface via swiftDialog."
dialogMessage=""

# SOFT Variables
softRootDir="/Users/${currentUser}/Library/Application Support/SOFA"
softLog="${softRootDir}/${scriptName}.log"
sofaHistory="${softRootDir}/history"
softUrlRoot="https://sofa.macadmins.io"
softIcon="${softUrlRoot}/custom_logo.png"
#endregion Parameters / Variables

#region Functions
function logMessage() {
    print "[$(date +"%Y-%m-%d %H:%M:%S")] ${1}" | tee -a "${softLog}"
}
#endregion Functions

#region Main

#region Logging / Setup
# Create SOFT directories if needed
if [[ ! -f $softRootDir ]]; then mkdir -p "${softRootDir}"; fi
if [[ ! -f $softLog ]]; then touch "${softLog}"; fi
if [[ ! -f $sofaHistory ]]; then touch "${sofaHistory}"; fi

trap "logMessage \"#################### END ####################\"" EXIT
logMessage "#################### START ####################"
logMessage "Running the ${scriptName} script for ${currentUser} ..."
logMessage "Files will be written to \"${softRootDir}\""
#endregion Logging / Setup

#region Check for swiftDialog
if [[ ! -f /usr/local/bin/dialog ]]; then
    logMessage "swiftDialog is required and is not installed !!!"
    exit 1
fi

if [[ ! $(/usr/local/bin/dialog --version) =~ '^2\.' ]]; then
    logMessage "swiftDialog version 2+ or higher is required !!!"
    exit 2
fi
#endregion Check for swiftDialog

#region Query SOFA
for product in macos ios; do
    logMessage "Processing ${product} updates ..."
    currentData="${softRootDir}/$(date +%Y-%m-%d)_${product}_data.plist"
    currentURL="${softUrlRoot}/v1/${product}_data_feed.json"
    
    if [[ ! -f "${currentData}" ]] || [[ $forceCheck == true ]]; then
        if $deleteOldData; then print "Deleting previous data ..."; rm -f "${softRootDir}/*plist"; fi
        logMessage "Fetching data from ${currentURL} ..."
        /usr/bin/plutil -convert xml1 -o "${currentData}" - <<< "$(curl --silent --show-error "${currentURL}")"
        logMessage "Succesfully fetched data !!!"
    else
        logMessage "Up to date ${product} data detected, no need to fetch updated information."
    fi

    for (( i=0 ; i < 10 ; i++ )); do
        if /usr/libexec/PlistBuddy -c "Print OSVersions:${i}" "${currentData}" &> /dev/null; then
            if [[ $product == "macos" ]]; then
                osName=$(/usr/libexec/PlistBuddy -c "Print OSVersions:${i}:OSVersion" "${currentData}" | tr -d "[0-9]" | tr -d " ")
                productName="macOS"
            else
                osName=$(/usr/libexec/PlistBuddy -c "Print OSVersions:${i}:OSVersion" "${currentData}")
                productName="iOS"
            fi
    
            osProductVersion=$(/usr/libexec/PlistBuddy -c "Print OSVersions:${i}:Latest:ProductVersion" "${currentData}")
            osBuildVersion=$(/usr/libexec/PlistBuddy -c "Print OSVersions:${i}:Latest:Build" "${currentData}")
            osReleaseDate=$(/usr/libexec/PlistBuddy -c "Print OSVersions:${i}:Latest:ReleaseDate" "${currentData}" | sed 's/T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z//g')

            osLastVersion=$(awk -F' : ' '/'${(L)osName}'/{print $NF}' "${sofaHistory}")

            if [[ -z $osLastVersion ]]; then
                print "${(L)osName} : ${osProductVersion}" >> "${sofaHistory}"
            else
                if [[ "${osProductVersion}" != "${osLastVersion}" ]]; then
                    logMessage "Newer update found for ${(C)osName}! Updating from \"${osLastVersion}\" to \"${osProductVersion}\"."
                    sed 's/'${osLastVersion}'/'${osProductVersion}'/' "${sofaHistory}" | tee "${sofaHistory}" 1> /dev/null
                fi
            fi

            dialogMessage+="## ${productName} ${osName}\n\nLatest Version: **${osProductVersion} (${osBuildVersion})**\n\nRelease Date: **${osReleaseDate}**\n\n"
        else
            break
        fi
    done
done
#endregion Query SOFA

#region Display dialog
if [[ $loadOSIcons == true ]]; then
    dialogWidth=1000
    dialogHeight=1000
fi

/usr/local/bin/dialog \
--moveable \
--ontop \
--width "${dialogWidth}" \
--height "${dialogHeight}" \
--infotext "${scriptVersion}" \
--icon "${softIcon}" \
--iconsize 200 \
--title "SOFA" \
--message "${dialogMessage}" \
--messageposition center \
--messagealignment left \
--helpmessage "${dialogHelpMessage}"
#endregion Display dialog

#endregion Main
