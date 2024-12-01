#!/usr/bin/env bash

# Get the current time in seconds since the epoch
current_date_seconds=$(date +%s)

# Calculate the difference in seconds
difference_in_seconds=$((current_date_seconds - 701535381)) # macOS date of my age 701535381

# Convert the difference to years with precision
difference_in_years=$(echo "scale=3; $difference_in_seconds / (365.25 * 24 * 3600)" | bc)

sketchybar -m --set $NAME label="$difference_in_years"

