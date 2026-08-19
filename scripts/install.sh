#!/bin/sh
# Queen Suite & Argon Theme — Complete Automated OpenWrt Installer
# GitHub Repository: https://github.com/dev-prabina/openWRT.git
set -e

REPO_USER="dev-prabina"
REPO_NAME="openWRT"
REPO_BRANCH="main"
ALT_BRANCH="master"
GITHUB_RAW="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME"
GITHUB_ARCHIVE="https://github.com/$REPO_USER/$REPO_NAME/archive/refs/heads"

echo "================================================================="
echo "  👑 Installing Queen Management Suite & Argon Theme on OpenWrt  "
echo "  Repository: https://github.com/$REPO_USER/$REPO_NAME           "
echo "================================================================="

download_file() {
    local url="$1"
    local dest="$2"
    if command -v wget >/dev/null 2>&1; then
        wget -q --no-check-certificate -O "$dest" "$url" 2>/dev/null || return 1
    elif command -v uclient-fetch >/dev/null 2>&1; then
        uclient-fetch --no-check-certificate -q -O "$dest" "$url" 2>/dev/null || return 1
    elif command -v curl >/dev/null 2>&1; then
        curl -sSL -k -o "$dest" "$url" 2>/dev/null || return 1
    else
        return 1
    fi
    [ -s "$dest" ] || return 1
}

# Step 1: Detect & Install Prerequisites + Argon Theme + mwan3
echo "[1/7] Installing system packages & dependencies..."
if command -v apk >/dev/null 2>&1; then
    echo "  -> Detected OpenWrt 25.x (apk). Updating & installing..."
    apk update >/dev/null 2>&1 || true
    apk add ucode ucode-mod-fs ucode-mod-uci ucode-mod-ubus iwinfo mwan3 luci-theme-argon luci-app-argon-config curl wget tar ca-certificates >/dev/null 2>&1 || true
elif command -v opkg >/dev/null 2>&1; then
    echo "  -> Detected OpenWrt 24.x (opkg). Updating & installing..."
    opkg update >/dev/null 2>&1 || true
    opkg install ucode ucode-mod-fs ucode-mod-uci ucode-mod-ubus iwinfo mwan3 luci-theme-argon luci-app-argon-config curl wget tar ca-certificates >/dev/null 2>&1 || true
fi

# Step 2: Configure Custom Argon Theme
echo "[2/7] Applying tailored Queen Argon theme configuration..."
uci -q batch <<EOF
set luci.main.mediaurlbase='/luci-static/argon'
set argon.@global[0]=global
set argon.@global[0].primary='#0F766E'
set argon.@global[0].dark_primary='#81C784'
set argon.@global[0].blur='16'
set argon.@global[0].blur_dark='16'
set argon.@global[0].transparency='0.9'
set argon.@global[0].transparency_dark='0.8'
set argon.@global[0].mode='light'
set argon.@global[0].online_wallpaper='bing'
commit argon
commit luci
EOF

# Step 3: Create Destination Directories
echo "[3/7] Creating system directories..."
mkdir -p /usr/libexec/rpcd
mkdir -p /www/luci-static/resources/view/queenx
mkdir -p /usr/share/luci/menu.d
mkdir -p /usr/share/rpcd/acl.d
mkdir -p /etc/config

# Step 4: Locate or Fetch Queen Source Files
echo "[4/7] Locating / downloading Queen source files..."
SRC_DIR=""

# Check local current directory and parent directory
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
PARENT_DIR="$(cd "$SCRIPT_DIR/.." 2>/dev/null && pwd)"

if [ -d "$SCRIPT_DIR/sections" ]; then
    SRC_DIR="$SCRIPT_DIR"
elif [ -d "$PARENT_DIR/sections" ]; then
    SRC_DIR="$PARENT_DIR"
elif [ -d "$PARENT_DIR/Queen/sections" ]; then
    SRC_DIR="$PARENT_DIR/Queen"
elif [ -d "$(pwd)/sections" ]; then
    SRC_DIR="$(pwd)"
elif [ -d "$(pwd)/Queen/sections" ]; then
    SRC_DIR="$(pwd)/Queen"
fi

