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

if [ -z "${AUTO_UPDATE}" ] || [ "${AUTO_UPDATE}" == "1" ] || { [ "${GMOD_X64}" == "1" ] && [ ! -f "/home/container/srcds_run_x64" ]; }; then
    ./steamcmd/steamcmd.sh +force_install_dir /home/container +login anonymous +app_update 4020 -beta $( [[ "${GMOD_X64}" == "1" ]] && printf %s 'x86-64' || printf %s 'public' ) validate +quit
fi

mkdir -p /home/container/garrysmod/lua/bin
mkdir -p /home/container/garrysmod/addons

if [ "${GMOD_X64}" = "1" ]; then
    mkdir -p /home/container/bin/linux64
else
    mkdir -p /home/container/bin/linux32
fi

if [[ ! -z "$GIT_ADDONS" ]]; then
    for repo_url in $(echo "$GIT_ADDONS" | tr ',\n\t' '   '); do
        repo_path=/home/container/garrysmod/addons/$(echo "$repo_url" | sed -E 's#.*/([^/]+)\.git$#\1#')

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

github_asset() {
    curl -fsSL "https://api.github.com/repos/${1}/releases/latest" \
        | grep browser_download_url \
        | grep -m 1 -F "$2" \
        | cut -d '"' -f 4
}

download_extract() {
    url="$1"
    dest="$2"

    archive="$(mktemp)"

    curl -L --fail -o "$archive" "$url"
    mkdir -p "$dest"
    unzip -oq "$archive" -d "$dest"

    rm -f "$archive"
}

# https://github.com/RaphaelIT7/VPhysics-Jolt
if [ "${GMOD_PHYSICS_ENGINE}" = "jolt" ]; then
    echo "Installing Jolt..."

    if [ "${GMOD_X64}" = "1" ]; then
        download_extract "$(github_asset "RaphaelIT7/VPhysics-Jolt" "linux64.zip")" "/home/container"
    else
        download_extract "$(github_asset "RaphaelIT7/VPhysics-Jolt" "linux32.zip")" "/home/container"
    fi

# https://github.com/Asphaltian/VPhysics-Box3D
elif [ "${GMOD_PHYSICS_ENGINE}" = "box3d" ]; then
    echo "Installing Box3D..."

    if [ "${GMOD_X64}" = "1" ]; then
        download_extract "$(github_asset "Asphaltian/VPhysics-Box3D" "gmod-linux-x64-dedicated.zip")" "/home/container/bin/linux64"
    else
        download_extract "$(github_asset "Asphaltian/VPhysics-Box3D" "gmod-linux-x86-dedicated.zip")" "/home/container/bin"
    fi
fi

# https://github.com/timschumi/gmod-chttp
if [ "${GMOD_HTTP_CLIENT}" = "chttp" ]; then
    echo "Installing gmod-chttp..."

    if [ "${GMOD_X64}" = "1" ]; then
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_chttp_linux64.dll "$(github_asset "timschumi/gmod-chttp" "gmsv_chttp_linux64.dll")"
    else
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_chttp_linux.dll "$(github_asset "timschumi/gmod-chttp" "gmsv_chttp_linux.dll")"
    fi

    if [ -f "/home/container/garrysmod/lua/bin/gmsv_reqwest_linux.dll" ]; then
        rm -f /home/container/garrysmod/lua/bin/gmsv_reqwest_linux.dll
    fi

    if [ -f "/home/container/garrysmod/lua/bin/gmsv_reqwest_linux64.dll" ]; then
        rm -f /home/container/garrysmod/lua/bin/gmsv_reqwest_linux64.dll
    fi

# https://github.com/WilliamVenner/gmsv_reqwest
elif [ "${GMOD_HTTP_CLIENT}" = "reqwest" ]; then
    echo "Installing gmod-reqwest..."

    if [ "${GMOD_X64}" = "1" ]; then
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_reqwest_linux64.dll "$(github_asset "WilliamVenner/gmsv_reqwest" "gmsv_reqwest_linux64.dll")"
    else
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_reqwest_linux.dll "$(github_asset "WilliamVenner/gmsv_reqwest" "gmsv_reqwest_linux.dll")"
    fi

    if [ -f "/home/container/garrysmod/lua/bin/gmsv_chttp_linux.dll" ]; then
        rm -f /home/container/garrysmod/lua/bin/gmsv_chttp_linux.dll
    fi

    if [ -f "/home/container/garrysmod/lua/bin/gmsv_chttp_linux64.dll" ]; then
        rm -f /home/container/garrysmod/lua/bin/gmsv_chttp_linux64.dll
    fi
