#!/bin/bash
# Server Files: /mnt/server

## download and install steamcmd
cd /tmp
mkdir -p /mnt/server/steamcmd
curl -sSL -o steamcmd.tar.gz https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz
tar -xzvf steamcmd.tar.gz -C /mnt/server/steamcmd
# Fix steamcmd disk write error when this folder is missing
mkdir -p /mnt/server/steamapps
cd /mnt/server/steamcmd

# SteamCMD fails otherwise for some reason, even running as root.
# This is changed at the end of the install process anyways.
chown -R root:root /mnt
export HOME=/mnt/server

## install game using steamcmd
./steamcmd.sh +force_install_dir /mnt/server +login anonymous +app_update 4020 -beta $( [[ "${GMOD_X64}" == "1" ]] && printf %s 'x86-64' || printf %s 'public' ) validate +quit

## set up 32 bit libraries
mkdir -p /mnt/server/.steam/sdk32
cp -v linux32/steamclient.so ../.steam/sdk32/steamclient.so

## set up 64 bit libraries
mkdir -p /mnt/server/.steam/sdk64
cp -v linux64/steamclient.so ../.steam/sdk64/steamclient.so

cd /mnt/server/garrysmod/cfg
if [ ! -f "server.cfg" ]; then

echo '
hostname        "p1ka.eu - Public Server"
sv_password     ""
sv_loadingurl   ""
sv_downloadurl  ""

// Steam Server List Settings
sv_location "eu"
sv_lan "0"

// Game Defaults - HL2
sv_defaultdeployspeed   1
mp_show_voice_icons     0
sv_gravity              800

// Network Settings - Please keep these set to default.
sv_minrate              75000
sv_maxrate              0
gmod_physiterations     2
net_splitpacket_maxrate 45000
decalfrequency          12

// Execute Ban Files - Please do not edit
exec banned_ip.cfg
exec banned_user.cfg
' > server.cfg

fi

mkdir -p /mnt/server/garrysmod/addons
