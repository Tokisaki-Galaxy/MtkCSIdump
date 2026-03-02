#!/bin/sh
# install_modules.sh — Safe mt76 kernel module installer for OpenWrt
#
# Instead of overwriting system-provided modules, this script copies the
# patched .ko files into the  extra/  sub-directory of the running kernel's
# module tree.  The standard Linux module loader (depmod / modprobe) searches
# extra/ BEFORE the built-in kernel/ directory, so the patched modules are
# loaded in preference to the originals — without touching the original files.
#
# If anything goes wrong you can simply run:
#   sh install_modules.sh --restore
# to remove the overrides and reload the system originals.
#
# Usage:
#   sh install_modules.sh             — install patched modules
#   sh install_modules.sh --restore   — remove overrides, restore originals
#   sh install_modules.sh --status    — show what is currently installed
#
# Requirements: busybox sh, depmod, modprobe (standard on OpenWrt)

set -e

KERNEL_VER=$(uname -r)
MODULE_DIR="/lib/modules/${KERNEL_VER}"
EXTRA_DIR="${MODULE_DIR}/extra"
MARKER="${EXTRA_DIR}/.csidump-installed"

# Resolve the directory containing this script (and the .ko files).
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── helpers ───────────────────────────────────────────────────────────────────
die() { echo "ERROR: $*" >&2; exit 1; }

check_root() {
    [ "$(id -u)" -eq 0 ] || die "This script must be run as root."
}

have_ko_files() {
    ls "${SCRIPT_DIR}"/*.ko >/dev/null 2>&1
}

# ── status mode ───────────────────────────────────────────────────────────────
if [ "$1" = "--status" ]; then
    echo "Kernel : ${KERNEL_VER}"
    echo "Extra  : ${EXTRA_DIR}"
    if [ -f "${MARKER}" ]; then
        echo "Status : CSIdump modules are INSTALLED"
        echo ""
        echo "Installed modules:"
        ls -lh "${EXTRA_DIR}"/*.ko 2>/dev/null | awk '{print "  " $NF, $5}'
    else
        echo "Status : not installed (extra/ override not present)"
    fi
    exit 0
fi

# ── restore mode ──────────────────────────────────────────────────────────────
if [ "$1" = "--restore" ]; then
    check_root
    echo "Removing CSIdump module overrides..."
    if [ ! -f "${MARKER}" ]; then
        echo "Nothing to restore (marker not found at ${MARKER})."
        exit 0
    fi

    # Remove installed .ko overrides
    # shellcheck disable=SC2046
    rm -f $(cat "${MARKER}")
    rm -f "${MARKER}"

    # Remove the extra/ directory if it is now empty
    rmdir "${EXTRA_DIR}" 2>/dev/null || true

    depmod -a
    echo ""
    echo "Done.  The original system modules will be used on next modprobe/reboot."
    echo "Reboot (or run 'modprobe -r <module> && modprobe <module>') to apply."
    exit 0
fi

# ── install mode ──────────────────────────────────────────────────────────────
check_root
have_ko_files || die "No .ko files found in ${SCRIPT_DIR}/"

echo "Installing CSIdump mt76 kernel modules"
echo "  Kernel  : ${KERNEL_VER}"
echo "  Source  : ${SCRIPT_DIR}"
echo "  Dest    : ${EXTRA_DIR}"
echo ""

mkdir -p "${EXTRA_DIR}"

# Track which files we install so --restore can clean up precisely.
INSTALLED_FILES=""

for ko in "${SCRIPT_DIR}"/*.ko; do
    [ -f "$ko" ] || continue
    name=$(basename "$ko")
    dest="${EXTRA_DIR}/${name}"

    cp "$ko" "$dest"
    echo "  Installed: ${name}"
    INSTALLED_FILES="${INSTALLED_FILES} ${dest}"
done

# Write the manifest for --restore
# shellcheck disable=SC2086
echo ${INSTALLED_FILES} | tr ' ' '\n' | grep -v '^$' > "${MARKER}"

echo ""
echo "Updating module dependency database..."
depmod -a

echo ""
echo "Installation complete."
echo ""
echo "Note: The original system modules in ${MODULE_DIR}/ were NOT modified."
echo "      The new modules in ${EXTRA_DIR}/ take priority automatically."
echo ""
echo "Please reboot (or reload the modules) to activate the patched drivers."
echo ""
echo "To uninstall at any time, run:"
echo "  sh $(basename "$0") --restore"
