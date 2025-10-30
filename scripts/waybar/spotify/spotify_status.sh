#!/usr/bin/env bash

status=$(playerctl --player=spotify status 2>/dev/null)

if [[ "$status" == "Playing" ]] || [[ "$status" == "Paused" ]]; then
    artist=$(playerctl --player=spotify metadata artist)
    album=$(playerctl --player=spotify metadata album)
    title=$(playerctl --player=spotify metadata title)
    echo "${artist} >> ${album} > ${title}"
else
    echo ""
fi
