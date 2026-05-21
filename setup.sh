#!/bin/bash
# Acer Predator PHN16S-71 — machine-specific setup
# Downloads and installs DAMX + linuwu-sense from GitHub. No Omarchy needed.
# Run once after mycachy install.sh, then reboot.
# NOT part of the mycachy repo — this laptop only.

set -e

DAMX_REPO="PXDiv/Div-Acer-Manager-Max"
INSTALL_DIR="/opt/damx"
BIN_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"

# ── Privileges ────────────────────────────────────────────────────────────────
if [[ "$EUID" -ne 0 ]]; then
  echo "Re-running with sudo..."
  exec sudo bash "$0" "$@"
fi

# ── Kernel headers (needed to build linuwu-sense) ─────────────────────────────
echo "==> Installing kernel headers..."
pacman -S --needed --noconfirm linux-cachyos-headers base-devel

# ── Download latest DAMX release ──────────────────────────────────────────────
echo "==> Fetching latest DAMX release..."
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$DAMX_REPO/releases/latest" \
  | grep "browser_download_url" | grep "\.tar\.xz\"" | grep -v sha256 \
  | sed 's/.*"\(https[^"]*\)".*/\1/')

if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "ERROR: Could not fetch DAMX release URL from GitHub."
  exit 1
fi

echo "    URL: $DOWNLOAD_URL"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

curl -L "$DOWNLOAD_URL" | tar -xJ -C "$TMPDIR" --strip-components=1

# ── Build and install linuwu-sense driver ────────────────────────────────────
echo "==> Building linuwu-sense kernel driver..."
cd "$TMPDIR/Linuwu-Sense"
make clean
make
make install
cd "$TMPDIR"

echo "==> Writing modprobe config (predator_v4=1 — required for PHN16S)..."
echo "options linuwu_sense predator_v4=1" > /etc/modprobe.d/linuwu-sense.conf

echo "==> Writing modules-load config..."
echo "linuwu_sense" > /etc/modules-load.d/linuwu_sense.conf

# ── Install DAMX daemon ───────────────────────────────────────────────────────
echo "==> Installing DAMX daemon..."
mkdir -p "$INSTALL_DIR/daemon"
cp -f "$TMPDIR/DAMX-Daemon/DAMX-Daemon" "$INSTALL_DIR/daemon/DAMX-Daemon"
chmod +x "$INSTALL_DIR/daemon/DAMX-Daemon"

mkdir -p /etc/DAMX_Daemon
cat > /etc/DAMX_Daemon/config.ini << 'EOF'
[General]
loglevel = INFO
autodetectfeatures = True
EOF

cat > "$SYSTEMD_DIR/damx-daemon.service" << 'EOF'
[Unit]
Description=DAMX Daemon for Acer laptops
After=network.target

[Service]
Type=simple
ExecStart=/opt/damx/daemon/DAMX-Daemon
Restart=on-failure
RestartSec=5
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# ── Install linuwu-sense service (unloads cleanly at shutdown) ────────────────
cat > "$SYSTEMD_DIR/linuwu_sense.service" << 'EOF'
[Unit]
Description=Unload linuwu_sense at shutdown

[Service]
Type=oneshot
RemainAfterExit=true
ExecStop=/sbin/rmmod linuwu_sense

[Install]
WantedBy=multi-user.target
EOF

# ── Install DAMX GUI ──────────────────────────────────────────────────────────
echo "==> Installing DAMX GUI..."
mkdir -p "$INSTALL_DIR/gui"
cp -rf "$TMPDIR/DAMX-GUI/"* "$INSTALL_DIR/gui/"
chmod +x "$INSTALL_DIR/gui/DivAcerManagerMax"

mkdir -p /usr/share/icons/hicolor/256x256/apps
cp -f "$TMPDIR/DAMX-GUI/icon.png" /usr/share/icons/hicolor/256x256/apps/damx.png

cat > /usr/share/applications/damx.desktop << 'EOF'
[Desktop Entry]
Name=DAMX
Comment=Div Acer Manager Max
Exec=/opt/damx/gui/DivAcerManagerMax
Icon=damx
Terminal=false
Type=Application
Categories=Utility;System;
Keywords=acer;laptop;system;
EOF

cat > "$BIN_DIR/DAMX" << 'EOF'
#!/bin/bash
/opt/damx/gui/DivAcerManagerMax "$@"
EOF
chmod +x "$BIN_DIR/DAMX"

# ── Enable services ───────────────────────────────────────────────────────────
echo "==> Enabling services..."
systemctl daemon-reload
systemctl enable --now damx-daemon linuwu_sense

echo "==> Loading linuwu_sense module now (no reboot needed for first use)..."
modprobe linuwu_sense predator_v4=1 2>/dev/null || true

# ── IBT crash fix ─────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  IMPORTANT: IBT kernel parameter"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  This laptop requires 'ibt=off' in kernel parameters"
echo "  or it will crash. Add it to your bootloader config:"
echo ""
echo "  /boot/loader/entries/*.conf  (systemd-boot)"
echo "  /etc/default/grub            (GRUB)"
echo "  /boot/limine.conf            (Limine)"
echo ""
echo "  Add 'ibt=off' to the kernel options line, then"
echo "  regenerate your bootloader config and reboot."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Done. DAMX is running. Test with:"
echo "  damx-cycle          # cycle thermal profile"
echo "  damx-waybar         # show current profile + temps"
echo "  DAMX                # open GUI"
echo ""
echo "NOTE: Only 'low-power' and 'balanced' profiles work on BIOS V1.26."