else
    if [ -f "/home/container/garrysmod/lua/bin/gmsv_chttp_linux.dll" ]; then
        rm -f /home/container/garrysmod/lua/bin/gmsv_chttp_linux.dll
    fi

    if [ -f "/home/container/garrysmod/lua/bin/gmsv_chttp_linux64.dll" ]; then
        rm -f /home/container/garrysmod/lua/bin/gmsv_chttp_linux64.dll
    fi

    if [ -f "/home/container/garrysmod/lua/bin/gmsv_reqwest_linux.dll" ]; then
        rm -f /home/container/garrysmod/lua/bin/gmsv_reqwest_linux.dll
    fi

    if [ -f "/home/container/garrysmod/lua/bin/gmsv_reqwest_linux64.dll" ]; then
        rm -f /home/container/garrysmod/lua/bin/gmsv_reqwest_linux64.dll
    fi
fi

# https://github.com/RaphaelIT7/gmod-holylib
if [ "${GMOD_HOLYLIB}" = "1" ]; then
    echo "Installing HolyLib..."

    if [ "${GMOD_X64}" = "1" ]; then
        curl -L --fail -o /home/container/garrysmod/addons/holylib_linux_64.vdf "$(github_asset "RaphaelIT7/gmod-holylib" "holylib_linux_64.vdf")"
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_holylib_linux64.so "$(github_asset "RaphaelIT7/gmod-holylib" "gmsv_holylib_linux64.so")"
    else
        curl -L --fail -o /home/container/garrysmod/addons/holylib_linux.vdf "$(github_asset "RaphaelIT7/gmod-holylib" "holylib_linux.vdf")"
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_holylib_linux.so "$(github_asset "RaphaelIT7/gmod-holylib" "gmsv_holylib_linux.so")"
    fi
elif [ "${GMOD_X64}" = "1" ]; then
    if [ -f "/home/container/garrysmod/addons/holylib_linux_64.vdf" ]; then
        rm -f /home/container/garrysmod/addons/holylib_linux_64.vdf
    fi

    if [ -f "/home/container/garrysmod/lua/bin/gmsv_holylib_linux64.so" ]; then
        rm -f /home/container/garrysmod/lua/bin/gmsv_holylib_linux64.so
    fi
else
    if [ -f "/home/container/garrysmod/addons/holylib_linux.vdf" ]; then
        rm -f /home/container/garrysmod/addons/holylib_linux.vdf
    fi

    if [ -f "/home/container/garrysmod/lua/bin/gmsv_holylib_linux.so" ]; then
        rm -f /home/container/garrysmod/lua/bin/gmsv_holylib_linux.so
    fi
fi

# https://github.com/ncgst/gm_passlogpatch
if [ "${GMOD_MODULE_PASSLOGPATCH}" = "1" ]; then
    echo "Installing gm_passlogpatch..."

    if [ "${GMOD_X64}" = "1" ]; then
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_passlogpatch_linux64.dll "$(github_asset "ncgst/gm_passlogpatch" "gmsv_passlogpatch_linux64.dll")"
    else
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_passlogpatch_linux.dll "$(github_asset "ncgst/gm_passlogpatch" "gmsv_passlogpatch_linux.dll")"
    fi
