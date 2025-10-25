#!/bin/bash
# Fix Debian Buster EOL issue in a toolchain Dockerfile
# Debian Buster reached EOL and repositories moved to archive.debian.org

if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-Dockerfile>"
    exit 1
fi

DOCKERFILE="$1"

if [ ! -f "$DOCKERFILE" ]; then
    echo "Error: Dockerfile not found: $DOCKERFILE"
    exit 1
fi

echo "Patching Dockerfile: $DOCKERFILE"

# Check if it's using Debian Buster
if ! grep -q "FROM debian:buster" "$DOCKERFILE"; then
    echo "  Not a Debian Buster Dockerfile, skipping"
    exit 0
fi

# Check if already patched
if grep -q "archive.debian.org" "$DOCKERFILE"; then
    echo "  Already patched for archive.debian.org, skipping"
    exit 0
fi

# Fix ENV format if needed (old format)
sed -i.bak 's/^ENV DEBIAN_FRONTEND noninteractive$/ENV DEBIAN_FRONTEND=noninteractive/' "$DOCKERFILE"

# Insert archive.debian.org fix after the FROM and ENV lines
# This uses awk to insert the fix in the right place
awk '
/^FROM debian:buster/ {
    print
    getline
    # Print the ENV line (should be DEBIAN_FRONTEND)
    print
    print ""
    print "# Debian Buster is EOL - use archive repositories"
    print "RUN sed -i \"s/deb.debian.org/archive.debian.org/g\" /etc/apt/sources.list && \\"
    print "    sed -i \"s|security.debian.org|archive.debian.org|g\" /etc/apt/sources.list && \\"
    print "    sed -i \"/buster-updates/d\" /etc/apt/sources.list && \\"
    print "    apt-get update -o Acquire::Check-Valid-Until=false"
    next
}

# Add -o Acquire::Check-Valid-Until=false to apt-get update commands
/apt-get.*update/ && !/Check-Valid-Until/ {
    sub(/apt-get -y update/, "apt-get -y update -o Acquire::Check-Valid-Until=false")
}

{ print }
' "$DOCKERFILE" > "$DOCKERFILE.tmp"

mv "$DOCKERFILE.tmp" "$DOCKERFILE"

# Remove backup file
rm -f "$DOCKERFILE.bak"

echo "  ✓ Patched to use Debian Buster archive repositories"