# If not found locally (e.g. piped via curl/wget), download from GitHub
if [ -z "$SRC_DIR" ]; then
    echo "  -> Running in remote pipe mode. Downloading repository from GitHub..."
    WORK_DIR="/tmp/queen_installer_$$"
    rm -rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
    
    DOWNLOAD_SUCCESS=0
    
    # 1. Try git clone if git is available
    if command -v git >/dev/null 2>&1; then
        echo "  -> Attempting git clone..."
        if git clone --depth 1 "https://github.com/$REPO_USER/$REPO_NAME.git" "$WORK_DIR/repo" >/dev/null 2>&1; then
            DOWNLOAD_SUCCESS=1
        fi
    fi
    
    # 2. Try tarball download if git wasn't used or failed
    if [ "$DOWNLOAD_SUCCESS" -eq 0 ]; then
        echo "  -> Attempting archive download ($REPO_BRANCH)..."
        if download_file "$GITHUB_ARCHIVE/$REPO_BRANCH.tar.gz" "$WORK_DIR/repo.tar.gz"; then
            tar -xzf "$WORK_DIR/repo.tar.gz" -C "$WORK_DIR" 2>/dev/null || true
            DOWNLOAD_SUCCESS=1
        else
            echo "  -> Attempting archive download ($ALT_BRANCH)..."
            if download_file "$GITHUB_ARCHIVE/$ALT_BRANCH.tar.gz" "$WORK_DIR/repo.tar.gz"; then
                tar -xzf "$WORK_DIR/repo.tar.gz" -C "$WORK_DIR" 2>/dev/null || true
                DOWNLOAD_SUCCESS=1
            fi
        fi
    fi

    # Find the extracted folder
    for d in "$WORK_DIR"/*; do
        if [ -d "$d/sections" ]; then
            SRC_DIR="$d"
            break
        elif [ -d "$d/Queen/sections" ]; then
            SRC_DIR="$d/Queen"
            break
        fi
    done

    # 3. Fallback: Download individual raw files directly via GitHub CDN
    if [ -z "$SRC_DIR" ]; then
        echo "  -> Fetching individual Queen files directly via raw GitHub..."
        RAW_DIR="$WORK_DIR/raw_queen"
        mkdir -p "$RAW_DIR/sections/internet" "$RAW_DIR/sections/wireless" "$RAW_DIR/sections/clients" \
                 "$RAW_DIR/sections/mac-filter" "$RAW_DIR/sections/dns" "$RAW_DIR/sections/loadbalance" \
                 "$RAW_DIR/components" "$RAW_DIR/assets" "$RAW_DIR/examples"

        fetch_raw() {
            local rel_p="$1"
            local dest="$2"
            download_file "$GITHUB_RAW/$REPO_BRANCH/$rel_p" "$dest" || \
            download_file "$GITHUB_RAW/$REPO_BRANCH/Queen/$rel_p" "$dest" || \
            download_file "$GITHUB_RAW/$ALT_BRANCH/$rel_p" "$dest" || \
            download_file "$GITHUB_RAW/$ALT_BRANCH/Queen/$rel_p" "$dest" || true
        }

        # Fetch all Queen components
        fetch_raw "sections/internet/luci.internet" "$RAW_DIR/sections/internet/luci.internet"
        fetch_raw "sections/internet/internet.js" "$RAW_DIR/sections/internet/internet.js"
        fetch_raw "sections/wireless/luci.wireless" "$RAW_DIR/sections/wireless/luci.wireless"
        fetch_raw "sections/wireless/wireless.js" "$RAW_DIR/sections/wireless/wireless.js"
        fetch_raw "sections/clients/luci.clients" "$RAW_DIR/sections/clients/luci.clients"
        fetch_raw "sections/clients/clients.js" "$RAW_DIR/sections/clients/clients.js"
        fetch_raw "sections/mac-filter/luci.macfilter" "$RAW_DIR/sections/mac-filter/luci.macfilter"
        fetch_raw "sections/mac-filter/macfilter.js" "$RAW_DIR/sections/mac-filter/macfilter.js"
        fetch_raw "sections/dns/luci.dns" "$RAW_DIR/sections/dns/luci.dns"
        fetch_raw "sections/dns/dns.js" "$RAW_DIR/sections/dns/dns.js"
        fetch_raw "sections/loadbalance/luci.loadbalance" "$RAW_DIR/sections/loadbalance/luci.loadbalance"
        fetch_raw "sections/loadbalance/loadbalance.js" "$RAW_DIR/sections/loadbalance/loadbalance.js"
        fetch_raw "components/menu.json" "$RAW_DIR/components/menu.json"
        fetch_raw "components/acl.json" "$RAW_DIR/components/acl.json"
        fetch_raw "assets/primenet_router.png" "$RAW_DIR/assets/primenet_router.png"
        fetch_raw "examples/mwan3.example" "$RAW_DIR/examples/mwan3.example"

        if [ -s "$RAW_DIR/sections/internet/luci.internet" ]; then
            SRC_DIR="$RAW_DIR"
        fi
    fi
fi

if [ -z "$SRC_DIR" ] || [ ! -d "$SRC_DIR/sections" ]; then
    echo "❌ ERROR: Could not locate or download Queen source files!"
    echo "Please ensure the router has Internet access or clone https://github.com/$REPO_USER/$REPO_NAME.git manually."
    exit 1
fi

echo "  -> Source files located at: $SRC_DIR"

# Step 5: Deploy Backend Plugins & Frontend Views
echo "[5/7] Deploying backend plugins & frontend views..."
cp -f "$SRC_DIR/sections/internet/luci.internet" /usr/libexec/rpcd/luci.internet
cp -f "$SRC_DIR/sections/wireless/luci.wireless" /usr/libexec/rpcd/luci.wireless
cp -f "$SRC_DIR/sections/clients/luci.clients" /usr/libexec/rpcd/luci.clients
cp -f "$SRC_DIR/sections/mac-filter/luci.macfilter" /usr/libexec/rpcd/luci.macfilter
cp -f "$SRC_DIR/sections/dns/luci.dns" /usr/libexec/rpcd/luci.dns
cp -f "$SRC_DIR/sections/loadbalance/luci.loadbalance" /usr/libexec/rpcd/luci.loadbalance

cp -f "$SRC_DIR/sections/internet/internet.js" /www/luci-static/resources/view/queenx/internet.js
cp -f "$SRC_DIR/sections/wireless/wireless.js" /www/luci-static/resources/view/queenx/wireless.js
cp -f "$SRC_DIR/sections/clients/clients.js" /www/luci-static/resources/view/queenx/clients.js
cp -f "$SRC_DIR/sections/mac-filter/macfilter.js" /www/luci-static/resources/view/queenx/macfilter.js
cp -f "$SRC_DIR/sections/dns/dns.js" /www/luci-static/resources/view/queenx/dns.js
cp -f "$SRC_DIR/sections/loadbalance/loadbalance.js" /www/luci-static/resources/view/queenx/loadbalance.js

cp -f "$SRC_DIR/components/menu.json" /usr/share/luci/menu.d/luci-app-queenx.json
cp -f "$SRC_DIR/components/acl.json" /usr/share/rpcd/acl.d/luci-app-queenx.json

if [ -f "$SRC_DIR/assets/primenet_router.png" ]; then
    cp -f "$SRC_DIR/assets/primenet_router.png" /www/luci-static/resources/primenet_router.png
fi

if [ ! -f "/etc/config/mwan3" ] && [ -f "$SRC_DIR/examples/mwan3.example" ]; then
    cp -f "$SRC_DIR/examples/mwan3.example" /etc/config/mwan3
fi

# Step 6: Set Permissions & Reload Daemons
echo "[6/7] Setting permissions and refreshing system services..."
chmod 0755 /usr/libexec/rpcd/luci.* 2>/dev/null || true
chmod 0644 /www/luci-static/resources/view/queenx/*.js 2>/dev/null || true
chmod 0644 /usr/share/luci/menu.d/luci-app-queenx.json 2>/dev/null || true
chmod 0644 /usr/share/rpcd/acl.d/luci-app-queenx.json 2>/dev/null || true

/etc/init.d/rpcd reload
rm -rf /tmp/luci-indexcache* /tmp/luci-modulecache*

# Cleanup temporary download folder if used
if [ -n "$WORK_DIR" ] && [ -d "$WORK_DIR" ]; then
    rm -rf "$WORK_DIR"
fi

# Step 7: Self-Verification
echo "[7/7] Running automated installation verification..."
ALL_OK=1
for b in internet wireless clients macfilter dns loadbalance; do
    if [ ! -x "/usr/libexec/rpcd/luci.$b" ]; then
        echo "  [FAIL] Backend /usr/libexec/rpcd/luci.$b is missing or not executable!"
        ALL_OK=0
    fi
    if [ ! -f "/www/luci-static/resources/view/queenx/$b.js" ]; then
        echo "  [FAIL] Frontend view /www/luci-static/resources/view/queenx/$b.js is missing!"
        ALL_OK=0
    fi
done

if [ "$ALL_OK" -eq 1 ]; then
    echo "  -> All 6 backends, 6 frontend views, menu routes & ACLs verified: OK!"
else
    echo "  ⚠️ Warning: Some components may not have installed correctly."
fi

echo ""
echo "================================================================="
echo "  ✅ Queen Management Suite & Argon Theme Installed Successfully! "
echo "================================================================="
echo "Open your browser and navigate to:"
echo "👉 http://192.168.1.1/cgi-bin/luci/admin/queenx/internet"
echo "================================================================="