elif [ "${GMOD_X64}" = "1" ] && [ -f "/home/container/garrysmod/lua/bin/gmsv_passlogpatch_linux64.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_passlogpatch_linux64.dll
elif [ -f "/home/container/garrysmod/lua/bin/gmsv_passlogpatch_linux.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_passlogpatch_linux.dll
fi

# https://github.com/shockpast/gm_tungstenite
if [ "${GMOD_MODULE_TUNGSTENITE}" = "1" ]; then
    echo "Installing gm_tungstenite..."

    if [ "${GMOD_X64}" = "1" ]; then
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_tungstenite_linux64.dll "$(github_asset "shockpast/gm_tungstenite" "gmsv_tungstenite_linux64.dll")"
    else
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_tungstenite_linux.dll "$(github_asset "shockpast/gm_tungstenite" "gmsv_tungstenite_linux.dll")"
    fi
elif [ "${GMOD_X64}" = "1" ] && [ -f "/home/container/garrysmod/lua/bin/gmsv_tungstenite_linux64.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_tungstenite_linux64.dll
elif [ -f "/home/container/garrysmod/lua/bin/gmsv_tungstenite_linux.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_tungstenite_linux.dll
fi

# https://github.com/wrefgtzweve/gm_getregistry
if [ "${GMOD_MODULE_GETREGISTRY}" = "1" ]; then
    echo "Installing gm_getregistry..."

    if [ "${GMOD_X64}" = "1" ]; then
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_getregistry_linux64.dll "$(github_asset "wrefgtzweve/gm_getregistry" "gmsv_getregistry_linux64.dll")"
    else
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_getregistry_linux.dll "$(github_asset "wrefgtzweve/gm_getregistry" "gmsv_getregistry_linux.dll")"
    fi
elif [ "${GMOD_X64}" = "1" ] && [ -f "/home/container/garrysmod/lua/bin/gmsv_getregistry_linux64.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_getregistry_linux64.dll
elif [ -f "/home/container/garrysmod/lua/bin/gmsv_getregistry_linux.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_getregistry_linux.dll
fi

# https://github.com/FredyH/GWSockets
if [ "${GMOD_MODULE_GWSOCKETS}" = "1" ]; then
    echo "Installing gm_gwsockets..."

    if [ "${GMOD_X64}" = "1" ]; then
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_gwsockets_linux64.dll "$(github_asset "FredyH/GWSockets" "gmsv_gwsockets_linux64.dll")"
    else
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_gwsockets_linux.dll "$(github_asset "FredyH/GWSockets" "gmsv_gwsockets_linux.dll")"
    fi
elif [ "${GMOD_X64}" = "1" ] && [ -f "/home/container/garrysmod/lua/bin/gmsv_gwsockets_linux64.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_gwsockets_linux64.dll
elif [ -f "/home/container/garrysmod/lua/bin/gmsv_gwsockets_linux.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_gwsockets_linux.dll
fi

# https://github.com/WilliamVenner/gmsv_workshop
if [ "${GMOD_MODULE_WORKSHOP}" = "1" ]; then
    echo "Installing gmsv_workshop..."

    if [ "${GMOD_X64}" = "1" ]; then
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_workshop_linux64.dll "$(github_asset "WilliamVenner/gmsv_workshop" "gmsv_workshop_linux64.dll")"
    else
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_workshop_linux.dll "$(github_asset "WilliamVenner/gmsv_workshop" "gmsv_workshop_linux.dll")"
    fi
elif [ "${GMOD_X64}" = "1" ] && [ -f "/home/container/garrysmod/lua/bin/gmsv_workshop_linux64.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_workshop_linux64.dll
elif [ -f "/home/container/garrysmod/lua/bin/gmsv_workshop_linux.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_workshop_linux.dll
fi

# https://github.com/Pika-Software/gmsv_async_postgres
if [ "${GMOD_MODULE_POSTGRES}" = "1" ]; then
    echo "Installing gmsv_async_postgres..."

    if [ "${GMOD_X64}" = "1" ]; then
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_async_postgres_linux64.dll "$(github_asset "Pika-Software/gmsv_async_postgres" "gmsv_async_postgres_linux64.dll")"
    else
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_async_postgres_linux.dll "$(github_asset "Pika-Software/gmsv_async_postgres" "gmsv_async_postgres_linux.dll")"
    fi
elif [ "${GMOD_X64}" = "1" ] && [ -f "/home/container/garrysmod/lua/bin/gmsv_async_postgres_linux64.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_async_postgres_linux64.dll
elif [ -f "/home/container/garrysmod/lua/bin/gmsv_async_postgres_linux.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_async_postgres_linux.dll
fi

# https://github.com/Pika-Software/gm_asyncio
if [ "${GMOD_MODULE_ASYNC_IO}" = "1" ]; then
    echo "Installing gm_asyncio..."

    if [ "${GMOD_X64}" = "1" ]; then
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_asyncio_linux64.dll "$(github_asset "Pika-Software/gm_asyncio" "gmsv_asyncio_linux64.dll")"
    else
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_asyncio_linux.dll "$(github_asset "Pika-Software/gm_asyncio" "gmsv_asyncio_linux.dll")"
    fi
elif [ "${GMOD_X64}" = "1" ] && [ -f "/home/container/garrysmod/lua/bin/gmsv_asyncio_linux64.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_asyncio_linux64.dll
elif [ -f "/home/container/garrysmod/lua/bin/gmsv_asyncio_linux.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_asyncio_linux.dll
fi

# https://github.com/Pika-Software/gm_efsw
if [ "${GMOD_MODULE_EFSW}" = "1" ]; then
    echo "Installing gm_efsw..."

    if [ "${GMOD_X64}" = "1" ]; then
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_efsw_linux64.dll "$(github_asset "Pika-Software/gm_efsw" "gmsv_efsw_linux64.dll")"
    else
        curl -L --fail -o /home/container/garrysmod/lua/bin/gmsv_efsw_linux.dll "$(github_asset "Pika-Software/gm_efsw" "gmsv_efsw_linux.dll")"
    fi
elif [ "${GMOD_X64}" = "1" ] && [ -f "/home/container/garrysmod/lua/bin/gmsv_efsw_linux64.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_efsw_linux64.dll
elif [ -f "/home/container/garrysmod/lua/bin/gmsv_efsw_linux.dll" ]; then
    rm -f /home/container/garrysmod/lua/bin/gmsv_efsw_linux.dll
fi

# Switch to the container's working directory
cd /home/container || exit 1

# Display the command we're running in the output, and then execute it with the env
# from the container itself.
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"

# shellcheck disable=SC2086
exec env ${PARSED}
