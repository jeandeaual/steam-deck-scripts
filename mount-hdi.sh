#!/usr/bin/env bash
# Mount a PC-98 hard disk image in HDI format.
# https://github.com/drojaazu/pc98_disks_in_linux

set -uo pipefail

if [[ "$#" -lt 1 ]]; then
    echo "At least one HDI file in required" >&2
    exit 1
fi

mount_image() {
    readonly image=$1

    # Look for the start of the first partition
    local offset=$(( $(grep -Ebaom 1 'FAT1[2|6]' "${image}" | sed -E 's/:FAT1[2|6]//g') - 54 ))
    local basename
    basename="$(basename "${image%.*}")"

    device="$(sudo losetup --show -fL -o "${offset}" "${image}")"
    echo "${image} is setup on ${device}"

    readonly mount_path="/run/media/${USER}/${basename}"

    if [[ ! -d "${mount_path}" ]]; then
        mkdir -p "${mount_path}"
    fi

    sudo mount "${device}" "${mount_path}"

    echo "${image} mounted on ${mount_path}"
}

for image in "$@"; do
    mount_image "${image}"
done
