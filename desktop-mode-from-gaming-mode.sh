#!/bin/bash
# Run Steam Deck desktop mode in gaming mode.
# See https://gist.github.com/davidedmundson/8e1732b2c8b539fd3e6ab41a65bcab74.

set -euo pipefail

if [[ -z "${GAMESCOPE_WAYLAND_DISPLAY:-}" ]]; then
    zenity --error --text="This script can only be run in a gamescope session." --width 400
    exit 1
fi

# Remove the performance overlay, it meddles with some tasks
unset LD_PRELOAD

# Shadow kwin_wayland_wrapper so that we can pass args to the kwin wrapper
# while being launched by plasma-session
mkdir -p "${XDG_RUNTIME_DIR}/nested_plasma"

display_resolution="$(xdpyinfo | awk '/dimensions/ {print $2}')"

cat <<EOF > "${XDG_RUNTIME_DIR}/nested_plasma/kwin_wayland_wrapper"
#!/bin/sh
/usr/bin/kwin_wayland_wrapper --width "${display_resolution%x*}" --height "${display_resolution#*x}" --no-lockscreen \$@
EOF

cleanup() {
    rm "${XDG_RUNTIME_DIR}/nested_plasma/kwin_wayland_wrapper"
}
trap cleanup EXIT

chmod a+x "${XDG_RUNTIME_DIR}/nested_plasma/kwin_wayland_wrapper"

export PATH="${XDG_RUNTIME_DIR}/nested_plasma${PATH:+:${PATH}}"

dbus-run-session startplasma-wayland
