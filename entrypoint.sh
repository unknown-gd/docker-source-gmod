#!/bin/bash
set -e

# Give everything time to initialize for preventing SteamCMD deadlock
sleep 1

# Default the TZ environment variable to UTC.
TZ=${TZ:-UTC}
export TZ

# Set environment variable that holds the Internal Docker IP
INTERNAL_IP=$(ip route get 1 | awk '{print $(NF-2);exit}')
export INTERNAL_IP

# Switch to the container's working directory
cd /home/container || exit 1

# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell
# variable format of "${VARIABLE}" before evaluating the string and automatically
# replacing the values.
PARSED=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g' | eval echo "$(cat -)")

# https://stackoverflow.com/questions/5947742/how-to-change-the-output-color-of-echo-in-linux
Default='\e[0m'       # Text Reset
Red='\e[1;31m'          # Red
Green='\e[1;32m'        # Green
Yellow='\e[1;33m'       # Yellow
Cyan='\e[1;36m'         # Cyan

mkdir -p /home/container/garrysmod/lua/bin
mkdir -p /home/container/garrysmod/addons

ARCH=linux
if [ "$GMOD_BRANCH" = "x86-64" ]; then
    mkdir -p /home/container/bin/linux64
    ARCH=linux64
else
    mkdir -p /home/container/bin/linux32
fi

if [ "${AUTO_UPDATE}" = "1" ] || { [ "$GMOD_BRANCH" = "x86-64" ] && [ ! -f "/home/container/srcds_run_x64" ]; }; then
    echo -e "${Default}[${Cyan}p1ka.eu${Default}]${Yellow} Updating Garry's Mod (branch: ${GMOD_BRANCH})..."

    ./steamcmd/steamcmd.sh \
        +force_install_dir /home/container \
        +login anonymous \
        +app_update 4020 \
        -beta "${GMOD_BRANCH}" \
        validate \
        +quit
fi

if [[ ! -z "$GIT_ADDONS" ]]; then
    for repo_url in $(echo "$GIT_ADDONS" | tr ',\n\t' '   '); do
        repo_name=$(echo "$repo_url" | sed -E 's#.*/([^/]+)\.git$#\1#')
        repo_path=/home/container/garrysmod/addons/${repo_name}
        echo -e "${Default}[${Cyan}p1ka.eu${Default}]${Green} Cloning ${repo_name}..."

        if [[ -d "$repo_path" ]]; then
            cd "$repo_path" || exit 1
            git reset --hard
            git clean -fd
            git pull
        else
            git clone "$repo_url" "$repo_path"
        fi

        git submodule update --init --recursive "$repo_path"

    done

    cd /home/container || exit 1
fi

bool() {
    if [ "$1" = "$2" ]; then
        echo true
    else
        echo false
    fi
}

get_github_asset_url() {
    repo_path="$1"
    file_name="$2"

    curl -fsSL "https://api.github.com/repos/${repo_path}/releases/latest" \
        | grep browser_download_url \
        | grep -m 1 -F "${file_name}" \
        | cut -d '"' -f 4
}

download_extract() {
    url="$1"
    dest="$2"

    echo -e "${Default}[${Cyan}p1ka.eu${Default}]${Green} Downloading '$url'..."

    archive="$(mktemp)"
    curl -L --fail -o "$archive" "$url"

    echo -e "${Default}[${Cyan}p1ka.eu${Default}] Extracting '$archive'..."

    mkdir -p "$dest"
    unzip -oq "$archive" -d "$dest"

    echo -e "${Default}[${Cyan}p1ka.eu${Default}] Extracted '$archive' to '$dest'"

    rm -f "$archive"
}

install_vdf() {
    local name="$1"
    local is_enabled="${2:-false}"
    local is_plugin="${3:-false}"

    local vmf_path="/home/container/garrysmod/addons/gmsv_${name}_${ARCH}.vdf"
    local plugin_path="lua/bin/gmsv_${name}_${ARCH}.so"

    if { $is_enabled && $is_plugin && [ ! -f "$vmf_path" ]; }; then
        printf "Plugin\n{\n\tfile\t\t\"${plugin_path}\"\n}\n" > "$vmf_path"
        echo -e "${Default}[${Cyan}p1ka.eu${Default}]${Green} Generated VDF for plugin '${name}' (reason: enabled as plugin)"
    elif [ -f "$vmf_path" ]; then
        echo -e "${Default}[${Cyan}p1ka.eu${Default}]${Yellow} Removing VDF for plugin '${name}' (reason: disabled/not_a_plugin)"
        rm -f "$vmf_path"
    fi
}

