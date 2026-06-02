#!/bin/bash

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
fi

# ttt is restricted here >:c
rm -rf "/home/container/garrysmod/gamemodes/terrortown"

find "/home/container/garrysmod/addons" \
    -type d \
    -path '*/gamemodes/terrortown' |
while read -r ttt_dir; do
    rm -rf "$(echo "$ttt_dir" | sed 's#/gamemodes/terrortown$##')"
done

# Switch to the container's working directory
cd /home/container || exit 1

# Display the command we're running in the output, and then execute it with the env
# from the container itself.
printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"

# shellcheck disable=SC2086
exec env ${PARSED}
