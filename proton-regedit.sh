#!/usr/bin/env bash
# Start regedit in the current or provided Steam compatdata folder.

set -euo pipefail

# Get the Wine prefix from the given or current folder
wine_prefix=${1:-$(pwd | sed -E 's|^(.*steamapps/compatdata/[0-9]+/pfx).*|\1|')}

# Retrieve the Wine executables from all the Proton installations
readarray -t wine_exes < <(find "${HOME}"/.local/share/Steam/steamapps/common/Proton\ * -type f -executable -name wine)

# Use the first one found
readonly wine="${wine_exes[1]}"

# Start regedit
WINEPREFIX="${wine_prefix}" "${wine}" regedit
