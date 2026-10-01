#!/usr/bin/env sh
# Install the published mkok.sh test harness into a user-selected prefix.

# Stop on command errors (-e), treat unset variables as errors (-u), and disable
# pathname expansion (-f). These options make failures in setup/download visible
# rather than silently continuing with an incomplete installation.
set -euf

# PREFIX is overridable by the caller; the default keeps installation local to
# the current user's home directory. DEST is the final library location, and URL
# points to the upstream master branch's raw source file.
PREFIX="${PREFIX:-$HOME/.local}"
DEST="$PREFIX/lib/mkok.sh"
URL="https://raw.githubusercontent.com/wakodiwe/mkok.sh/master/src/mkok.sh"

# Ensure the destination directory exists before downloading. curl fails on
# HTTP errors (-f), follows redirects (-L), stays quiet except for errors (-s),
# and writes the downloaded content directly to DEST (-o).
mkdir -p "$(dirname "$DEST")"
curl -fsSL "$URL" -o "$DEST"

# Make the installed source readable by owner/group/others and writable only by
# its owner. This does not set an executable bit because the file is intended to
# be sourced by shell test scripts.
chmod 644 "$DEST"

# Print the exact install location and a shell-source usage hint.
printf "Installed to %s\n" "$DEST"
printf "Usage: . %s\n" "$DEST"