install_module() {
    local name="$1"
    local repo="$2"
    local is_enabled="${3:-false}"
    local is_plugin="${4:-false}"

    local ext="dll"
    if $is_plugin; then
        ext="so"
    fi

    local file_path="/home/container/garrysmod/lua/bin/gmsv_${name}_${ARCH}.${ext}"

    if $is_enabled; then
        if [ -f "$file_path" ]; then
            echo -e "${Default}[${Cyan}p1ka.eu${Default}] Skipping '$name' module (reason: already installed)"
        else
            echo -e "${Default}[${Cyan}p1ka.eu${Default}]${Green} Installing '$name' module..."
            curl -L --fail \
                -o "$file_path" \
                "$(get_github_asset_url "$repo" "gmsv_${name}_${ARCH}.${ext}")"
        fi
    elif [ -f "$file_path" ]; then
        echo -e "${Default}[${Cyan}p1ka.eu${Default}]${Red} Purging '$name' module (reason: disabled)"
        rm -f "$file_path"
    fi

    install_vdf "$name" "$is_enabled" "$is_plugin"
}

# https://github.com/RaphaelIT7/VPhysics-Jolt
if [ "${GMOD_PHYSICS_ENGINE}" = "jolt" ]; then
    echo -e "${Default}[${Cyan}p1ka.eu${Default}]${Green} Installing Jolt Physics Engine..."

    if [ "$GMOD_BRANCH" = "x86-64" ]; then
        download_extract "$(get_github_asset_url "RaphaelIT7/VPhysics-Jolt" "linux64.zip")" "/home/container"
    else
        download_extract "$(get_github_asset_url "RaphaelIT7/VPhysics-Jolt" "linux32.zip")" "/home/container"
    fi

# https://github.com/Asphaltian/VPhysics-Box3D
elif [ "${GMOD_PHYSICS_ENGINE}" = "box3d" ]; then
    echo -e "${Default}[${Cyan}p1ka.eu${Default}]${Green} Installing Box3D Physics Engine..."

    if [ "$GMOD_BRANCH" = "x86-64" ]; then
        download_extract "$(get_github_asset_url "Asphaltian/VPhysics-Box3D" "gmod-linux-x64-dedicated.zip")" "/home/container/bin/linux64"
    else
        download_extract "$(get_github_asset_url "Asphaltian/VPhysics-Box3D" "gmod-linux-x86-dedicated.zip")" "/home/container/bin"
    fi
fi

# https://github.com/timschumi/gmod-chttp
install_module \
    "chttp" \
    "timschumi/gmod-chttp" \
    "$(bool "${GMOD_HTTP_CLIENT}" "chttp")" \
    false

# https://github.com/WilliamVenner/gmsv_reqwest
install_module \
    "reqwest" \
    "WilliamVenner/gmsv_reqwest" \
    "$(bool "${GMOD_HTTP_CLIENT}" "reqwest")" \
    false

# https://github.com/RaphaelIT7/gmod-holylib
install_module \
    "holylib" \
    "RaphaelIT7/gmod-holylib" \
    "$(bool "${GMOD_HOLYLIB}" "1")" \
    true

# https://github.com/ncgst/gm_passlogpatch
install_module \
    "passlogpatch" \
    "ncgst/gm_passlogpatch" \
    "$(bool "${GMOD_MODULE_PASSLOGPATCH}" "1")" \
    false

# https://github.com/shockpast/gm_tungstenite
install_module \
    "tungstenite" \
    "shockpast/gm_tungstenite" \
    "$(bool "${GMOD_MODULE_TUNGSTENITE}" "1")" \
    false

# https://github.com/wrefgtzweve/gm_getregistry
install_module \
    "getregistry" \
    "wrefgtzweve/gm_getregistry" \
    "$(bool "${GMOD_MODULE_GETREGISTRY}" "1")" \
    false

# https://github.com/FredyH/GWSockets
install_module \
    "gwsockets" \
    "FredyH/GWSockets" \
    "$(bool "${GMOD_MODULE_GWSOCKETS}" "1")" \
    false

# https://github.com/WilliamVenner/gmsv_workshop
install_module \
    "workshop" \
    "WilliamVenner/gmsv_workshop" \
    "$(bool "${GMOD_MODULE_WORKSHOP}" "1")" \
    false

# https://github.com/Pika-Software/gmsv_async_postgres
install_module \
    "async_postgres" \
    "Pika-Software/gmsv_async_postgres" \
    "$(bool "${GMOD_MODULE_POSTGRES}" "1")" \
    false

# https://github.com/Pika-Software/gm_asyncio
install_module \
    "asyncio" \
    "Pika-Software/gm_asyncio" \
    "$(bool "${GMOD_MODULE_ASYNC_IO}" "1")" \
    false

# https://github.com/Pika-Software/gm_efsw
install_module \
    "efsw" \
    "Pika-Software/gm_efsw" \
    "$(bool "${GMOD_MODULE_EFSW}" "1")" \
    false

# https://github.com/WilliamVenner/gmsv_serverstat
install_module \
    "serverstat" \
    "WilliamVenner/gmsv_serverstat" \
    "$(bool "${GMOD_MODULE_SERVERSTAT}" "1")" \
    false

# https://github.com/blueshank-gh/plugin_crashcapture
install_module \
    "crashcapture" \
    "blueshank-gh/plugin_crashcapture" \
    "$(bool "${GMOD_MODULE_CRASHCAPTURE}" "1")" \
    true

# Switch to the container's working directory
cd /home/container || exit 1

# Display the command we're running in the output, and then execute it with the env
# from the container itself.
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"

# shellcheck disable=SC2086
exec env ${PARSED}
