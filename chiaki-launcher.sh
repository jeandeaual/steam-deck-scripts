#!/usr/bin/env bash
# Automate Chiaki's launch
# This script automatically selects the first configured console.

set -uo pipefail

readonly CHIAKI_APP_ID="re.chiaki.Chiaki4deck" # Either "re.chiaki.Chiaki" or "re.chiaki.Chiaki4deck"
readonly CHIAKI_CONF="${HOME}/.var/app/${CHIAKI_APP_ID}/config/Chiaki/Chiaki.conf"
readonly TIMEOUT_SEC=35
readonly LOGIN_PASSCODE=""
readonly MODE="fullscreen" # Can be either "fullscreen", "zoom" or "stretch"
readonly PS_CONSOLE=5 # Set to 4 or 5
readonly HOME_SSIDS=(
    "La Cantine"
    "La Cantine 5G"
)
readonly CONSOLE_INDEX=1 # Use the first registered console

remove_whitespace() {
    # Remove trailing and leading whitespace from the arguments
    local string="$*"
    # Remove leading whitespace
    string="${string#"${string%%[![:space:]]*}"}"
    # Remove trailing whitespace
    printf "%s" "${string%"${string##*[![:space:]]}"}"
}

readarray -t console_nicknames < <(grep server_nickname "${CHIAKI_CONF}" | cut -d '=' -f2-)
# shellcheck disable=SC1003
readarray -t registration_keys < <(grep regist_key "${CHIAKI_CONF}" | cut -d '(' -f2 | cut -d '\' -f1)

if [[ ${CONSOLE_INDEX} -gt ${#console_nicknames[@]} ]]; then
    echo "Error: can't get configuration for console number ${CONSOLE_INDEX} (${#console_nicknames[@]} console(s) found)" >&2
    exit 1
fi

console_nickname="$(remove_whitespace "${console_nicknames[$((CONSOLE_INDEX-1))]}")"
registration_key="${registration_keys[$((CONSOLE_INDEX-1))]}"

console_address="10.0.1.40"
if [[ ${#HOME_SSIDS[@]} -gt 0 ]]; then
    current_ssid="$(iwgetid -r)"
    # shellcheck disable=SC2076
    if [[ ! " ${HOME_SSIDS[*]} " =~ " ${current_ssid} " ]]; then
        console_address="lacantine.xyz"
    fi
fi

connect_error() {
    echo "Error: Couldn't connect to your PlayStation console!" >&2
    echo "Error: Please check that your Steam Deck and PlayStation are on the same network" >&2
    echo "Error: ...and that you have the right PlayStation IP address!" >&2
    exit 2
}

wakeup_error() {
    echo "Error: Couldn't wake up PlayStation console from sleep!" >&2
    echo "Error: Please make sure you are using the correct PlayStation ${PS_CONSOLE}." >&2
    echo "Error: If not, change the wakeup call to use the number of your PlayStation console" >&2
    exit 3
}

timeout_error() {
    echo "Error: PlayStation console didn't become ready in ${TIMEOUT_SEC} seconds!" >&2
    echo "Error: Please change ${TIMEOUT_SEC} to a higher number in your script if this persists." >&2
    exit 4
}

SECONDS=0

while :; do
    # Wait for console to be in sleep/rest mode or on (otherwise console isn't available)
    ps_status="$(flatpak run "${CHIAKI_APP_ID}" discover -h "${console_address}" 2>/dev/null)"
    if echo "${ps_status}" | grep -q 'ready\|standby'; then
        break
    fi
    if [[ ${SECONDS} -gt ${TIMEOUT_SEC} ]]; then
        connect_error
    fi
    sleep 1
done

# Wake up console from sleep/rest mode if not already awake
if ! echo "${ps_status}" | grep -q ready; then
    flatpak run "${CHIAKI_APP_ID}" wakeup -"${PS_CONSOLE}" -h "${console_address}" -r "${registration_key}" 2>/dev/null
fi

# Wait for PlayStation to report ready status, exit script on error if it never happens.
while ! echo "${ps_status}" | grep -q ready; do
    if [[ ${SECONDS} -gt ${TIMEOUT_SEC} ]]; then
        if echo "${ps_status}" | grep -q standby; then
            wakeup_error
        else
            timeout_error
        fi
    fi
    sleep 1
    ps_status="$(flatpak run "${CHIAKI_APP_ID}" discover -h "${console_address}" 2>/dev/null)"
done

# Begin playing PlayStation remote play via Chiaki
exec flatpak run "${CHIAKI_APP_ID}" ${LOGIN_PASSCODE:+--passcode ${LOGIN_PASSCODE}} --"${MODE}" stream "${console_nickname}" "${console_address}"
