#!/bin/bash

col_seps=0xffD3C6AA
col_icons=0xff493628
col_spaces=0xff54473F
col_bar=0xff91a87a  
POPUP_OFF='sketchybar --set apple.logo popup.drawing=off'
POPUP_CLICK_SCRIPT='sketchybar --set $NAME popup.drawing=toggle'

apple_logo=(
  click_script="$POPUP_CLICK_SCRIPT"
  popup.height=35
  label="$APPLE"
  icon="󱢗"
  label.padding_right=0
  label.padding_left=0
  background.color=0x0032a932
  background.height=23
  background.corner_radius=30
  background.padding_left=20
  background.padding_right=1
  icon.color=0xff493628
	icon.font="Terminess Nerd Font:Bold:24.0" \
)

apple_prefs=(
  icon=$PREFERENCES
  label="Preferences"
  background.color="$col_bar"
  label.padding_left=10
  label.padding_right=40
  click_script="open -a 'System Preferences'; $POPUP_OFF"
)

apple_activity=(
  icon=$ACTIVITY
  label="Activity"
  label.color="$col_seps"
  label.padding_left=10
  label.padding_right=62
  background.color="$col_icons"
  click_script="open -a 'Activity Monitor'; $POPUP_OFF"
)

apple_lock=(
  icon=$LOCK
  label="Lock Screen"
  label.padding_left=10
  label.padding_right=40
  background.color="$col_bar"
  click_script="pmset displaysleepnow; $POPUP_OFF"
)

sketchybar --add item apple.logo left                  \
           --set apple.logo "${apple_logo[@]}"         \
                                                       \
           --add item apple.prefs popup.apple.logo     \
           --set apple.prefs "${apple_prefs[@]}"       \
                                                       \
           --add item apple.activity popup.apple.logo  \
           --set apple.activity "${apple_activity[@]}" \
                                                       \
           --add item apple.lock popup.apple.logo      \
           --set apple.lock "${apple_lock[@]}"
