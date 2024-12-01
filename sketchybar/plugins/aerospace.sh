#!/usr/bin/env bash

focus_sid=$(aerospace list-workspaces --focused)

if [ "$1" = "$focus_sid" ]; then
    sketchybar --set $NAME background.drawing=on
else
    sketchybar --set $NAME background.drawing=off
fi

