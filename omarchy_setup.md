# Rebuilding this Omarchy setup on a fresh install

This guide takes a fresh Omarchy install to this machine's setup: the **cyberdeck** look plus the apps, scripts and system settings described in `CLAUDE.md`. Each config file is included in full as a paste-ready block. Work through the steps in order and paste each block into a terminal.

- **Written for Omarchy 4.0.6** (Arch Linux + Hyprland), 3 Nov 2026. Step 7 applies the shell-plugin changes as patches against Omarchy 4.0.6's stock files. On a newer Omarchy a patch may not apply cleanly; step 7 explains what to do.
- **Hardware:** ThinkPad T14s Gen 3, host `think-beast`, user `sampsonml`. It has a laptop panel (`eDP-1`), a Synaptics touchpad and a fingerprint reader, and docks to an LG 4K monitor.
- **This file contains personal details exactly as configured:** email addresses (calendar shortcuts), a birth date (the mortality counter) and SSH user names. Remove them before sharing the file.
- **Never run `omarchy refresh …` or `omarchy reinstall` on the finished setup.** They reset configs to stock and wipe these changes.

Steps:

0. [Before wiping the old machine: save the image files](#0-before-wiping-the-old-machine-save-the-image-files)
1. [Install and update Omarchy](#1-install-and-update-omarchy)
2. [Packages, fingerprint, hibernation](#2-packages-fingerprint-hibernation)
3. [Lid, sleep and hibernate (system files)](#3-lid-sleep-and-hibernate-system-files)
4. [Theme: cyberdeck](#4-theme-cyberdeck)
5. [Ghostty](#5-ghostty)
6. [Hyprland](#6-hyprland)
7. [Omarchy shell: bar, widgets, lock screen](#7-omarchy-shell-bar-widgets-lock-screen)
8. [tmux](#8-tmux)
9. [Starship prompt](#9-starship-prompt)
10. [Neovim and Python](#10-neovim-and-python)
11. [Web apps, email and default apps](#11-web-apps-email-and-default-apps)
12. [Princeton VPN](#12-princeton-vpn)
13. [SSH](#13-ssh)
14. [Claude Code notes](#14-claude-code-notes)
15. [Final check](#15-final-check)

---

## 0. Before wiping the old machine: save the image files

Four wallpapers and three web-app icons are images, so they can't be pasted from this file. Save them, plus a copy of the cloned shell plugins as a fallback for step 7:

```bash
mkdir -p ~/omarchy-assets
cp ~/.config/omarchy/themes/cyberdeck/backgrounds/*.png ~/omarchy-assets/
cp ~/.config/omarchy/themes/abyss/backgrounds/fantasy_wallpaper.png ~/omarchy-assets/
cp ~/.config/omarchy/themes/graveyard/backgrounds/graveyard.png ~/omarchy-assets/
cp ~/.local/share/icons/hicolor/256x256/apps/{google-calendar,princeton-calendar,overleaf}.png ~/omarchy-assets/
cp -a ~/.config/omarchy/plugins ~/omarchy-assets/plugins-fallback
tar czf ~/omarchy-assets.tar.gz -C ~ omarchy-assets
```

Copy `~/omarchy-assets.tar.gz` to a USB drive or cloud storage.

**Optional: Thunderbird's mail cache.** Copying `~/.config/thunderbird/` (about 20 GB) as well means the new machine doesn't have to download all the mail again, which took several hours. The copy also contains your signed-in mail sessions, so keep it private and delete it once restored.

---

## 1. Install and update Omarchy

1. Install Omarchy (omarchy.org). Use the **same user name, `sampsonml`**. Cloned plugins are named after the user (`sampsonml.bar`, `sampsonml.lock`, …), and `shell.json` refers to those names. The host name `think-beast` is optional; the lock screen shows whatever is in `/etc/hostname`.
2. Update everything, then reboot if asked:

   ```bash
   omarchy update
   ```

3. Unpack the files from step 0. This creates `~/omarchy-assets/`:

   ```bash
   tar xzf omarchy-assets.tar.gz -C ~
   ```

---

## 2. Packages, fingerprint, hibernation

```bash
# Ghostty, set as the default terminal (writes ~/.config/xdg-terminals.list)
omarchy install terminal ghostty

# Iosevka Nerd Font (Ghostty and the custom bar icons), Thunderbird,
# the Princeton VPN client, lsusb
omarchy pkg add ttf-iosevka-nerd thunderbird globalprotect-openconnect usbutils

# Personal apps from the Omarchy repo
omarchy pkg add slack-desktop 1password spotify
```

Fingerprint login and hibernation, using Omarchy's own setup commands:

```bash
omarchy setup security fingerprint   # enrol a finger; used for sudo, polkit prompts and the lock screen
omarchy hibernation setup            # swapfile the size of RAM at /swap/swapfile, resume= kernel options, initramfs resume hook
```

Reboot after `omarchy hibernation setup`.

---

## 3. Lid, sleep and hibernate (system files)

The result:
- **Laptop alone** (on battery or charger): closing the lid locks the screen, sleeps (deep sleep), then hibernates after 2 hours.
- **Docked** (external monitor connected): closing the lid gives clamshell mode, with no lock and no sleep. That's the logind default, `HandleLidSwitchDocked=ignore`, so no file is needed.

These files need `sudo`:

`/etc/systemd/logind.conf.d/30-lid-suspend-then-hibernate.conf`:

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
sudo tee /etc/systemd/logind.conf.d/30-lid-suspend-then-hibernate.conf > /dev/null <<'OMARCHY_EOF'
# Laptop lid closed (not docked): sleep, then hibernate after HibernateDelaySec
# (see /etc/systemd/sleep.conf.d/30-hibernate-delay.conf). Docked lid close
# (external monitor) keeps the default HandleLidSwitchDocked=ignore.
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend-then-hibernate
OMARCHY_EOF
```

`/etc/systemd/sleep.conf.d/30-hibernate-delay.conf`:

```bash
sudo mkdir -p /etc/systemd/sleep.conf.d
sudo tee /etc/systemd/sleep.conf.d/30-hibernate-delay.conf > /dev/null <<'OMARCHY_EOF'
# suspend-then-hibernate: stay in deep sleep for 2 hours, then hibernate to the
# swapfile (/swap/swapfile, set up by `omarchy hibernation setup`).
[Sleep]
HibernateDelaySec=2h
OMARCHY_EOF
```

```bash
sudo systemctl kill -s HUP systemd-logind      # apply without logging out
cat /sys/power/mem_sleep                       # should show [deep] (the default on this laptop)
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch
```

Omarchy itself adds `10-ignore-power-button.conf` and `20-inhibit-delay.conf` in the same folder. Leave those alone.

**Fingerprint after waking up.** The fingerprint reader sometimes drops off USB and reconnects while the laptop sleeps. fprintd then keeps the old reader as a stuck "already claimed" device and uses it as the default, so fingerprint unlock (lock screen, sudo, polkit) fails until fprintd restarts. This unit restarts it after every wake-up. It does nothing if fprintd isn't running. Skip it if you didn't set up fingerprint in step 2.

`/etc/systemd/system/fprintd-resume-restart.service`:

```bash
sudo tee /etc/systemd/system/fprintd-resume-restart.service > /dev/null <<'OMARCHY_EOF'
# sampsonml (4 Nov 2026): restart fprintd every time the laptop wakes from sleep.
#
# The Synaptics reader (USB 06cb:00f9) sometimes drops off USB and reconnects
# while the laptop sleeps, especially when the lock screen is waiting for a
# finger. fprintd then keeps the old reader as a stuck, "already claimed"
# device and offers it as the default, so fingerprint unlock (lock screen, sudo,
# polkit) silently fails until fprintd restarts. Restarting it after each wake
# clears that.
#
# try-restart does nothing if fprintd isn't running (it starts on demand).
# --no-block keeps a stuck fprintd (5 s stop timeout) from delaying wake-up.
# Remove with: sudo systemctl disable --now fprintd-resume-restart.service
#              sudo rm /etc/systemd/system/fprintd-resume-restart.service

[Unit]
Description=Restart fprintd after waking from sleep (stale fingerprint reader fix)
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
Type=oneshot
ExecStart=/usr/bin/systemctl --no-block try-restart fprintd.service

[Install]
WantedBy=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
OMARCHY_EOF
sudo systemctl daemon-reload
sudo systemctl enable fprintd-resume-restart.service
```

---

## 4. Theme: cyberdeck

The palette comes from a long-exposure photo of a hillside at night: copper `#d08a52`, teal `#6fb3b8`, golden olive `#d8c07a`, moss `#9fb565`, ember red `#d9705a`, on near-black `#0e0d12`. Everything later takes its colours from the current theme, so switching theme recolours the whole desktop and nothing else changes apart from the wallpaper. The end of `colors.toml` has three extra keys of our own that tmux and Starship use; other themes fall back to standard keys.

`~/.config/omarchy/themes/cyberdeck/colors.toml`:

```bash
mkdir -p ~/.config/omarchy/themes/cyberdeck
cat > ~/.config/omarchy/themes/cyberdeck/colors.toml <<'OMARCHY_EOF'
# Cyberdeck: colours taken from the main wallpaper (long-exposure night hillside):
# warm near-black and night-indigo base, copper light-trail accent, teal trail fringe,
# moss and golden-olive greens, pale flower white for text. Shared with the tmux bar
# (~/.config/tmux/tmux.conf) and the Starship prompt.

mode = "dark"

accent = "#d08a52"
selection = "#26294a"
muted = "#5c6170"

background = "#0e0d12"
dark_background = "#0b0a0e"
darker_background = "#08070a"
lighter_background = "#1c1d2e"

foreground = "#dde2da"
dark_foreground = "#9fa39f"
light_foreground = "#e8ece4"
bright_foreground = "#f4f6f1"

red = "#d9705a"
green = "#9fb565"
yellow = "#d8c07a"
orange = "#d08a52"
blue = "#8c97d6"
magenta = "#a99bd8"
cyan = "#6fb3b8"
brown = "#7a5a3a"

bright_red     = "#e8907c"
bright_green   = "#bccd8e"
bright_yellow  = "#e8d59e"
bright_blue    = "#adb5e4"
bright_magenta = "#c4b9e6"
bright_cyan    = "#96cbcf"

# Active window: copper -> teal gradient, like the light trails (rotated by the
# borderangle animation in ~/.config/hypr/looknfeel.lua). Inactive: night indigo.
hyprland_active_border = "rgba(d08a52ee) rgba(6fb3b8ee) 45deg"
hyprland_inactive_border = "rgba(26294aaa)"

# Extra roles for the tmux bar and Starship prompt (sampsonml, 4 Nov 2026), written into
# them by ~/.config/omarchy/hooks/theme-set.d/theme-colours. Other themes don't have these
# and fall back to selection / selection / dark_foreground.
pill_background = "#23263d"
pane_border = "#2e3148"
subtle_foreground = "#8f939f"
OMARCHY_EOF
```

`~/.config/omarchy/themes/cyberdeck/icons.theme`:

```bash
mkdir -p ~/.config/omarchy/themes/cyberdeck
cat > ~/.config/omarchy/themes/cyberdeck/icons.theme <<'OMARCHY_EOF'
Yaru-purple
OMARCHY_EOF
```

The procedural wallpaper generator (needs ImageMagick's `magick`, which Omarchy includes):

`~/.config/omarchy/themes/cyberdeck/nightfield.sh`:

```bash
mkdir -p ~/.config/omarchy/themes/cyberdeck
cat > ~/.config/omarchy/themes/cyberdeck/nightfield.sh <<'OMARCHY_EOF'
#!/usr/bin/env bash
# Original "long-exposure night hillside" wallpaper, generated procedurally.
# Usage: nightfield.sh <out.png> [seed]
set -euo pipefail
OUT=$1
SEED=${2:-7}
W=1920 H=1200
QW=$((W/4)) QH=$((H/4))
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# Soft blobby noise, made at low resolution and scaled up (fast large blurs)
blobs() { # seed blur-at-quarter-res out
  magick -size ${QW}x${QH} xc: -seed "$1" +noise Random -channel G -separate +channel -blur 0x"$2" -auto-level -resize ${W}x${H}! "$3"
}

# 1. Sky: near-black top-left, deep indigo-blue towards the right horizon
magick -size ${H}x${W} gradient:'#202a7a'-'#020309' -rotate 90 "$T/sky_h.png"
magick -size ${W}x${H} gradient:'#000000'-'#ffffff' -level -35%,75% "$T/sky_v.png"
magick "$T/sky_h.png" "$T/sky_v.png" -compose multiply -composite "$T/sky.png"

# 2. Light trails at quarter resolution (they're soft anyway), then scaled up
trail() { # colour width blur-x blur opacity out paths...
  local col=$1 sw=$2 mb=$3 bl=$4 op=$5 out=$6; shift 6
  local draws=()
  for p in "$@"; do draws+=(-draw "path '$p'"); done
  magick -size ${QW}x${QH} xc:none -fill none -stroke "$col" -strokewidth "$sw" "${draws[@]}" \
    -motion-blur 0x"$mb"+0 -blur 0x"$bl" -channel A -evaluate multiply "$op" +channel -resize ${W}x${H}! "$out"
}
trail '#b8622e' 11 35 4.5 1.0 "$T/trail_wide.png" \
  'M -25,172 C 75,150 130,130 190,118 S 287,110 375,118' \
  'M -25,200 C 62,180 125,172 205,160 S 300,150 425,140'
trail '#ffb070' 1.6 22 1 1.0 "$T/trail_core.png" \
  'M 25,160 C 95,140 140,125 195,119 S 287,113 355,118' \
  'M 0,192 C 75,175 140,165 220,156 S 312,148 400,140'
trail '#2f8f95' 8 40 5.5 0.5 "$T/trail_teal.png" \
  'M 75,140 C 140,120 190,110 250,106 S 350,108 450,112'

# 3. Hillside rising from bottom-left to the right, with a bumpy, bushy skyline
magick -size ${W}x${H} xc:black -fill white -draw "polygon 0,1200 0,1030 160,970 380,900 600,840 820,780 1000,715 1180,655 1380,612 1560,592 1760,610 1920,650 1920,1200" "$T/hill_shape.png"
blobs $SEED 2 "$T/n_edge.png"
magick "$T/hill_shape.png" "$T/n_edge.png" -compose Displace -define compose:args=0x70 -composite -threshold 50% -morphology Close Disk:7 -blur 0x1.2 "$T/hill_mask.png"

# Foliage: rounded clumps lit from above (shade), needle-like fine texture, dark gaps between bushes
magick -size ${W}x${H} xc: -seed $((SEED+1)) +noise Random -channel G -separate +channel -blur 0x9 -auto-level "$T/n_clump.png"
magick "$T/n_clump.png" -shade 120x32 -auto-level -sigmoidal-contrast 4x55% -blur 0x0.7 "$T/clump_shade.png"
magick -size ${W}x${H} xc: -seed $((SEED+2)) +noise Random -channel G -separate +channel -blur 0x1 -auto-level "$T/n_fine.png"
blobs $((SEED+3)) 4 "$T/n_big.png"
magick "$T/n_big.png" -sigmoidal-contrast 9x42% "$T/gaps.png"
magick "$T/clump_shade.png" "$T/n_fine.png" -compose blend -define compose:args=25 -composite \
  "$T/gaps.png" -compose multiply -composite -auto-level "$T/bush_gray.png"
magick \( -size 1x1 xc:'#020402' xc:'#0f1d0a' xc:'#2c4719' xc:'#5f8638' xc:'#c2d394' +append \) -filter triangle -resize 256x1! "$T/clut.png"
magick "$T/bush_gray.png" "$T/clut.png" -clut "$T/bush.png"

# Flash lighting: brightest on the upper middle of the ridge, falling off into darkness
magick -size 2400x1700 radial-gradient:white-black -crop ${W}x${H}+250+150 +repage -level 0,80% -gamma 1.25 \( -size ${W}x${H} gradient:white-black -level -110%,100% \) -compose multiply -composite "$T/light.png"
magick "$T/bush.png" "$T/light.png" -compose multiply -composite "$T/bush_lit.png"

# 4. Flower rosettes: sparse clusters of pale petals, mostly where the flash lands
magick -size ${W}x${H} xc: -seed $((SEED+4)) +noise Random -channel G -separate +channel -threshold 99.95% \
  -morphology Dilate Disk:10 "$T/fl_seed.png"
magick "$T/n_fine.png" -threshold 48% "$T/petals.png"
blobs $((SEED+5)) 6 "$T/fl_zone.png"
magick "$T/fl_seed.png" "$T/petals.png" -evaluate-sequence Multiply -blur 0x0.9 "$T/fl_raw.png"
magick "$T/fl_zone.png" -level 30%,65% "$T/fl_zone2.png"
magick "$T/clump_shade.png" -level 35%,75% "$T/fl_tops.png"
magick "$T/fl_raw.png" "$T/light.png" "$T/fl_zone2.png" "$T/fl_tops.png" "$T/hill_mask.png" \
  -colorspace gray -evaluate-sequence Multiply -level 0,40% "$T/fl_mask.png"
magick -size ${W}x${H} xc:'#eef3e6' "$T/fl_mask.png" -alpha off -compose CopyOpacity -composite "$T/flowers.png"

# Assemble
magick "$T/bush_lit.png" "$T/hill_mask.png" -alpha off -compose CopyOpacity -composite "$T/hill.png"
magick -size ${W}x${H} radial-gradient:white-black -level -45%,100% "$T/vignette.png"
magick "$T/sky.png" \
  "$T/trail_teal.png" -compose screen -composite \
  "$T/trail_wide.png" -compose screen -composite \
  "$T/trail_core.png" -compose screen -composite \
  "$T/hill.png" -compose over -composite \
  "$T/flowers.png" -compose over -composite \
  "$T/vignette.png" -compose multiply -composite \
  -attenuate 0.3 +noise Gaussian \
  -depth 8 "$OUT"
OMARCHY_EOF
```

```bash
chmod +x ~/.config/omarchy/themes/cyberdeck/nightfield.sh
```

Wallpapers, from step 0:

```bash
mkdir -p ~/.config/omarchy/themes/cyberdeck/backgrounds
cp ~/omarchy-assets/0-perplexity-hero.png ~/omarchy-assets/1-nightfield.png ~/.config/omarchy/themes/cyberdeck/backgrounds/
```

If `1-nightfield.png` is missing, regenerate it with `~/.config/omarchy/themes/cyberdeck/nightfield.sh ~/.config/omarchy/themes/cyberdeck/backgrounds/1-nightfield.png`. That uses the default seed, 7. If the original used another seed, the details will differ. `0-perplexity-hero.png` can only come from the backup.

A theme hook that keeps tmux transparent. Omarchy's theme switcher paints every tmux pane with the theme background, and this hook undoes that. It has to be in place before the theme is applied:

`~/.config/omarchy/hooks/theme-set.d/tmux-transparent`:

```bash
mkdir -p ~/.config/omarchy/hooks/theme-set.d
cat > ~/.config/omarchy/hooks/theme-set.d/tmux-transparent <<'OMARCHY_EOF'
#!/bin/bash
# Keep tmux panes transparent so Ghostty's background-opacity shows through.
#
# omarchy-theme-set-tmux runs just before this hook and paints every pane with
# the theme background in two ways: it sets window-style/window-active-style to
# "bg=<theme background>", and it sends OSC 11 (set background colour) to each
# pane. This undoes only those background parts; the theme's text colours,
# palette and cursor colour are left alone.

tmux list-sessions >/dev/null 2>&1 || exit 0

tmux set-option -g window-style default
tmux set-option -g window-active-style default

# OSC 111 resets a pane's background colour to the terminal default
tmux list-panes -a -F '#{pane_tty}' 2>/dev/null | sort -u | while read -r tty; do
  [[ $tty == /dev/pts/* ]] && printf '\033]111\007' >"$tty" 2>/dev/null
done

tmux list-clients -F '#{client_name}' 2>/dev/null | while read -r client; do
  tmux refresh-client -t "$client" 2>/dev/null
done
exit 0
OMARCHY_EOF
```

A second hook makes tmux and the Starship prompt follow the theme: on every theme switch it writes the new theme's colours into a marked block in `tmux.conf` and `starship.toml` (steps 8 and 9) and reloads tmux. Until those files exist it does nothing.

`~/.config/omarchy/hooks/theme-set.d/theme-colours`:

```bash
cat > ~/.config/omarchy/hooks/theme-set.d/theme-colours <<'OMARCHY_EOF'
#!/bin/bash
# theme-colours (sampsonml, 4 Nov 2026). Omarchy runs this after every theme switch (a
# theme-set hook); run it by hand to re-apply the current theme's colours.
#
# The user wants a theme switch to change colours and nothing else, so the tmux bar and
# the Starship prompt use named colours instead of fixed cyberdeck hex values. This writes
# the current theme's values into the marked block in each file and reloads tmux:
#   ~/.config/tmux/tmux.conf   %hidden THEME_ACCENT="#d08a52" ...  (used as ${THEME_ACCENT})
#   ~/.config/starship.toml    [palettes.theme] theme_accent = "#d08a52" ...
#                              (used as fg:theme_accent; Starship reads it at the next prompt)
#
# Each colour is a key of the theme's colors.toml. pill_background, pane_border and
# subtle_foreground are extra keys only the cyberdeck theme defines (so it stays exactly
# as designed); other themes fall back to selection, selection and dark_foreground.
# Anything missing or malformed falls back to the cyberdeck value.

set -u

COLORS="$HOME/.local/state/omarchy/current/theme/colors.toml"
TMUX_CONF="$HOME/.config/tmux/tmux.conf"
STARSHIP_TOML="$HOME/.config/starship.toml"

[[ -f $COLORS ]] || exit 0

# role  key  fallback-key  cyberdeck-value
ROLES=(
  "accent            accent             -                #d08a52"
  "cyan              cyan               -                #6fb3b8"
  "yellow            yellow             -                #d8c07a"
  "green             green              -                #9fb565"
  "red               red                -                #d9705a"
  "muted             muted              -                #5c6170"
  "background        background         -                #0e0d12"
  "dark_foreground   dark_foreground    -                #9fa39f"
  "pill_background   pill_background    selection        #23263d"
  "pane_border       pane_border        selection        #2e3148"
  "subtle_foreground subtle_foreground  dark_foreground  #8f939f"
)

lookup() {
  local v
  v=$(omarchy-theme-color --file "$COLORS" "$1" 2>/dev/null | tr 'A-F' 'a-f')
  [[ $v =~ ^#[0-9a-f]{6}$ ]] && echo "$v"
}

tmux_block=""
starship_block=""
for spec in "${ROLES[@]}"; do
  read -r role key fallback default <<<"$spec"
  value=$(lookup "$key")
  [[ -z $value && $fallback != - ]] && value=$(lookup "$fallback")
  [[ -z $value ]] && value=$default
  tmux_block+="%hidden THEME_${role^^}=\"$value\""$'\n'
  starship_block+="theme_$role = \"$value\""$'\n'
done

# Replace the lines between the "# >>> theme colours" and "# <<< theme colours" markers.
# Returns 0 if the file changed.
write_block() {
  local file=$1 block=$2 tmp
  [[ -f $file ]] && grep -q '^# >>> theme colours' "$file" || return 1
  tmp=$(mktemp)
  BLOCK="$block" awk '
    /^# >>> theme colours/ { print; printf "%s", ENVIRON["BLOCK"]; skip = 1; next }
    /^# <<< theme colours/ { skip = 0 }
    !skip { print }
  ' "$file" >"$tmp"
  if cmp -s "$tmp" "$file"; then
    rm -f "$tmp"
    return 1
  fi
  cat "$tmp" >"$file"
  rm -f "$tmp"
}

if write_block "$TMUX_CONF" "$tmux_block" && tmux list-sessions >/dev/null 2>&1; then
  tmux source-file "$TMUX_CONF"
fi
write_block "$STARSHIP_TOML" "$starship_block"
exit 0
OMARCHY_EOF
```

```bash
chmod +x ~/.config/omarchy/hooks/theme-set.d/tmux-transparent ~/.config/omarchy/hooks/theme-set.d/theme-colours
```

Apply the theme. This generates the per-app theme files in `~/.local/state/omarchy/current/theme/`; don't edit those by hand.

```bash
omarchy theme set cyberdeck
```

**A second theme, abyss** (4 Nov 2026): made from `fantasy_wallpaper.png`, an underwater scene (a pale seafoam moon glowing through deep teal water). The background, text, accent, cyan and window border come from the picture; the terminal colours are muted, cool versions chosen to sit with the teal. Like every theme, it recolours everything and changes nothing else. `icons.theme` has no trailing newline, like Omarchy's own.

```bash
mkdir -p ~/.config/omarchy/themes/abyss/backgrounds
cp ~/omarchy-assets/fantasy_wallpaper.png ~/.config/omarchy/themes/abyss/backgrounds/
printf 'Yaru-prussiangreen' > ~/.config/omarchy/themes/abyss/icons.theme
cat > ~/.config/omarchy/themes/abyss/colors.toml <<'OMARCHY_EOF'
# abyss (sampsonml, 4 Nov 2026): taken from backgrounds/fantasy_wallpaper.png (an
# underwater scene signed Derek Rudy, from ~/Downloads): a pale seafoam moon glowing
# through deep teal water, navy-black at the edges. The background, text, accent, cyan
# and borders come straight from the picture (its main colours run #010718 → #032a32 →
# #04a5a1 → #2faf9f). The picture has no reds, yellows or purples, so the terminal colours
# are muted, cool versions chosen to sit with the teal; all at least 6:1 on the background.
mode = "dark"

accent = "#38bfa6"             # the moon
selection = "#0c3a44"
muted = "#4f7479"
background = "#03141e"         # deep water at the edges
dark_background = "#020e18"
darker_background = "#010915"
lighter_background = "#082530"
foreground = "#cfe9e3"         # moonlight on the surface
dark_foreground = "#8fb5ae"
light_foreground = "#e0f3ef"
bright_foreground = "#f0faf8"

red = "#e57c72"
green = "#79cf8e"
yellow = "#d9c47f"
orange = "#e3a065"
blue = "#5aa6e3"
magenta = "#a492e3"
cyan = "#15b3bc"               # the glow under the moon
brown = "#8c6c4c"
bright_red     = "#f09a91"
bright_green   = "#9fe0ae"
bright_yellow  = "#ead79f"
bright_blue    = "#83bdee"
bright_magenta = "#c0b2ef"
bright_cyan    = "#55d0d6"

# Window border: the moon's seafoam into sea blue, like the light falling into the water.
hyprland_active_border = "rgba(38bfa6ee) rgba(5aa6e3ee) 45deg"
hyprland_inactive_border = "rgba(0c3a44aa)"

# Extra roles for the tmux bar and Starship prompt, written into them by
# ~/.config/omarchy/hooks/theme-set.d/theme-colours (see the cyberdeck theme).
pill_background = "#0a2e38"
pane_border = "#103a42"
subtle_foreground = "#7fa29e"
OMARCHY_EOF
```

Switch to it with `omarchy theme set abyss` (or the theme menu), and back with `omarchy theme set cyberdeck`.

**A third theme, graveyard** (5 Nov 2026): made from `graveyard.png`, a pixel-art night graveyard (a mausoleum in a teal forest, the path in front of it lit yellow-green, mint sky behind). The saved wallpaper is already the 3× upscale (4368×2448, point filter, so the pixels stay sharp); if you only have the original 1456×816 picture, recreate it with `magick graveyard.png -filter point -resize 300% PNG8:<theme>/backgrounds/graveyard.png`. The accent is the glowing grass, cyan the sky, and the window border runs from one to the other.

```bash
mkdir -p ~/.config/omarchy/themes/graveyard/backgrounds
cp ~/omarchy-assets/graveyard.png ~/.config/omarchy/themes/graveyard/backgrounds/
printf 'Yaru-olive' > ~/.config/omarchy/themes/graveyard/icons.theme
cat > ~/.config/omarchy/themes/graveyard/colors.toml <<'OMARCHY_EOF'
# graveyard (sampsonml, 5 Nov 2026): taken from backgrounds/graveyard.png (from
# ~/Downloads, a pixel-art night graveyard: a mausoleum in a teal forest, the path in front
# of it lit yellow-green, mint sky behind; upscaled 3x with a point filter so the pixels
# stay sharp). The background, text, accent, cyan, borders and brown come straight from the
# picture (its main colours run #080d1b -> #193845 -> #2d6a66 -> #40a094 -> #6cd2bd, with
# #dddd85 in the grass and #63423b / #765e47 in the tree trunk). The red, blue and magenta
# aren't in it, so they are muted versions chosen to sit with the teal; all text colours
# are at least 6:1 on the background except muted (dim text) and brown.
mode = "dark"

accent = "#d6d97c"             # the glowing grass on the path
selection = "#173640"
muted = "#56746e"
background = "#0a101c"         # the night sky and shadows
dark_background = "#070c16"
darker_background = "#050811"
lighter_background = "#122030"
foreground = "#d5e4dc"         # moonlit stone
dark_foreground = "#8fa79f"
light_foreground = "#e2eee8"
bright_foreground = "#f1f7f3"

red = "#d97a66"
green = "#94c27a"              # the moss
yellow = "#dcb86a"             # the gold berries
orange = "#e0995c"
blue = "#6ea4d4"
magenta = "#b195cc"
cyan = "#6cd2bd"               # the sky behind the mausoleum
brown = "#9a7550"              # the tree trunk
bright_red     = "#eb9b8a"
bright_green   = "#b3d89c"
bright_yellow  = "#ebd193"
bright_blue    = "#93bde3"
bright_magenta = "#c9b3de"
bright_cyan    = "#9ae6d4"

# Window border: the lit grass into the mint sky, the two lights in the picture.
hyprland_active_border = "rgba(d6d97cee) rgba(6cd2bdee) 45deg"
hyprland_inactive_border = "rgba(173640aa)"

# Extra roles for the tmux bar and Starship prompt, written into them by
# ~/.config/omarchy/hooks/theme-set.d/theme-colours (see the cyberdeck theme).
pill_background = "#122434"
pane_border = "#1b3542"
subtle_foreground = "#7d948e"
OMARCHY_EOF
```

Switch to it with `omarchy theme set graveyard`.

---

## 5. Ghostty

Ghostty is 80% opaque with blur, uses Iosevka Nerd Font Mono, and sends Shift+Enter and Alt+Shift+Enter as distinct key codes so TUIs and tmux can tell them apart. The font size line is overridden by a small state file that the autosize script below writes: 11 on the laptop alone, 14 when an external monitor is on.

`~/.config/ghostty/config`:

```bash
mkdir -p ~/.config/ghostty
cat > ~/.config/ghostty/config <<'OMARCHY_EOF'
# Dynamic theme colors
config-file = ?"~/.local/state/omarchy/current/theme/ghostty.conf"

#opacity
background-opacity = 0.8
background-blur = true

# Font
font-family = "Iosevka Nerd Font Mono"
font-style = Regular
font-size = 11
# Overrides the size above with one that suits the connected monitor.
# Written by ~/.local/bin/ghostty-font-autosize; edit sizes there, not here.
config-file = ?"~/.local/state/ghostty/font-size.conf"

# Window
window-theme = ghostty
window-padding-x = 14
window-padding-y = 14
confirm-close-surface=false
resize-overlay = never
gtk-toolbar-style = flat

# Cursor styling
cursor-style = "block"
cursor-style-blink = false

# Cursor styling + SSH session terminfo
# (all shell integration options must be passed together)
shell-integration-features = no-cursor,ssh-env

# Keyboard bindings
keybind = shift+insert=paste_from_clipboard
keybind = control+insert=copy_to_clipboard
# Send Shift+Enter as CSI-u so TUIs can distinguish it from Enter.
keybind = shift+enter=csi:13;2u
# Legacy encoding sends Alt+Shift+Enter the same as Alt+Enter; send CSI-u so tmux can match M-S-Enter.
keybind = alt+shift+enter=csi:13;4u
keybind = super+control+shift+alt+arrow_down=resize_split:down,100
keybind = super+control+shift+alt+arrow_up=resize_split:up,100
keybind = super+control+shift+alt+arrow_left=resize_split:left,100
keybind = super+control+shift+alt+arrow_right=resize_split:right,100

# Slowdown mouse scrolling
mouse-scroll-multiplier = 0.95

# Fix general slowness on hyprland (https://github.com/ghostty-org/ghostty/discussions/3224)
async-backend = epoll
OMARCHY_EOF
```

`~/.local/bin/ghostty-font-autosize`:

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/ghostty-font-autosize <<'OMARCHY_EOF'
#!/bin/bash
# Set Ghostty's font size from the monitors that are switched on, and reload
# Ghostty if the size changed. Hyprland runs this when a monitor is added or
# removed (see ~/.config/hypr/monitors.lua), so closing the lid onto an
# external display or unplugging it switches the size automatically.
#
# Ghostty has one font size for all windows, so when an external monitor is on,
# its size wins over the laptop's.

LAPTOP_SIZE=11

# Size for an external monitor, matched on its description from `hyprctl monitors`.
external_size() {
  case "$1" in
    "LG Electronics LG Ultra HD"*) echo 14 ;;
    *) echo 14 ;; # any other external monitor
  esac
}

OUT="$HOME/.local/state/ghostty/font-size.conf"

size=""
while IFS=$'\t' read -r name desc; do
  [[ $name == eDP* ]] && continue
  s=$(external_size "$desc")
  ((s > ${size:-0})) && size=$s
done < <(hyprctl monitors -j | jq -r '.[] | [.name, .description] | @tsv')
size=${size:-$LAPTOP_SIZE}

line="font-size = $size"
[[ -f $OUT && $(<"$OUT") == "$line" ]] && exit 0

mkdir -p "${OUT%/*}"
echo "$line" >"$OUT"
pkill -SIGUSR2 -x ghostty || true
OMARCHY_EOF
```

```bash
chmod +x ~/.local/bin/ghostty-font-autosize
```

```bash
~/.local/bin/ghostty-font-autosize     # writes ~/.local/state/ghostty/font-size.conf
omarchy restart terminal
```

Hyprland runs the script whenever a monitor is added or removed (step 6). To change the sizes, edit `LAPTOP_SIZE` / `external_size()` in the script.

---

## 6. Hyprland

Omarchy's `~/.config/hypr/hyprland.lua` loads its defaults and then these user files. Four of them are customized. `autostart.lua` and `hyprland.lua` stay stock.

**Shortcuts** (`bindings.lua`). These replace Omarchy's HEY shortcuts:

| Keys | Opens |
|---|---|
| `Super+Shift+C` | Google Calendar (personal) |
| `Super+Shift+Alt+C` | Princeton Calendar |
| `Super+Shift+L` | Overleaf |
| `Super+Shift+E` | Thunderbird |
| `Super+Shift+Alt+E` | New Thunderbird message |
| `Super+Shift+R` | arxiv-digest web app (needs its launcher entry, step 11) |

`Super+D` (new, not a replacement) opens the deep-work menu from step 7.4.

Each app shortcut opens the app, or switches to it if it's already open. The two calendars use different URL paths (`/calendar/u/0/r` and `/calendar/r`) because Chromium names web-app windows from the URL path, which is how the shortcut finds the right window. `?authuser=` picks the Google account.

`~/.config/hypr/bindings.lua`:

```bash
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/bindings.lua <<'OMARCHY_EOF'
-- Keep only your personal keybinding overrides here. Add new bindings or
-- unbind defaults before replacing them.

-- See current bindings and descriptions:
--   omarchy menu keybindings --print

-- To disable every Omarchy default binding, set this in
-- ~/.config/hypr/hyprland.lua before require("default.hypr.omarchy"), then add
-- only the bindings you want below:
--   omarchy_default_bindings = false

-- To disable all preinstalled app/webapp bindings, set:
--   omarchy_preinstalled_bindings = false

-- Add a new binding.
-- o.bind("SUPER + SHIFT + R", "SSH", "alacritty -e ssh your-server")

-- Change an existing binding by unbinding it first, then binding the key again.
-- This example changes SUPER+SPACE from the launcher to the Omarchy root menu.
-- hl.unbind("SUPER + SPACE")
-- o.bind("SUPER + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Disable a default binding without replacing it.
-- hl.unbind("SUPER + SHIFT + B")

-- Logitech MX Keys examples:
-- o.bind("SUPER + SHIFT + S", nil, "omarchy-capture-screenshot")
-- o.bind("SUPER + H", nil, "voxtype record toggle")
-- o.bind("SUPER + PERIOD", nil, "omarchy-shell shell toggle omarchy.emojis")

-- Calendars, Overleaf and email (replaces Omarchy's HEY bindings; Thunderbird is the mail app).
-- Each launches the app, or focuses its window if it's already open. The webapp
-- patterns match Chromium's window class, which comes from the URL path.
hl.unbind("SUPER + SHIFT + C")
hl.unbind("SUPER + SHIFT + E")
hl.unbind("SUPER + SHIFT + ALT + E")
o.bind("SUPER + SHIFT + C", "Calendar", o.launch_webapp_sole(
  "calendar\\.google\\.com__calendar_u_0_r",
  "https://calendar.google.com/calendar/u/0/r?authuser=msampsonroko@gmail.com"))
o.bind("SUPER + SHIFT + ALT + C", "Princeton Calendar", o.launch_webapp_sole(
  "calendar\\.google\\.com__calendar_r",
  "https://calendar.google.com/calendar/r?authuser=ms0821@princeton.edu"))
o.bind("SUPER + SHIFT + L", "Overleaf", o.launch_webapp_sole(
  "www\\.overleaf\\.com__project",
  "https://www.overleaf.com/project"))
o.bind("SUPER + SHIFT + E", "Email", { launch = "thunderbird", focus = "org\\.mozilla\\.Thunderbird" })
o.bind("SUPER + SHIFT + ALT + E", "New email", { launch = "thunderbird -compose" })

-- arxiv-digest web app (R for research). Runs the launcher entry that
-- `arxiv-digest shortcut install` created: opens the app in the browser,
-- starting it in the background if it isn't running.
o.bind("SUPER + SHIFT + R", "arXiv digest", { launch = "arxiv-digest.desktop" })

-- Deep-work mode (added 4 Nov 2026; D for deep). Opens the deep-work menu: pick a
-- length, or end, extend or pause the running session. The sampsonml.deepwork shell
-- plugin (~/.config/omarchy/plugins/sampsonml.deepwork/) does the work.
o.bind("SUPER + D", "Deep work", os.getenv("HOME") .. "/.local/bin/deepwork")
OMARCHY_EOF
```

**Look** (`looknfeel.lua`): slightly rounded corners (5; the shell's menus, notifications and the bar frame follow the same value) and a faint glow in the theme's accent (copper) behind the focused window. The border's copper → teal gradient comes from the theme. Terminal opacity is pinned to Omarchy's default, so a theme can't change it. Its rotation animation is left off to save battery. Blur is on for translucent windows and the bar's HUD frame (frosted glass), and switching workspaces is instant (no animation, as in stock Omarchy), as is the scratchpad (its default drop-down slide is turned off). New windows unfold from a thin line like an old monitor switching on (and collapse back when closed), and unfocused windows are dimmed slightly, with the dim fading as focus moves. The deep-work timer bar (step 7.4) is frosted like the bar.

`~/.config/hypr/looknfeel.lua`:

```bash
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/looknfeel.lua <<'OMARCHY_EOF'
-- Change the default Omarchy look'n'feel.

-- https://wiki.hypr.land/Configuring/Basics/Variables/#general
-- hl.config({
--   general = {
--     -- No gaps between windows or borders.
--     gaps_in = 0,
--     gaps_out = 0,
--     border_size = 0,
--
--     -- Change to niri-like side-scrolling layout.
--     layout = "scrolling",
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#decoration
-- hl.config({
--   decoration = {
--     -- Use round window corners.
--     rounding = 8,
--
--     -- Dim unfocused windows (0.0 = no dim, 1.0 = fully dimmed).
--     dim_inactive = true,
--     dim_strength = 0.15,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#animations
-- hl.config({
--   animations = {
--     -- Disable all animations.
--     enabled = false,
--   },
-- })

-- https://wiki.hypr.land/Configuring/Basics/Variables/#layout
-- hl.config({
--   layout = {
--     -- Avoid overly wide single-window layouts on wide screens.
--     single_window_aspect_ratio = { 1, 1 },
--   },
-- })

-- https://wiki.hypr.land/Configuring/Layouts/Scrolling-Layout/
-- hl.config({
--   scrolling = {
--     -- See only one column per screen instead of two.
--     column_width = 0.97,
--   },
-- })

-- Theme colours (sampsonml, 4 Nov 2026; the user wants a theme switch to change colours
-- and nothing else): the focused window's glow uses the theme's accent (it was a fixed
-- copper), read from the current theme's colors.toml. Switching theme reloads Hyprland,
-- which runs this again.
local function theme_color(key, fallback)
  local f = io.open(os.getenv("HOME") .. "/.local/state/omarchy/current/theme/colors.toml", "r")
  if not f then return fallback end
  local text = "\n" .. f:read("*a")
  f:close()
  return text:match("\n%s*" .. key .. "%s*=%s*[\"']?#(%x%x%x%x%x%x)") or fallback
end
local glow = theme_color("accent", "d08a52")

-- Cyberdeck look (pairs with the "cyberdeck" Omarchy theme; border colours come from the theme).
hl.config({
  decoration = {
    -- Slightly rounded corners (5; on 4 Nov 2026 the user asked for 2, then 5; it was 0 =
    -- square). The Omarchy shell copies this value for its own corners (Style.cornerRadius:
    -- menus, notifications, panels, the lock screen), and the bar's HUD frame uses it too.
    -- A theme's hyprland.lua loads before this file, so this wins over a theme's rounding.
    rounding = 5,

    -- Soft glow in the theme's accent (copper in cyberdeck) behind the focused window;
    -- none behind the others.
    shadow = {
      enabled = true,
      range = 8,
      render_power = 3,
      color = "rgba(" .. glow .. "10)",
      color_inactive = "rgba(00000000)",
    },

    -- Focus spotlight (added 3 Nov 2026): unfocused windows are dimmed slightly, and the
    -- dim fades smoothly when focus moves (the fadeDim animation below).
    dim_inactive = true,
    dim_strength = 0.12,

    -- Frosted glass behind translucent windows (Ghostty is at 0.8 opacity) and the bar
    -- (added 3 Nov 2026; Omarchy's default has blur off). xray blurs only the wallpaper,
    -- never the windows underneath, so Hyprland can cache the blur and it stays cheap on
    -- battery. Tiled windows never overlap, so it only changes how floating windows look.
    blur = {
      enabled = true,
      size = 6,
      passes = 2,
      xray = true,
    },
  },
})

-- Frost the bar's HUD frame too. ignore_alpha skips the fully transparent gaps around
-- the frame, so only the frame itself is blurred. The frame fill is 0.35 alpha
-- (hudFillAlpha in ~/.config/omarchy/plugins/sampsonml.bar/Bar.qml), so keep this
-- threshold below that or the frame stops being blurred.
hl.layer_rule({ match = { namespace = "omarchy-bar" }, blur = true, ignore_alpha = 0.2 })

-- The deep-work timer bar (sampsonml.deepwork plugin, 4 Nov 2026) takes the bar's place
-- during a session; frost it the same way. Its background is also 0.35 alpha.
hl.layer_rule({ match = { namespace = "sampsonml-deepwork" }, blur = true, ignore_alpha = 0.2 })

-- Workspace switches are not animated: Omarchy's default ("workspaces" disabled) is
-- left alone. On 3 Nov 2026 a slide, pixel dissolves, a slide plus light sweep, a CRT
-- raster and an ember burn were all tried and then removed at the user's request; the
-- shell plugins are archived in ~/.config/omarchy/archive/.
-- The scratchpad (Super+S) isn't animated either: Omarchy's default drop-down slide
-- ("slidevert") is turned off here, also at the user's request.
hl.animation({ leaf = "specialWorkspace", enabled = false })

-- CRT power-on (added 3 Nov 2026): new windows unfold from a thin horizontal line through
-- their middle, like an old monitor switching on, and closing collapses them back to a
-- line. Omarchy's default is "popin 87%" (a small zoom). Opening keeps Omarchy's timing;
-- closing is a little slower than Omarchy's (1.49, linear) so the collapse is visible.
-- The window's opacity still fades in and out alongside (fadeIn / fadeOut, stock).
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.1, bezier = "easeOutQuint", style = "gnomed" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "easeInOutCubic", style = "gnomed" })

-- Focus spotlight: how fast the dim on unfocused windows fades in and out (decoration
-- dim_inactive above). Without this it inherits the generic "fade" speed.
hl.animation({ leaf = "fadeDim", enabled = true, speed = 4, bezier = "easeOutQuint" })

-- Rotating border is off on this laptop to save battery (the copper -> teal gradient stays, just static).
-- To turn it on, uncomment the next line.
-- hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" })

-- Terminal opacity stays Omarchy's default whatever the theme (sampsonml, 4 Nov 2026): a
-- theme's hyprland.lua loads before this file, and Kanagawa's sets terminals to
-- "0.99 0.985". A theme switch should only change colours.
o.window({ tag = "terminal" }, { opacity = "0.985 0.96" })
OMARCHY_EOF
```

**Monitors** (`monitors.lua`): stock auto rule, plus hooks that run the Ghostty font script when monitors change.

`~/.config/hypr/monitors.lua`:

```bash
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/monitors.lua <<'OMARCHY_EOF'
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

local omarchy_gdk_scale = 2
local omarchy_monitor_scale = "auto"

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })

-- Configure a specific monitor.
-- hl.monitor({ output = "DP-2", mode = "2560x1440@144", position = "0x0", scale = 1 })

-- Portrait/rotated secondary monitor (transform: 1 = 90°, 3 = 270°).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })

-- Pick Ghostty's font size for the connected monitor (laptop 11, external 14).
-- Sizes live in ~/.local/bin/ghostty-font-autosize.
local function ghostty_font_autosize()
  hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/ghostty-font-autosize")
end
hl.on("hyprland.start", ghostty_font_autosize)
hl.on("monitor.added", ghostty_font_autosize)
hl.on("monitor.removed", ghostty_font_autosize)
hl.on("monitor.layout_changed", ghostty_font_autosize)
OMARCHY_EOF
```

**Touchpad** (`input.lua`): a faster pointer for the built-in touchpad only (sensitivity 0.4; the default is 0). The TrackPoint and external mice keep the default speed. The device name is specific to this laptop: check it with `hyprctl devices` and change the last line if it differs.

`~/.config/hypr/input.lua`:

```bash
mkdir -p ~/.config/hypr
cat > ~/.config/hypr/input.lua <<'OMARCHY_EOF'
-- Keep only your personal input overrides here. Uncommented settings below
-- replace Omarchy's defaults.

-- Keyboard layout and options.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input
-- hl.config({
--   input = {
--     -- Use multiple keyboard layouts and switch between them with Left Alt + Right Alt.
--     kb_layout = "us,dk,eu",
--     kb_options = "compose:caps,shift:both_capslock_cancel,grp:alts_toggle",
--
--     -- Use a specific keyboard variant if needed (e.g. intl for international keyboards).
--     kb_variant = "intl",
--
--     -- Change speed of keyboard repeat.
--     repeat_rate = 40,
--     repeat_delay = 250,
--
--     -- Start with numlock on by default.
--     numlock_by_default = true,
--
--     -- Increase sensitivity for mouse/trackpad (default: 0).
--     sensitivity = 0.35,
--
--     -- Turn off mouse acceleration (default: adaptive).
--     accel_profile = "flat",
--
--     touchpad = {
--       -- Use natural (inverse) scrolling.
--       natural_scroll = true,
--
--       -- Use two-finger clicks for right-click instead of lower-right corner.
--       clickfinger_behavior = true,
--
--       -- Control the speed of your scrolling.
--       scroll_factor = 0.4,
--
--       -- Enable the touchpad while typing.
--       disable_while_typing = false,
--
--       -- Left-click-and-drag with three fingers.
--       drag_3fg = 1,
--     },
--   },
-- })

-- App-specific touchpad scroll speeds.
-- o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
-- o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })

-- Enable touchpad gestures for changing workspaces.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Gestures/
-- hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- Enable touchpad gestures for moving focus (helpful on scrolling layout).
-- hl.gesture({ fingers = 3, direction = "left", action = function() hl.dispatch(hl.dsp.focus({ direction = "l" })) end })
-- hl.gesture({ fingers = 3, direction = "right", action = function() hl.dispatch(hl.dsp.focus({ direction = "r" })) end })

-- sampsonml: faster pointer for the built-in touchpad only (range -1..1, default 0).
-- The TrackPoint and external mice keep the default speed.
-- Find device names with: hyprctl devices
hl.device({ name = "syna8018:00-06cb:ce67-touchpad", sensitivity = 0.4 })

-- sampsonml: faster pointer for the Apple Magic Trackpad (Bluetooth, added 4 Nov 2026).
-- A bit higher than the built-in touchpad because it's a bigger surface.
hl.device({ name = "apple-inc.-magic-trackpad", sensitivity = 0.5 })
OMARCHY_EOF
```

```bash
hyprctl reload && hyprctl configerrors   # should print nothing after "ok"
```

---

## 7. Omarchy shell: bar, widgets, lock screen

### 7.1 Sizes

The bar icons are a little bigger than stock: `base-size` is 17 (stock 14), and every text size is pinned back to its 14-point value so menus, panels and notifications keep their text size. Bar text (clock, workspace numbers, mortality, power draw) is set 2px smaller, to 12, in those widgets (step 7.2 and 7.3).

`~/.config/omarchy/shell.toml`:

```bash
mkdir -p ~/.config/omarchy
cat > ~/.config/omarchy/shell.toml <<'OMARCHY_EOF'
[font]
# Bar icons, icon spacing and bar height scale with base-size / 12; there is no
# separate icon-size setting. base-size is set to 17 for bar icons of ~18px
# (13 * 17/12). It was 18 (~20px icons) until 3 Nov 2026; stock is 14 (~15px).
# Every text token below is pinned to its base-size 14 value, so text in menus,
# panels and notifications stays the same size. Bar text is set separately,
# 2px below `body`, in the bar modules (clock, workspaces, mortality, power-draw).
base-size = 17
caption = 12
body-small = 13
body = 14
subtitle = 15
title = 16
heading = 19
display = 28
display-large = 33
icon-large = 21

[spacing]
# Spacing grows with base-size too; 14/17 keeps panels, menus and notifications
# at their base-size 14 dimensions.
scale = 0.8235

[bar]
# Bar height at base-size 12; scaled with base-size (20 -> 28px at base-size 17).
# Was 24 (34px) until 3 Nov 2026; lowered to give windows more vertical room.
# Icons and text don't change with it, only the padding around them.
size-horizontal = 20

# These were ignored by the shell (it only reads size-horizontal / size-vertical
# under [bar]); icon sizes come from base-size above.
# icon-size = 18
# icon-canvas = 20
# icon-slot = 32
OMARCHY_EOF
```

### 7.2 Clone the four stock plugins, then patch them

```bash
omarchy plugin clone omarchy.bar          # -> ~/.config/omarchy/plugins/sampsonml.bar
omarchy plugin clone omarchy.workspaces   # -> ~/.config/omarchy/plugins/sampsonml.workspaces
omarchy plugin clone omarchy.lock         # -> ~/.config/omarchy/plugins/sampsonml.lock
omarchy plugin clone omarchy.clock        # -> ~/.config/omarchy/plugins/sampsonml.clock
```

Cloned plugins stop receiving Omarchy updates. That's the trade-off for being able to change them.

The patches below are the exact differences between Omarchy 4.0.6's stock files and this setup's versions. Run each block as it is:
- `patch` prints `patching file …` when it applies cleanly.
- If it reports a **FAILED hunk**, Omarchy's stock file has changed since 4.0.6. Either apply that part by hand (the rejected part is saved next to the file as `*.rej`), or copy the finished file from `~/omarchy-assets/plugins-fallback/` (step 0).

**Bar HUD frame** (`sampsonml.bar/Bar.qml`): a floating frame around horizontal bars with a translucent fill in the theme background (35% opaque), an outline in the same colours as the window border (read from Hyprland, so it follows the theme; copper → teal in cyberdeck), corners rounded like the windows, and a gap from the screen edge that lines up with tiled windows. Tiled windows sit 5px below the frame instead of Hyprland's 10px, because the bar reserves 5px less than its height (`hudWindowGapTrim`). The settings at the top of the HUD block are `hudNotch`, `hudCornerAccents`, `hudFillAlpha`, `hudOutlineAlpha` and `hudWindowGapTrim`.

Patch for `~/.config/omarchy/plugins/sampsonml.bar/Bar.qml`:

```bash
cd ~/.config/omarchy/plugins/sampsonml.bar
patch -p1 <<'OMARCHY_EOF'
--- a/Bar.qml
+++ b/Bar.qml
@@ -4,6 +4,7 @@
 import Quickshell.Wayland
 import QtQuick
 import QtQuick.Layouts
+import QtQuick.Shapes
 import qs.Commons
 import qs.Commons as Commons
 import qs.Ui
@@ -569,10 +570,94 @@
   readonly property bool vertical: position === "left" || position === "right"
   readonly property int barSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
 
+  // --- Cyberdeck HUD frame (sampsonml) ---
+  // Horizontal bars float as a HUD frame: a translucent dark fill inside an
+  // even copper outline with slightly rounded corners (Hyprland's rounding, via
+  // Style.cornerRadius; square until 4 Nov 2026). hudNotch > 0 cuts the corners at
+  // 45° and hudCornerAccents adds bright corner brackets. Vertical
+  // bars keep the stock look. barSize stays the content height (widgets size
+  // themselves from it); the window adds the edge gap on top of that.
+  readonly property bool hudEnabled: !vertical
+  // Gap between screen edge and frame: half the Hyprland window gap, as
+  // Omarchy uses for panels. Sides use the full gap so the frame lines up
+  // with tiled windows below it.
+  readonly property int hudEdgeGap: hudEnabled ? Style.gapsOut : 0
+  readonly property int hudSideGap: hudEnabled ? Style.gapsOut * 2 : 0
+  readonly property int hudOuterSize: barSize + hudEdgeGap
+  // How much closer tiled windows sit to the frame than Hyprland's gaps_out
+  // (10 - 5 = 5px gap below the bar; added 3 Nov 2026). See BarPanel.exclusiveZone.
+  readonly property int hudWindowGapTrim: hudEnabled ? 5 : 0
+  // Corner cut size; 0 gives rounded corners (the accents become L-brackets).
+  readonly property real hudNotch: 0
+  readonly property real hudAccentLength: Math.round(barSize * 0.38)
+  readonly property real hudFillAlpha: 0.35 // was 0.75 until 3 Nov 2026
+  // The outline matches the border Hyprland draws around windows (the user's
+  // request, 4 Nov 2026; until then it was a fixed copper at 0.55): the colours
+  // and angle of general:col.active_border, read with hyprctl at startup and
+  // after every Hyprland config reload (switching theme reloads it), drawn as
+  // the same gradient. So it follows the theme, including a theme's own
+  // hyprland.lua. hudOutlineAlpha scales the border's own opacity (1 = same).
+  property var hudBorderStops: []     // colours, first to last; empty = theme accent
+  property real hudBorderAngle: 0     // degrees, as in Hyprland
+  readonly property real hudOutlineAlpha: 1.0
+  readonly property color hudAccentColor: hudStop(0)
+  // Bright brackets on each corner, in the border colour. Off: the outline is
+  // the same all the way round.
+  readonly property bool hudCornerAccents: false
+  readonly property color hudFill: Qt.rgba(background.r, background.g, background.b, transparent ? 0 : hudFillAlpha)
+
   function normalizePosition(value) {
     return BarModel.normalizePosition(value)
   }
 
+  // sampsonml: the window border's colours (see hudBorderStops).
+  function hudStop(i) {
+    var s = hudBorderStops
+    var c = s && s.length > 0 ? s[Math.min(i, s.length - 1)] : Color.accent
+    return Qt.rgba(c.r, c.g, c.b, c.a * hudOutlineAlpha)
+  }
+
+  function hudStopPosition(i) {
+    var n = hudBorderStops ? hudBorderStops.length : 0
+    return n > 1 ? Math.min(i, n - 1) / (n - 1) : 0
+  }
+
+  // hyprctl's JSON gives the gradient as e.g. "eed08a52 ee6fb3b8 45deg":
+  // colours as AARRGGBB, then the angle.
+  function applyHudBorder(raw) {
+    var stops = []
+    var angle = 0
+    try {
+      String(JSON.parse(raw).gradient || "").split(/\s+/).forEach(function(tok) {
+        var m = tok.match(/^([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})$/)
+        if (m) stops.push(Qt.rgba(parseInt(m[2], 16) / 255, parseInt(m[3], 16) / 255,
+                                  parseInt(m[4], 16) / 255, parseInt(m[1], 16) / 255))
+        else if (/deg$/.test(tok)) angle = parseFloat(tok)
+      })
+    } catch (e) {
+      return
+    }
+    if (stops.length === 0) return
+    hudBorderStops = stops
+    hudBorderAngle = isFinite(angle) ? angle : 0
+  }
+
+  Process {
+    id: hudBorderQuery
+    running: root.hudEnabled
+    command: ["hyprctl", "getoption", "general:col.active_border", "-j"]
+    stdout: StdioCollector {
+      onStreamFinished: root.applyHudBorder(text)
+    }
+  }
+
+  Connections {
+    target: Hyprland
+    function onRawEvent(event) {
+      if (event.name === "configreloaded" && root.hudEnabled) hudBorderQuery.running = true
+    }
+  }
+
   // Apply tray-pinning on top of the shared layout normalization so the
   // bar host and scriptable config helpers can't drift on entry shape.
   function normalizeLayout(layout) {
@@ -1254,7 +1339,15 @@
     // textures — which measures ~150ms against ~20ms to tear down. Parking
     // keeps the surface alive, so showing is only a margin change.
     visible: !remapGuard.remapping
-    exclusionMode: root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Auto
+    // sampsonml: reserve hudWindowGapTrim px less than the bar window's height,
+    // so tiled windows sit closer to a horizontal bar (gap 10 -> 5) without
+    // changing Hyprland's gaps_out. A per-side gaps_out ("5 10 10 10") would
+    // also do it, but the shell takes its edge gap (Style.gapsOut) from the
+    // first, top value, which would shrink panel/notification margins and the
+    // HUD side gap. Setting exclusiveZone switches the mode to Normal, so the
+    // zone is 0 while hidden. Stock: exclusionMode Ignore when hidden, else Auto.
+    exclusionMode: root.barHidden ? ExclusionMode.Ignore : ExclusionMode.Normal
+    exclusiveZone: root.barHidden ? 0 : (root.vertical ? root.barSize : root.hudOuterSize - root.hudWindowGapTrim)
 
     ScreenMoveRemap {
       id: remapGuard
@@ -1262,8 +1355,8 @@
     }
 
     margins {
-      top: root.barHidden && root.position === "top" ? -root.barSize : 0
-      bottom: root.barHidden && root.position === "bottom" ? -root.barSize : 0
+      top: root.barHidden && root.position === "top" ? -root.hudOuterSize : 0
+      bottom: root.barHidden && root.position === "bottom" ? -root.hudOuterSize : 0
       left: root.barHidden && root.position === "left" ? -root.barSize : 0
       right: root.barHidden && root.position === "right" ? -root.barSize : 0
     }
@@ -1276,14 +1369,108 @@
     }
 
     implicitWidth: root.vertical ? root.barSize : 0
-    implicitHeight: root.vertical ? 0 : root.barSize
-    color: root.transparent ? "transparent" : root.background
+    implicitHeight: root.vertical ? 0 : root.hudOuterSize
+    color: root.hudEnabled || root.transparent ? "transparent" : root.background
     surfaceFormat.opaque: false
     WlrLayershell.namespace: "omarchy-bar"
     WlrLayershell.layer: WlrLayer.Top
+    // Only the frame takes input; the gaps around it click through.
+    mask: Region { item: hudFrame }
+
+    // The HUD frame. In vertical mode it fills the window and draws nothing.
+    Item {
+      id: hudFrame
+      x: root.hudSideGap
+      y: root.position === "bottom" ? 0 : root.hudEdgeGap
+      width: parent.width - root.hudSideGap * 2
+      height: root.vertical ? parent.height : root.barSize
+
+      Shape {
+        id: hudShape
+        anchors.fill: parent
+        visible: root.hudEnabled
+        preferredRendererType: Shape.CurveRenderer
+
+        readonly property real w: width
+        readonly property real h: height
+        readonly property real n: root.hudNotch
+        // The border gradient's line across the frame, as Hyprland lays it across a
+        // window: from the first colour to the last along the angle.
+        readonly property real ga: root.hudBorderAngle * Math.PI / 180
+        readonly property real gl: Math.abs(w * Math.cos(ga)) + Math.abs(h * Math.sin(ga))
+        // Corner rounding, as for windows (ignored when hudNotch cuts the corners).
+        readonly property real r: root.hudNotch > 0 ? 0 : Math.min(Style.cornerRadius, h / 2)
+        readonly property real c: root.hudNotch > 0 ? n : r + o  // where each corner starts
+        readonly property real a: root.hudAccentLength
+        // Inset half a pixel so 1px strokes land on whole pixels.
+        readonly property real o: 0.5
+
+        // Fill and dim outline: a rectangle with rounded corners, or corners cut at 45°
+        // when hudNotch > 0 (an arc with radius 0 is a straight line).
+        ShapePath {
+          fillColor: root.hudFill
+          strokeColor: root.hudStop(0)
+          strokeGradient: LinearGradient {
+            x1: hudShape.w / 2 - Math.cos(hudShape.ga) * hudShape.gl / 2
+            y1: hudShape.h / 2 - Math.sin(hudShape.ga) * hudShape.gl / 2
+            x2: hudShape.w / 2 + Math.cos(hudShape.ga) * hudShape.gl / 2
+            y2: hudShape.h / 2 + Math.sin(hudShape.ga) * hudShape.gl / 2
+            // Up to four colours (Omarchy's themes use one or two).
+            GradientStop { position: root.hudStopPosition(0); color: root.hudStop(0) }
+            GradientStop { position: root.hudStopPosition(1); color: root.hudStop(1) }
+            GradientStop { position: root.hudStopPosition(2); color: root.hudStop(2) }
+            GradientStop { position: root.hudStopPosition(3); color: root.hudStop(3) }
+          }
+          strokeWidth: 1
+          joinStyle: ShapePath.MiterJoin
+          startX: hudShape.c; startY: hudShape.o
+          PathLine { x: hudShape.w - hudShape.c; y: hudShape.o }
+          PathArc { x: hudShape.w - hudShape.o; y: hudShape.c; radiusX: hudShape.r; radiusY: hudShape.r }
+          PathLine { x: hudShape.w - hudShape.o; y: hudShape.h - hudShape.c }
+          PathArc { x: hudShape.w - hudShape.c; y: hudShape.h - hudShape.o; radiusX: hudShape.r; radiusY: hudShape.r }
+          PathLine { x: hudShape.c; y: hudShape.h - hudShape.o }
+          PathArc { x: hudShape.o; y: hudShape.h - hudShape.c; radiusX: hudShape.r; radiusY: hudShape.r }
+          PathLine { x: hudShape.o; y: hudShape.c }
+          PathArc { x: hudShape.c; y: hudShape.o; radiusX: hudShape.r; radiusY: hudShape.r }
+        }
+
+        // Bright copper accents tracing each corner.
+        ShapePath {
+          fillColor: "transparent"
+          strokeColor: root.hudCornerAccents ? root.hudAccentColor : "transparent"
+          strokeWidth: 1.5
+          joinStyle: ShapePath.MiterJoin
+          capStyle: ShapePath.FlatCap
+          // top-left
+          startX: hudShape.n + hudShape.a; startY: hudShape.o
+          PathLine { x: hudShape.n; y: hudShape.o }
+          PathLine { x: hudShape.o; y: hudShape.n }
+          PathLine { x: hudShape.o; y: Math.min(hudShape.h / 2, hudShape.n + hudShape.a * 0.5) }
+          // top-right
+          PathMove { x: hudShape.w - hudShape.n - hudShape.a; y: hudShape.o }
+          PathLine { x: hudShape.w - hudShape.n; y: hudShape.o }
+          PathLine { x: hudShape.w - hudShape.o; y: hudShape.n }
+          PathLine { x: hudShape.w - hudShape.o; y: Math.min(hudShape.h / 2, hudShape.n + hudShape.a * 0.5) }
+          // bottom-right
+          PathMove { x: hudShape.w - hudShape.n - hudShape.a; y: hudShape.h - hudShape.o }
+          PathLine { x: hudShape.w - hudShape.n; y: hudShape.h - hudShape.o }
+          PathLine { x: hudShape.w - hudShape.o; y: hudShape.h - hudShape.n }
+          PathLine { x: hudShape.w - hudShape.o; y: Math.max(hudShape.h / 2, hudShape.h - hudShape.n - hudShape.a * 0.5) }
+          // bottom-left
+          PathMove { x: hudShape.n + hudShape.a; y: hudShape.h - hudShape.o }
+          PathLine { x: hudShape.n; y: hudShape.h - hudShape.o }
+          PathLine { x: hudShape.o; y: hudShape.h - hudShape.n }
+          PathLine { x: hudShape.o; y: Math.max(hudShape.h / 2, hudShape.h - hudShape.n - hudShape.a * 0.5) }
+        }
+      }
+    }
 
     Loader {
-      anchors.fill: parent
+      // Content sits inside the frame, pulled in past the notched corners.
+      x: hudFrame.x + (root.hudEnabled ? root.hudNotch * 0.5 : 0)
+      y: hudFrame.y
+      width: hudFrame.width - (root.hudEnabled ? root.hudNotch : 0)
+      height: hudFrame.height
       sourceComponent: root.vertical ? verticalBar : horizontalBar
 
       // A child of the loader, not a sibling of the sections: an ancestor stays
OMARCHY_EOF
cd ~
```

**Workspace pills** (`sampsonml.workspaces/Workspaces.qml`): like stock Omarchy, shows workspaces 1–5 always and 6–9 and 10 (labelled "0") only while they're in use. The focused one is filled with the theme accent (copper), occupied ones have a light outline, and empty ones a dim outline, all in theme colours.

Patch for `~/.config/omarchy/plugins/sampsonml.workspaces/Workspaces.qml`:

```bash
cd ~/.config/omarchy/plugins/sampsonml.workspaces
patch -p1 <<'OMARCHY_EOF'
--- a/Workspaces.qml
+++ b/Workspaces.qml
@@ -1,6 +1,7 @@
 import QtQuick
 import QtQuick.Layouts
 import Quickshell.Hyprland
+import Quickshell.Io
 import qs.Commons
 import qs.Ui
 
@@ -17,6 +18,9 @@
     return null
   }
 
+  // Stock Omarchy behaviour (restored 5 Nov 2026 at the user's request; from 2 Nov it
+  // always showed all ten): 1-5 always, and 6-9 and 10 ("0") only while they exist in
+  // Hyprland, i.e. hold windows or are showing on a monitor.
   function workspaceIds() {
     var ids = [1, 2, 3, 4, 5]
     var values = Hyprland.workspaces.values
@@ -37,6 +41,42 @@
 
   readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
 
+  // --- Cyberdeck pills (sampsonml) ---
+  // Every workspace is a rounded pill showing its number, like the tmux window
+  // tabs. The focused one is filled with the theme accent (copper #d08a52 in
+  // cyberdeck); the rest are hollow, outlined in light grey when they have
+  // windows and dim grey when empty. All the colours come from the theme
+  // (fixed cyberdeck values until 4 Nov 2026).
+  readonly property color pillFocused: Color.accent
+  readonly property color pillFocusedText: Color.background
+  readonly property color pillOccupiedBorder: themeColor("dark_foreground", "#9fa39f")
+  readonly property color pillOccupiedText: Color.foreground
+  readonly property color pillEmptyBorder: Color.muted
+  readonly property color pillEmptyText: Color.muted
+
+  // Theme colours the shell's Color doesn't carry (sampsonml, 4 Nov 2026): read from the
+  // current theme's colors.toml, and again whenever the shell applies a theme, so they
+  // follow the theme. The fallbacks are the cyberdeck values.
+  property string themePalette: ""
+  function themeColor(key, fallback) {
+    var m = themePalette.match(new RegExp("^\\s*" + key + "\\s*=\\s*[\"']?(#[0-9A-Fa-f]{6})", "m"))
+    return m ? m[1] : fallback
+  }
+  FileView {
+    id: themeColorsFile
+    path: Color.currentThemePath + "/colors.toml"
+    printErrors: false
+    onLoaded: root.themePalette = text()
+  }
+  Connections {
+    target: Color
+    function onAccentChanged() { themeColorsFile.reload() }
+    function onBackgroundChanged() { themeColorsFile.reload() }
+    function onShellValuesChanged() { themeColorsFile.reload() }
+  }
+  readonly property real pillHeight: Math.round(root.barSize * 0.6)
+  readonly property real pillWidth: Math.round(pillHeight * 1.35)
+
   implicitWidth: grid.implicitWidth + trailingGap
   implicitHeight: grid.implicitHeight
 
@@ -45,7 +85,7 @@
     anchors.fill: parent
     anchors.rightMargin: root.trailingGap
     columns: root.vertical ? 1 : root.workspaceIds().length
-    columnSpacing: root.vertical ? 0 : Style.space(1)
+    columnSpacing: root.vertical ? 0 : Style.space(4)
     rowSpacing: root.vertical ? Style.space(2) : 0
 
     Repeater {
@@ -58,14 +98,30 @@
         readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
         readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData
 
+        id: wsButton
         bar: root.bar
-        text: focused ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData))
-        opacity: occupied || focused ? 1 : 0.5
+        text: modelData === 10 ? "0" : String(modelData)
+        foreground: focused ? root.pillFocusedText : (occupied ? root.pillOccupiedText : root.pillEmptyText)
+        // sampsonml: bar text 2px below the shared body token (14 -> 12, 3 Nov 2026).
+        fontSize: Style.font.body - 2
         horizontalMargin: 6
         verticalPadding: 6
-        fixedWidth: root.vertical ? root.barSize : Style.space(20)
-        fixedHeight: root.barSize
+        fixedWidth: root.vertical ? root.barSize : root.pillWidth
+        fixedHeight: root.vertical ? root.pillHeight + Style.space(2) : root.barSize
         onPressed: function() { root.focusWorkspace(modelData) }
+
+        Rectangle {
+          z: -1
+          anchors.centerIn: parent
+          width: root.pillWidth
+          height: root.pillHeight
+          radius: height / 2
+          color: wsButton.focused ? root.pillFocused : "transparent"
+          border.width: wsButton.focused ? 0 : 1
+          border.color: wsButton.occupied ? root.pillOccupiedBorder : root.pillEmptyBorder
+
+          Behavior on color { ColorAnimation { duration: 140 } }
+        }
       }
     }
   }
OMARCHY_EOF
cd ~
```

**Clock** (`sampsonml.clock/BarWidget.qml`): the only change is a bar font 2px below the shared `body` size (12 instead of 14), to match the other bar text. The calendar popup is unchanged. The clone has to be the bar's `centerAnchor` (set in `shell.json`, step 7.6), or the clock stops being centred.

Patch for `~/.config/omarchy/plugins/sampsonml.clock/BarWidget.qml`:

```bash
cd ~/.config/omarchy/plugins/sampsonml.clock
patch -p1 <<'OMARCHY_EOF'
--- a/BarWidget.qml
+++ b/BarWidget.qml
@@ -145,6 +145,9 @@
     bar: root.bar
     text: root.vertical ? "" : root.displayText
     labelVisible: !root.vertical
+    // sampsonml: bar text 2px below the shared body token (14 -> 12, 3 Nov 2026).
+    // The only change in this clone; everything else is stock omarchy.clock 4.0.6.
+    fontSize: Style.font.body - 2
     hasVisualContent: root.vertical ? root.verticalLines.length > 0 : text !== ""
     fixedHeight: root.vertical ? root.verticalLines.length * Style.bar.iconSlot : -1
     horizontalMargin: 8.75
OMARCHY_EOF
cd ~
```

**Lock screen** (`sampsonml.lock/LockView.qml`):
- a large HUD clock with date, ISO week and battery (`MON 02 NOV 2026 · W45 · 󰂁 92%`)
- a terminal-style status line (`SYSTEM LOCKED // THINK-BEAST`, plus a failed-attempt count)
- a blinking cursor
- no wallpaper blur

The patch changes only what's displayed, not the password or fingerprint handling.

Patch for `~/.config/omarchy/plugins/sampsonml.lock/LockView.qml`:

```bash
cd ~/.config/omarchy/plugins/sampsonml.lock
patch -p1 <<'OMARCHY_EOF'
--- a/LockView.qml
+++ b/LockView.qml
@@ -1,5 +1,7 @@
 import QtQuick
 import QtQuick.Effects
+import Quickshell.Io
+import Quickshell.Services.UPower
 import qs.Commons
 import qs.Commons as Commons
 import qs.Ui
@@ -39,6 +41,89 @@
     ? Border.surfaceSpec("lock", "border-error", Commons.Color.lock.borderError, root.outlineThickness, "border-alpha")
     : Border.surfaceSpec("lock", "border-active", Commons.Color.lock.borderActive, root.outlineThickness, "border-alpha")
 
+  // --- Cyberdeck additions: HUD clock + terminal-style status line ---------
+  // Display-only; nothing here touches the password field or authentication.
+  property var now: new Date()
+  property bool cursorOn: true
+  property string hostName: "LOCALHOST"
+  readonly property string statusText: authenticatingPassword ? "VERIFYING…"
+    : errorState ? "ACCESS DENIED · ATTEMPT " + failedAttempts
+    : passwordInput.text.length > 0 ? "AUTHENTICATING…"
+    : "SYSTEM LOCKED // " + hostName + (failedAttempts > 0 ? " · " + failedAttempts + " FAILED" : "")
+
+  // Battery level for the HUD date row (display only). Hidden on machines
+  // without a battery. Icons match Omarchy's power widget (Model.js).
+  readonly property var battery: UPower.displayDevice
+  readonly property bool batteryPresent: !!(battery && battery.isPresent)
+  readonly property int batteryPercent: batteryPresent
+    ? Math.round(Math.max(0, Math.min(1, battery.percentage)) * 100) : 0
+  readonly property bool batteryPluggedIn: batteryPresent && !UPower.onBattery
+  readonly property bool batteryLow: batteryPresent && UPower.onBattery && batteryPercent <= 15
+  readonly property color batteryTeal: themeColor("cyan", "#6fb3b8")  // the theme's cyan
+
+  // Theme colours the shell's Color doesn't carry (sampsonml, 4 Nov 2026): read from the
+  // current theme's colors.toml, and again whenever the shell applies a theme, so they
+  // follow the theme. The fallbacks are the cyberdeck values.
+  property string themePalette: ""
+  function themeColor(key, fallback) {
+    var m = themePalette.match(new RegExp("^\\s*" + key + "\\s*=\\s*[\"']?(#[0-9A-Fa-f]{6})", "m"))
+    return m ? m[1] : fallback
+  }
+  FileView {
+    id: themeColorsFile
+    path: Color.currentThemePath + "/colors.toml"
+    printErrors: false
+    onLoaded: root.themePalette = text()
+  }
+  Connections {
+    target: Color
+    function onAccentChanged() { themeColorsFile.reload() }
+    function onBackgroundChanged() { themeColorsFile.reload() }
+    function onShellValuesChanged() { themeColorsFile.reload() }
+  }
+  readonly property string batteryIcon: {
+    if (!batteryPresent) return ""
+    if (battery.state === UPowerDeviceState.FullyCharged) return "󰂅"
+    var index = Math.max(0, Math.min(9, Math.floor(battery.percentage * 10)))
+    var charging = ["󰢜", "󰂆", "󰂇", "󰂈", "󰢝", "󰂉", "󰢞", "󰂊", "󰂋", "󰂅"]
+    var normal = ["󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]
+    return batteryPluggedIn ? charging[index] : normal[index]
+  }
+
+  // ISO-8601 week number (Qt's date formats don't have one)
+  function isoWeek(d) {
+    var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
+    var day = t.getUTCDay() || 7
+    t.setUTCDate(t.getUTCDate() + 4 - day)
+    var yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
+    return Math.ceil(((t - yearStart) / 86400000 + 1) / 7)
+  }
+
+  FileView {
+    id: hostFile
+    path: "/etc/hostname"
+    onLoaded: {
+      var h = hostFile.text().trim()
+      if (h.length > 0) root.hostName = h.toUpperCase()
+    }
+  }
+
+  Timer {
+    interval: 1000
+    running: root.visible
+    repeat: true
+    triggeredOnStart: true
+    onTriggered: root.now = new Date()
+  }
+
+  Timer {
+    interval: 530
+    running: root.visible
+    repeat: true
+    onTriggered: root.cursorOn = !root.cursorOn
+  }
+  // -------------------------------------------------------------------------
+
   signal submitPassword(string password)
   signal passwordTextEdited(string password)
   signal clearFailureRequested()
@@ -106,7 +191,7 @@
       anchors.fill: wallpaper
       source: wallpaper
       autoPaddingEnabled: false
-      blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
+      blurEnabled: false
       blur: 1.0
       blurMax: 128
       blurMultiplier: 1.25
@@ -120,6 +205,120 @@
       onPositionChanged: root.wakeRequested()
     }
 
+    // Cyberdeck: large HUD clock with date and ISO week, above the password field
+    Column {
+      id: hudClock
+      anchors.horizontalCenter: parent.horizontalCenter
+      anchors.bottom: inputField.top
+      anchors.bottomMargin: 56
+      spacing: 4
+      layer.enabled: true
+      layer.effect: MultiEffect {
+        shadowEnabled: true
+        shadowColor: "#d0000000"
+        shadowBlur: 0.8
+        shadowVerticalOffset: 2
+        shadowHorizontalOffset: 0
+      }
+
+      Text {
+        anchors.horizontalCenter: parent.horizontalCenter
+        textFormat: Text.PlainText
+        text: Qt.formatDateTime(root.now, "HH:mm")
+        color: Commons.Color.lock.text
+        font.family: Style.font.family
+        font.pixelSize: Math.round(Style.font.display * 4)
+        font.weight: Font.Light
+        font.letterSpacing: 4
+      }
+
+      Row {
+        anchors.horizontalCenter: parent.horizontalCenter
+        spacing: 12
+
+        Text {
+          textFormat: Text.PlainText
+          text: Qt.formatDateTime(root.now, "ddd dd MMM yyyy").toUpperCase()
+          color: Commons.Color.lock.text
+          opacity: 0.85
+          font.family: Style.font.family
+          font.pixelSize: Style.font.heading
+          font.letterSpacing: 3
+        }
+        Text {
+          textFormat: Text.PlainText
+          text: "·"
+          color: Commons.Color.accent
+          font.family: Style.font.family
+          font.pixelSize: Style.font.heading
+        }
+        Text {
+          textFormat: Text.PlainText
+          text: "W" + root.isoWeek(root.now)
+          color: Commons.Color.accent
+          font.family: Style.font.family
+          font.pixelSize: Style.font.heading
+          font.letterSpacing: 3
+        }
+        // Battery: teal while plugged in, red at 15% or less on battery.
+        Text {
+          visible: root.batteryPresent
+          textFormat: Text.PlainText
+          text: "·"
+          color: Commons.Color.accent
+          font.family: Style.font.family
+          font.pixelSize: Style.font.heading
+        }
+        Text {
+          visible: root.batteryPresent
+          textFormat: Text.PlainText
+          text: root.batteryIcon + " " + root.batteryPercent + "%"
+          color: root.batteryLow ? Commons.Color.lock.textError
+            : root.batteryPluggedIn ? root.batteryTeal
+            : Commons.Color.lock.text
+          opacity: root.batteryLow || root.batteryPluggedIn ? 1.0 : 0.85
+          font.family: Style.font.family
+          font.pixelSize: Style.font.heading
+          font.letterSpacing: 3
+        }
+      }
+    }
+
+    // Cyberdeck: dark backing so the status line stays readable over bright wallpaper
+    Rectangle {
+      anchors.centerIn: statusLine
+      width: statusLine.implicitWidth + 28
+      height: statusLine.implicitHeight + 12
+      color: Commons.Color.lock.background
+      opacity: 0.75
+      radius: Style.cornerRadius
+    }
+
+    // Cyberdeck: terminal-style status line under the password field
+    Text {
+      id: statusLine
+      anchors.horizontalCenter: parent.horizontalCenter
+      anchors.top: inputField.bottom
+      anchors.topMargin: 18
+      textFormat: Text.PlainText
+      text: root.statusText + ((root.errorState || root.authenticatingPassword) ? "" : (root.cursorOn ? " ▮" : "  "))
+      color: root.errorState ? Commons.Color.lock.textError
+        : (root.authenticatingPassword || passwordInput.text.length > 0) ? Commons.Color.accent
+        : Commons.Color.lock.text
+      opacity: (root.errorState || root.authenticatingPassword || passwordInput.text.length > 0) ? 1.0 : 0.8
+      font.family: Style.font.family
+      font.pixelSize: Style.font.subtitle
+      font.letterSpacing: 2.5
+      layer.enabled: true
+      layer.effect: MultiEffect {
+        shadowEnabled: true
+        shadowColor: "#d0000000"
+        shadowBlur: 0.7
+        shadowVerticalOffset: 1
+        shadowHorizontalOffset: 0
+      }
+    }
+
     BorderSurface {
       id: inputField
       width: root.fieldWidth
OMARCHY_EOF
cd ~
```

**Lock screen display power** (`sampsonml.lock/Service.qml`): while locked, the display turns off only on battery. On the charger it stays on.

Patch for `~/.config/omarchy/plugins/sampsonml.lock/Service.qml`:

```bash
cd ~/.config/omarchy/plugins/sampsonml.lock
patch -p1 <<'OMARCHY_EOF'
--- a/Service.qml
+++ b/Service.qml
@@ -2,6 +2,7 @@
 import Quickshell
 import Quickshell.Io
 import Quickshell.Services.Pam
+import Quickshell.Services.UPower
 import Quickshell.Wayland
 import qs.Commons
 import qs.Commons as Commons
@@ -170,7 +171,21 @@
     runWake()
   }
 
+  // Cyberdeck: keep the display on while locked, unless running on battery.
+  // The built-in lock turns the display (and keyboard backlight) off after 5 s
+  // without input; that now only happens on battery. Machines without a
+  // battery (the mini PC) always count as on AC, so the display stays on.
+  // Set this to false to keep it on even on battery, or true to always blank.
+  readonly property bool blankDisplayWhenLocked: UPower.onBattery
+
+  // Plugging in or unplugging while locked takes effect straight away.
+  onBlankDisplayWhenLockedChanged: if (lockRequested) armBlankTimer()
+
   function armBlankTimer() {
+    if (!blankDisplayWhenLocked) {
+      idleBlankTimer.stop()
+      return
+    }
     idleBlankTimer.armedAt = Date.now()
     idleBlankTimer.restart()
   }
OMARCHY_EOF
cd ~
```

### 7.3 Custom bar widgets

These are plain QML files that `shell.json` refers to with `"type": "qml"`:

| File | Shows | Click |
|---|---|---|
| `beaker-menu.qml` | Omarchy menu button with a beaker icon instead of the logo | left: menu, right: terminal |
| `mortality.qml` | your age as a decimal that keeps ticking, with a copper test-tube icon in a copper pill | (none) |
| `princeton-vpn.qml` | globe: dim when off, blinking copper while connecting, teal when connected | left: VPN on/off, right: Library VPN |
| `deepwork.qml` | today's deep-work time (`󰧑 2h 35m`, `0m` before the first session) in a teal pill next to the workspaces that fills towards the daily goal and turns copper once it's reached; during a break, a coffee cup and the time left (step 7.4) | the deep-work menu |
| `power-draw.qml` | live battery draw (`󱐋 9.8 W`): golden olive from 8 W, ember red from 15 W, teal `+W` while charging, hidden on AC when full | opens Omarchy's battery panel |

`~/.config/omarchy/bar/modules/beaker-menu.qml`:

```bash
mkdir -p ~/.config/omarchy/bar/modules
cat > ~/.config/omarchy/bar/modules/beaker-menu.qml <<'OMARCHY_EOF'
import QtQuick
import qs.Commons
import qs.Ui

// Omarchy menu button with a science beaker icon instead of the Omarchy logo.
// Behaves like the built-in omarchy.menu bar widget: left click opens the
// Omarchy menu, right click opens a terminal. The menu itself is still the
// built-in omarchy.menu, so it keeps getting Omarchy updates.
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Octicons "beaker" (nf-oct-beaker) from the Nerd Font.
    text: "\uf499"
    fontFamily: "Iosevka Nerd Font Propo"
    // Same size as the other bar icons (scales with [font] base-size).
    fontSize: Style.bar.iconFont
    horizontalMargin: 7.5
    onPressed: function(mouseButton) {
      if (!root.bar) return
      if (mouseButton === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("omarchy-shell shell toggle omarchy.menu '{\"menu\":\"root\"}'")
    }
  }
}
OMARCHY_EOF
```

`~/.config/omarchy/bar/modules/mortality.qml`:

```bash
mkdir -p ~/.config/omarchy/bar/modules
cat > ~/.config/omarchy/bar/modules/mortality.qml <<'OMARCHY_EOF'
import QtQuick
import qs.Commons
import qs.Commons as Commons

// Mortality counter: your age in years as a decimal that keeps ticking up,
// e.g. "󰙨 34.49817235" (copper test-tube icon, nf-md-test_tube), inside a
// hollow copper pill. The icon replaced a "MORTALITY" text label on 3 Nov 2026.
//
// Settings come from this widget's entry in ~/.config/omarchy/shell.json:
//   { "id": "mortality", "type": "qml", "birth": "1991-04-17T06:30:00", "decimals": 8 }
// "birth" is local time (ISO 8601; the time part is optional). The whole
// number goes up exactly on each birthday; the fraction is how far you are
// from the last birthday to the next one.
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property string birthSetting: settings && settings.birth ? String(settings.birth) : ""
  readonly property int decimals: settings && isFinite(Number(settings.decimals))
    ? Math.max(0, Math.min(10, Math.floor(Number(settings.decimals)))) : 8
  readonly property var birth: parseBirth(birthSetting)
  property string ageText: "--"

  readonly property color copper: Commons.Color.accent
  readonly property color textColor: bar ? bar.barForeground : Commons.Color.foreground
  readonly property real pillHeight: Math.round((bar ? bar.barSize : Style.bar.sizeHorizontal) * 0.6)
  readonly property real padX: Style.space(9)
  readonly property real gap: Style.space(6)
  // Bar text and icon size: 2px below the shared body token (14 -> 12, 3 Nov 2026).
  readonly property int textSize: Style.font.body - 2

  implicitWidth: pill.width + Style.space(4)
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  // "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM[:SS]" (a space works instead of T),
  // read as local time. Returns null if it can't be parsed.
  function parseBirth(value) {
    var m = String(value || "").trim().match(/^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?$/)
    if (!m) return null
    var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]),
                     Number(m[4] || 0), Number(m[5] || 0), Number(m[6] || 0))
    return isNaN(d.getTime()) ? null : d
  }

  // The birthday in a given year, at the birth time of day.
  function birthdayIn(year) {
    return new Date(year, birth.getMonth(), birth.getDate(),
                    birth.getHours(), birth.getMinutes(), birth.getSeconds())
  }

  function ageYears(now) {
    var years = now.getFullYear() - birth.getFullYear()
    var last = birthdayIn(birth.getFullYear() + years)
    if (last > now) {
      years -= 1
      last = birthdayIn(birth.getFullYear() + years)
    }
    var next = birthdayIn(birth.getFullYear() + years + 1)
    return years + (now - last) / (next - last)
  }

  function refresh() {
    if (!birth) {
      ageText = "set birth date"
      return
    }
    var now = new Date()
    if (now < birth) {
      ageText = "not born yet"
      return
    }
    ageText = ageYears(now).toFixed(decimals)
  }

  function tooltipText() {
    if (!birth) return "Add \"birth\": \"YYYY-MM-DDTHH:MM\" to this widget in ~/.config/omarchy/shell.json"
    var days = Math.floor((new Date() - birth) / 86400000)
    return "Born " + Qt.formatDateTime(birth, "d MMMM yyyy, HH:mm") + " · " + days.toLocaleString(Qt.locale("en_US"), "f", 0) + " days"
  }

  onBirthChanged: refresh()
  onDecimalsChanged: refresh()

  // With 8 decimals the last digit moves about every 0.3 s.
  Timer {
    interval: 100
    running: root.visible && root.birth !== null
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Rectangle {
    id: pill
    anchors.centerIn: parent
    width: row.implicitWidth + root.padX * 2
    height: root.pillHeight
    radius: height / 2
    color: "transparent"
    border.width: 1
    border.color: root.copper

    Row {
      id: row
      anchors.centerIn: parent
      spacing: root.gap

      // Test tube (nf-md-test_tube, U+F0668) from the Nerd Font.
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰙨"
        color: root.copper
        font.family: "Iosevka Nerd Font Propo"
        font.pixelSize: root.textSize
        renderType: Text.NativeRendering
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.ageText
        color: root.textColor
        font.family: bar ? bar.fontFamily : Style.font.family
        font.pixelSize: root.textSize
        font.features: { "tnum": 1 }
        renderType: Text.NativeRendering
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipText())
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
OMARCHY_EOF
```

`~/.config/omarchy/bar/modules/princeton-vpn.qml`:

```bash
mkdir -p ~/.config/omarchy/bar/modules
cat > ~/.config/omarchy/bar/modules/princeton-vpn.qml <<'OMARCHY_EOF'
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Princeton VPN globe. Click to connect to / disconnect from Princeton's
// GlobalProtect VPN through ~/.local/bin/princeton-vpn (sign-in happens in the
// browser; admin rights come from the polkit password prompt).
//
//   left click   connect to vpn.princeton.edu, or disconnect
//   right click  connect to vpnlocal.princeton.edu (Library e-resources), or disconnect
//
// Colours: dim when disconnected, blinking copper (theme accent) while
// connecting, cyberdeck teal when connected.
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property string script: Quickshell.env("HOME") + "/.local/bin/princeton-vpn"
  readonly property color teal: themeColor("cyan", "#6fb3b8")  // the theme's cyan

  // Theme colours the shell's Color doesn't carry (sampsonml, 4 Nov 2026): read from the
  // current theme's colors.toml, and again whenever the shell applies a theme, so they
  // follow the theme. The fallbacks are the cyberdeck values.
  property string themePalette: ""
  function themeColor(key, fallback) {
    var m = themePalette.match(new RegExp("^\\s*" + key + "\\s*=\\s*[\"']?(#[0-9A-Fa-f]{6})", "m"))
    return m ? m[1] : fallback
  }
  FileView {
    id: themeColorsFile
    path: Commons.Color.currentThemePath + "/colors.toml"
    printErrors: false
    onLoaded: root.themePalette = text()
  }
  Connections {
    target: Commons.Color
    function onAccentChanged() { themeColorsFile.reload() }
    function onBackgroundChanged() { themeColorsFile.reload() }
    function onShellValuesChanged() { themeColorsFile.reload() }
  }
  property string vpnState: "disconnected" // connected | connecting | disconnected
  property bool blinkOn: true

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  Process {
    id: statusProc
    command: [root.script, "status"]
    stdout: SplitParser {
      onRead: function(line) {
        var s = String(line).trim()
        if (s === "connected" || s === "connecting" || s === "disconnected") root.vpnState = s
      }
    }
  }

  // Poll the tunnel state; faster while a connection is being set up.
  Timer {
    interval: root.vpnState === "connecting" ? 1000 : 3000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 550
    running: root.vpnState === "connecting"
    repeat: true
    onTriggered: root.blinkOn = !root.blinkOn
    onRunningChanged: root.blinkOn = true
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Font Awesome "globe" (nf-fa-globe) from the Nerd Font.
    text: ""
    fontFamily: "Iosevka Nerd Font Propo"
    // Same size as the other bar icons (scales with [font] base-size).
    fontSize: Style.bar.iconFont
    horizontalMargin: 7.5
    foreground: root.vpnState === "connected" ? root.teal
      : root.vpnState === "connecting" ? (root.blinkOn ? Commons.Color.accent : Commons.Color.muted)
      : (root.bar ? root.bar.barForeground : Commons.Color.foreground)
    dimmed: root.vpnState === "disconnected"
    tooltipText: root.vpnState === "connected" ? "Princeton VPN: connected (click to disconnect)"
      : root.vpnState === "connecting" ? "Princeton VPN: signing in… finish in your browser (click to cancel)"
      : "Princeton VPN: off (click to connect · right-click for Library VPN)"
    onPressed: function(mouseButton) {
      // Util.execArgv runs the argv detached through a login shell (no quoting
      // needed). The bar API has no shellQuote, despite the bar README.
      var argv = [root.script, "toggle"]
      if (mouseButton === Qt.RightButton) argv.push("library")
      Util.execArgv(argv)
      root.vpnState = root.vpnState === "disconnected" ? "connecting" : root.vpnState
      refreshSoon.restart()
    }
  }

  Timer {
    id: refreshSoon
    interval: 1500
    onTriggered: root.refresh()
  }
}
OMARCHY_EOF
```

`~/.config/omarchy/bar/modules/power-draw.qml`:

```bash
mkdir -p ~/.config/omarchy/bar/modules
cat > ~/.config/omarchy/bar/modules/power-draw.qml <<'OMARCHY_EOF'
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Live battery power draw, e.g. "󱐋 9.8 W", placed just left of omarchy.power.
// Reads the kernel's battery readings in /sys/class/power_supply/<battery>/
// directly, because UPower only refreshes its energy-rate figure every
// 30 s or so.
//
//   on battery   bolt + watts, averaged over the last few readings.
//                Normal colour below `warn` W, golden olive from `warn`,
//                ember red from `high`.
//   charging     plug + "+watts" in cyberdeck teal
//   on AC, idle  hidden (Full / Not charging: nothing is flowing)
//
//   left click   open Omarchy's battery / power-profile panel
//   hover        current and average draw, and time left (or time to full)
//
// Optional settings in this widget's shell.json entry (defaults shown):
//   { "id": "power-draw", "type": "qml", "battery": "BAT0",
//     "interval": 2, "samples": 5, "warn": 8, "high": 15 }
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  function setting(name, fallback) {
    var v = settings ? settings[name] : undefined
    return (v === undefined || v === null || v === "") ? fallback : v
  }
  function numberSetting(name, fallback, min, max) {
    var n = Number(setting(name, fallback))
    return isFinite(n) ? Math.max(min, Math.min(max, n)) : fallback
  }

  readonly property string battery: String(setting("battery", "BAT0"))
  readonly property string sysDir: "/sys/class/power_supply/" + battery + "/"
  readonly property int intervalMs: Math.round(numberSetting("interval", 2, 0.5, 60) * 1000)
  readonly property int maxSamples: Math.round(numberSetting("samples", 5, 1, 60))
  readonly property real warnWatts: numberSetting("warn", 8, 0, 200)
  readonly property real highWatts: numberSetting("high", 15, 0, 200)

  // The theme's cyan, yellow and red (teal, golden olive and ember red in cyberdeck).
  readonly property color teal: themeColor("cyan", "#6fb3b8")
  readonly property color olive: themeColor("yellow", "#d8c07a")
  readonly property color ember: themeColor("red", "#d9705a")

  // Theme colours the shell's Color doesn't carry (sampsonml, 4 Nov 2026): read from the
  // current theme's colors.toml, and again whenever the shell applies a theme, so they
  // follow the theme. The fallbacks are the cyberdeck values.
  property string themePalette: ""
  function themeColor(key, fallback) {
    var m = themePalette.match(new RegExp("^\\s*" + key + "\\s*=\\s*[\"']?(#[0-9A-Fa-f]{6})", "m"))
    return m ? m[1] : fallback
  }
  FileView {
    id: themeColorsFile
    path: Commons.Color.currentThemePath + "/colors.toml"
    printErrors: false
    onLoaded: root.themePalette = text()
  }
  Connections {
    target: Commons.Color
    function onAccentChanged() { themeColorsFile.reload() }
    function onBackgroundChanged() { themeColorsFile.reload() }
    function onShellValuesChanged() { themeColorsFile.reload() }
  }
  readonly property string iconFont: "Iosevka Nerd Font Propo"
  // Bar text and icon size: 2px below the shared body token (14 -> 12, 3 Nov 2026).
  readonly property int textSize: Style.font.body - 2
  readonly property string boltIcon: "󱐋" // nf-md-lightning_bolt U+F140B
  readonly property string plugIcon: "󰚥" // nf-md-power_plug U+F06A5

  // Discharging | Charging | Full | Not charging | Unknown | "" (no battery)
  property string status: ""
  property real nowWatts: 0
  property real avgWatts: 0
  property real energyWh: 0
  property real energyFullWh: 0
  property var samples: []

  readonly property bool discharging: status === "Discharging"
  readonly property bool charging: status === "Charging"
  readonly property bool active: (discharging || charging) && avgWatts > 0.05
  readonly property bool vertical: bar ? bar.vertical : false

  function readNumber(file) {
    file.reload()
    var n = parseInt(String(file.text()).trim(), 10)
    return isFinite(n) ? n : NaN
  }

  // Watts flowing in or out of the battery right now. Some batteries only
  // report current and voltage, so fall back to multiplying those.
  function readWatts() {
    var p = readNumber(powerNow)
    if (isFinite(p)) return p / 1e6
    var i = readNumber(currentNow)
    var v = readNumber(voltageNow)
    return (isFinite(i) && isFinite(v)) ? (i / 1e6) * (v / 1e6) : NaN
  }

  function refresh() {
    statusFile.reload()
    var s = String(statusFile.text()).trim()
    if (s !== status) {
      // The draw while charging says nothing about the draw on battery, so
      // start the average over whenever the state flips.
      samples = []
      status = s
    }
    if (!discharging && !charging) {
      nowWatts = 0
      avgWatts = 0
      return
    }

    var w = readWatts()
    if (!isFinite(w)) return
    nowWatts = Math.abs(w)
    var next = samples.concat([nowWatts])
    if (next.length > maxSamples) next = next.slice(next.length - maxSamples)
    samples = next
    var sum = 0
    for (var k = 0; k < next.length; k++) sum += next[k]
    avgWatts = sum / next.length

    var e = readNumber(energyNow)
    var f = readNumber(energyFull)
    energyWh = isFinite(e) ? e / 1e6 : 0
    energyFullWh = isFinite(f) ? f / 1e6 : 0
  }

  function formatWatts(w) {
    return (w < 9.95 ? w.toFixed(1) : w.toFixed(0)) + " W"
  }

  function formatHours(h) {
    if (!isFinite(h) || h <= 0 || h > 99) return ""
    var mins = Math.round(h * 60)
    return Math.floor(mins / 60) + "h " + ("0" + (mins % 60)).slice(-2) + "m"
  }

  readonly property color levelColor: charging ? teal
    : avgWatts >= highWatts ? ember
    : avgWatts >= warnWatts ? olive
    : (bar ? bar.barForeground : Commons.Color.foreground)

  readonly property string label: !active ? ""
    : vertical ? (charging ? plugIcon : boltIcon) + "\n" + avgWatts.toFixed(0)
    : (charging ? plugIcon + " +" : boltIcon + " ") + formatWatts(avgWatts)

  readonly property string tooltip: {
    if (!active) return ""
    var window = Math.round(samples.length * intervalMs / 1000)
    var lines = [(charging ? "Charging at " : "Drawing ") + formatWatts(nowWatts) + " now",
                 formatWatts(avgWatts) + " average over the last " + window + " s"]
    var left = charging
      ? formatHours((energyFullWh - energyWh) / avgWatts)
      : formatHours(energyWh / avgWatts)
    if (left !== "") lines.push(charging ? "Full in about " + left + " at this rate"
                                         : "About " + left + " left at this rate")
    lines.push("Click for battery and power profile")
    return lines.join("\n")
  }

  visible: active
  implicitWidth: active ? button.implicitWidth : 0
  implicitHeight: active ? button.implicitHeight : 0

  FileView { id: statusFile; path: root.sysDir + "status"; blockAllReads: true; printErrors: false }
  FileView { id: powerNow; path: root.sysDir + "power_now"; blockAllReads: true; printErrors: false }
  FileView { id: currentNow; path: root.sysDir + "current_now"; blockAllReads: true; printErrors: false }
  FileView { id: voltageNow; path: root.sysDir + "voltage_now"; blockAllReads: true; printErrors: false }
  FileView { id: energyNow; path: root.sysDir + "energy_now"; blockAllReads: true; printErrors: false }
  FileView { id: energyFull; path: root.sysDir + "energy_full"; blockAllReads: true; printErrors: false }

  // Poll less often when plugged in and idle, just to notice the state change.
  Timer {
    interval: root.active ? root.intervalMs : Math.max(root.intervalMs, 5000)
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // Keeps the pill the same width as the digits change, so the bar doesn't shift.
  TextMetrics {
    id: widest
    font.family: root.iconFont
    font.pixelSize: root.textSize
    text: root.plugIcon + " +88.8 W"
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label
    fontFamily: root.iconFont
    fontSize: root.textSize
    horizontalMargin: 7.5
    fixedWidth: root.vertical ? -1 : Math.ceil(widest.advanceWidth + Style.spaceReal(7.5) * 2)
    foreground: root.levelColor
    tooltipText: root.tooltip
    onTooltipTextChanged: if (button.tooltipHovered && root.bar) root.bar.showTooltip(button, button.tooltipText)
    onPressed: function(mouseButton) {
      Util.execArgv(["omarchy-shell", "-q", "omarchy.power", "toggle"])
    }
  }
}
OMARCHY_EOF
```

`~/.config/omarchy/bar/modules/deepwork.qml`:

```bash
cat > ~/.config/omarchy/bar/modules/deepwork.qml <<'OMARCHY_EOF'
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons

// Deep work today (sampsonml, 4 Nov 2026): how long you've spent in deep-work mode
// today, e.g. "󰧑 2h 35m", in a hollow teal pill next to the workspace pills. It's always
// shown, reading "0m" before the first session of the day (the user asked for that).
// Click: the deep-work menu (same as Super+D).
//
// Daily goal (the user's pick, 4 Nov 2026): the pill fills with teal towards "goal"
// minutes, and turns solid copper once today's total reaches it.
// Breaks: after a session the plugin starts a short break; the pill then shows a coffee
// cup and the time left, and drains as it runs.
//
// It reads finished sessions from ~/.local/state/sampsonml/deepwork/sessions.jsonl,
// which the sampsonml.deepwork plugin appends to (one JSON object per line; a session
// counts towards the day it started), and the break from rest.json in the same folder.
// The bar is hidden during a session, so it doesn't try to show the running one.
//
// shell.json entry: { "id": "deepwork", "type": "qml", "goal": 180 }
//   goal  daily target in minutes (0 or missing: no goal); the plugin's end-of-session
//         notification reads it from here too
Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  readonly property string home: Quickshell.env("HOME")
  readonly property string logPath: home + "/.local/state/sampsonml/deepwork/sessions.jsonl"
  readonly property string restPath: home + "/.local/state/sampsonml/deepwork/rest.json"

  property int todayMinutes: 0
  property int todaySessions: 0

  readonly property int goalMin: settings && settings.goal !== undefined ? Math.max(0, Number(settings.goal) || 0) : 0
  readonly property bool goalReached: goalMin > 0 && todayMinutes >= goalMin
  readonly property real goalProgress: goalMin > 0 ? Math.min(1, todayMinutes / goalMin) : 0

  property double restStart: 0
  property double restUntil: 0
  property double now: Date.now()
  readonly property bool resting: restUntil > now
  readonly property real restLeft: resting && restUntil > restStart
    ? Math.min(1, (restUntil - now) / (restUntil - restStart)) : 0

  // Solid copper once the goal is reached (not during a break, which is drawn in teal).
  readonly property bool showReached: goalReached && !resting
  readonly property real fillFraction: resting ? restLeft : goalProgress
  readonly property color fillColor: showReached ? copper : Qt.rgba(teal.r, teal.g, teal.b, 0.3)

  // The theme's cyan, accent and background (teal, copper and near-black in cyberdeck).
  readonly property color teal: themeColor("cyan", "#6fb3b8")
  readonly property color copper: Commons.Color.accent
  readonly property color dark: Commons.Color.background

  // Theme colours the shell's Color doesn't carry (sampsonml, 4 Nov 2026): read from the
  // current theme's colors.toml, and again whenever the shell applies a theme, so they
  // follow the theme. The fallbacks are the cyberdeck values.
  property string themePalette: ""
  function themeColor(key, fallback) {
    var m = themePalette.match(new RegExp("^\\s*" + key + "\\s*=\\s*[\"']?(#[0-9A-Fa-f]{6})", "m"))
    return m ? m[1] : fallback
  }
  FileView {
    id: themeColorsFile
    path: Commons.Color.currentThemePath + "/colors.toml"
    printErrors: false
    onLoaded: root.themePalette = text()
  }
  Connections {
    target: Commons.Color
    function onAccentChanged() { themeColorsFile.reload() }
    function onBackgroundChanged() { themeColorsFile.reload() }
    function onShellValuesChanged() { themeColorsFile.reload() }
  }
  readonly property color textColor: bar ? bar.barForeground : Commons.Color.foreground
  readonly property real pillHeight: Math.round((bar ? bar.barSize : Style.bar.sizeHorizontal) * 0.6)
  readonly property real padX: Style.space(9)
  readonly property real gap: Style.space(6)
  readonly property int textSize: Style.font.body - 2  // bar text size (see mortality.qml)

  implicitWidth: pill.width + Style.space(4)
  implicitHeight: bar ? bar.barSize : Style.bar.sizeHorizontal

  function durationText(minutes) {
    var h = Math.floor(minutes / 60)
    var m = minutes % 60
    return h > 0 ? h + "h " + (m < 10 ? "0" : "") + m + "m" : m + "m"
  }

  function refresh() {
    var text = ""
    try { text = logFile.text() } catch (e) { text = "" }
    var today = new Date()
    var minutes = 0
    var sessions = 0
    String(text || "").split("\n").forEach(function(line) {
      if (!line.trim()) return
      try {
        var e = JSON.parse(line)
        var d = new Date(e.start)
        if (d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth()
            && d.getDate() === today.getDate()) {
          minutes += Number(e.focusedMin || 0)
          sessions += 1
        }
      } catch (err) {}
    })
    todayMinutes = minutes
    todaySessions = sessions
  }

  function goalText(minutes) {
    return minutes % 60 === 0 && minutes >= 60 ? (minutes / 60) + "h" : durationText(minutes)
  }

  // "4:32"
  function restText() {
    var s = Math.max(0, Math.ceil((restUntil - now) / 1000))
    var sec = s % 60
    return Math.floor(s / 60) + ":" + (sec < 10 ? "0" : "") + sec
  }

  function tooltipText() {
    var s = todaySessions === 1 ? "1 session" : todaySessions + " sessions"
    var today = "Deep work today: " + durationText(todayMinutes)
      + (goalMin > 0 ? " of " + goalText(goalMin) : "") + " (" + s + ")"
      + (goalReached ? ", goal reached" : "")
    if (resting) return "Break: " + restText() + " left. Stand up and look away from the screen.\n" + today
    return today + "\nClick or Super+D: start or manage a session"
  }

  function readRest() {
    var r = null
    try { r = JSON.parse(String(restFile.text() || "")) } catch (e) { r = null }
    restStart = r ? Number(r.start) || 0 : 0
    restUntil = r ? Number(r.until) || 0 : 0
    now = Date.now()
  }

  FileView {
    id: logFile
    path: root.logPath
    watchChanges: true
    printErrors: false
    onLoaded: root.refresh()
    onLoadFailed: root.refresh()
    onFileChanged: reload()
  }

  FileView {
    id: restFile
    path: root.restPath
    watchChanges: true
    printErrors: false
    onLoaded: root.readRest()
    onLoadFailed: root.readRest()
    onFileChanged: reload()
  }

  // Picks up the new day at midnight, and the log if it didn't exist yet.
  Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: logFile.reload()
  }

  // The break countdown.
  Timer {
    interval: 1000
    repeat: true
    running: root.restUntil > 0 && root.restUntil > root.now - 1000
    onTriggered: root.now = Date.now()
  }

  Item {
    id: pill
    anchors.centerIn: parent
    width: row.implicitWidth + root.padX * 2
    height: root.pillHeight

    // Progress towards the goal (or the break draining), from the left: a full-size
    // rounded shape clipped to the progress width, so the left end stays round.
    Item {
      anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
      width: Math.round(parent.width * root.fillFraction)
      clip: true

      Rectangle {
        width: pill.width
        height: pill.height
        radius: height / 2
        color: root.fillColor
      }
    }

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: "transparent"
      border.width: 1
      border.color: root.showReached ? root.copper : root.teal
    }

    Row {
      id: row
      anchors.centerIn: parent
      spacing: root.gap

      // Brain (nf-md-brain, U+F09D1), or a coffee cup during a break (nf-md-coffee,
      // U+F0176, written as a UTF-16 surrogate pair).
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.resting ? "\uDB80\uDD76" : "󰧑"
        color: root.showReached ? root.dark : root.teal
        font.family: "Iosevka Nerd Font Propo"
        font.pixelSize: root.textSize
        renderType: Text.NativeRendering
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.resting ? root.restText() : root.durationText(root.todayMinutes)
        color: root.showReached ? root.dark : root.textColor
        font.family: bar ? bar.fontFamily : Style.font.family
        font.pixelSize: root.textSize
        font.features: { "tnum": 1 }
        renderType: Text.NativeRendering
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipText())
    onExited: if (root.bar) root.bar.hideTooltip(root)
    onClicked: Util.execArgv([root.home + "/.local/bin/deepwork"])
  }
}
OMARCHY_EOF
```

### 7.4 Deep-work mode (`Super+D`)

A focus mode designed with the user (4 Nov 2026). `Super+D` opens a menu: 25, 50 or 90 minutes, or open-ended; its title shows today's total against the daily goal (`Deep work · 2h 35m of 3h today`). During a session the same shortcut offers *End now*, *Add 10 min*, *Pause*/*Resume* and *Show colour (20 s)*.

Starting a session plays a 2-second TV glitch over the whole screen (the user's request): a still of the screen tears up (bands slip sideways, lines jitter, strips turn to static) and drains to grey, the set switches off into a white line and a dot, there's a moment of no signal, and then the picture comes back in bands onto the deep-work screen. It's black and white. Clicks go straight through it, and the desktop only changes once it covers the screen, so you never see the bar turn into the timer bar. `omarchy-shell deepwork intro` plays it on its own.

While a session runs:
- The bar is replaced by a **timer bar** of the same height: the countdown in the middle (`DEEP WORK  23:41`) on a frosted strip that fills from left to right as time passes. The fill is copper, ember red for the last minute, grey while paused. Open-ended sessions count up without a fill. Clicking it opens the menu.
- No gaps or borders, and unfocused windows are dimmed more (0.4 instead of 0.12).
- The screen turns mostly grey (the user's pick): bright colour is what makes thumbnails, badges and feeds pull at you. A quarter of the colour stays (`KEEP` in `grey.glsl`; `GREY=0` in `env.sh` turns it off). `Super+Alt+C` (or *Show colour* in the menu) brings the colour back for 20 seconds; press it again to go back to grey sooner.
- The workspace is locked (the user's request): the workspace keys (`Super+number`, `Super+Shift+number`, `Super+Tab` and friends, Super+scroll) only show `WORKSPACE LOCKED` on the timer bar, and anything else that switches workspace is switched straight back. The scratchpad (`Super+S`) still works, and so does moving a window silently (`Super+Shift+Alt+number`).
- Notifications are silenced (Omarchy's do-not-disturb; critical system alerts still show), and the idle lock is held off ("stay awake").
- When the time is up, a chime plays and a notification gets through do-not-disturb. The session carries on in overtime (`OVERTIME  +04:12`, fully filled in ember red) until you end it.

Ending puts back only what the session changed: a bar that was already hidden stays hidden. Windows jump straight to their new size rather than sliding. Each session is logged in `~/.local/state/sampsonml/deepwork/sessions.jsonl`, and the pill from step 7.3 shows today's total.

**Daily goal:** the pill fills with teal towards a daily target (`goal` on its `shell.json` entry, 180 minutes) and turns solid copper once you reach it. The end-of-session notification reads `Today: 2h 35m of 3h`, and says when the goal is reached.

**Breaks:** ending a session of 10 focused minutes or more starts a 5-minute break. Nothing is locked: the pill shows a coffee cup and counts down, and a bell and a notification say when it's over. Starting a session during a break asks first (*Keep resting* is the default, or *Start anyway*). `omarchy-shell deepwork rest <min>` starts one by hand, and `rest 0` ends it.

It's a shell plugin of our own (not a clone):
- `Service.qml`: the timer, the timer bar, the log, the breaks and the IPC target (`omarchy-shell deepwork start|end|extend|pause|resume|status|colour|rest`)
- `grey.glsl`: the grey screen, a Hyprland screen shader that `env.sh` switches on for the session
- `glitch.frag`: the GPU shader for the start animation, compiled to `glitch.frag.qsb`
- `env.sh`: the desktop changes. The Hyprland part is a file in Omarchy's toggles folder (`~/.local/state/omarchy/toggles/hypr/`), which loads after your own config, so a config reload mid-session keeps it.

It also needs its `shell.json` entry (step 7.5), the shortcut in `bindings.lua` and the blur rule in `looknfeel.lua` (both step 6).

```bash
mkdir -p ~/.config/omarchy/plugins/sampsonml.deepwork
cat > ~/.config/omarchy/plugins/sampsonml.deepwork/manifest.json <<'OMARCHY_EOF'
{
  "schemaVersion": 1,
  "id": "sampsonml.deepwork",
  "name": "Deep Work",
  "version": "1.0.0",
  "author": "sampsonml",
  "description": "Deep-work mode: a timed focus session. The bar becomes a timer bar; gaps and borders go, other windows dim, the screen turns grey, the workspace is locked, notifications are silenced and the screen stays awake. A short break follows each session. Super+D opens its menu.",
  "kinds": [
    "service"
  ],
  "entryPoints": {
    "service": "Service.qml"
  }
}
OMARCHY_EOF
cat > ~/.config/omarchy/plugins/sampsonml.deepwork/Service.qml <<'OMARCHY_EOF'
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// sampsonml.deepwork (4 Nov 2026): deep-work mode, designed with the user.
//
// Super+D runs ~/.local/bin/deepwork, which shows Omarchy menus and calls this service
// over IPC (`omarchy-shell deepwork <method>`):
//   start <minutes>   start a session (0 = open-ended; decimals work, for testing)
//   end               end it and restore everything
//   extend <minutes>  add time (in overtime: that many minutes from now)
//   pause / resume    freeze / unfreeze the timer (the desktop stays in deep-work mode)
//   status            JSON for the menu script
//   intro             play the start animation on its own (to preview it)
//   nudge             show "WORKSPACE LOCKED" on the timer bar for a moment (the
//                     workspace keys call this while a session runs)
//   colour            show colour for colourPeekMs, then grey again (Super+Alt+C during a
//                     session; again to go back to grey early)
//   rest <minutes>    start a break by hand (0 = end the break)
//
// While a session runs, env.sh (next to this file) has hidden the bar, removed gaps and
// borders, dimmed unfocused windows more, locked the workspace (the user's request: the
// workspace keys only nudge, and any other switch is switched back), switched on
// do-not-disturb and "stay awake", turned the screen mostly grey (grey.glsl), and this
// service shows the timer bar in the bar's place.
// Ending runs env.sh again, which undoes only what it changed (it keeps a note of that in
// ~/.local/state/sampsonml/deepwork/env-flags).
//
// The timer bar (the user's design, 4 Nov 2026) is a bar-height strip across the top of
// every screen with the countdown in the middle ("DEEP WORK  23:41"). The strip is also a
// progress bar that fills from left to right as the session goes on: copper, ember red for
// the last minute, dim grey while paused ("PAUSED"). Open-ended sessions count up and
// don't fill. Windows sit below it, like with the normal bar; clicking it opens the menu.
// When the time is up: a chime and a notification that gets through do-not-disturb (it
// stays until dismissed, or until the session is ended or extended), and the session
// keeps going ("OVERTIME  +04:12", fully filled in ember red) until it's ended from the menu.
// (The first version, the same day, was a 2px line along the top edge instead.)
//
// Starting a session plays a 2 s TV glitch over the whole screen (the user asked for "a tv
// glitch style thing", replacing the first animation, rising embers): a still of the
// screen tears up and drains to grey, the set switches off to a white line, there's a
// moment of no signal, then the signal comes back in bands onto the deep-work screen
// (glitch.frag, compiled to glitch.frag.qsb). Black and white unless introChroma is set.
// It's click-through, and env.sh enter only runs once it covers the screen, so the bar
// turning into the timer bar happens out of sight.
//
// Each finished session is appended to ~/.local/state/sampsonml/deepwork/sessions.jsonl;
// ~/.config/omarchy/bar/modules/deepwork.qml shows today's total in the bar from it, and
// how close it is to the daily goal ("goal" on that pill's shell.json entry, in minutes).
//
// Breaks (the user's pick, 4 Nov 2026): ending a session of at least breakAfterMin
// focused minutes starts a breakMin-minute break. Nothing is locked: the bar pill counts
// it down, a bell and a notification say when it's over, and the Super+D menu asks
// "Keep resting / Start anyway" if you start a session during it. The break is kept in
// rest.json (next to the log), which the pill reads too.
// The running session is mirrored to session.json in the same folder, so restarting the
// shell picks it up again. Time while the laptop sleeps or the shell is down isn't
// counted as focused time.
//
// Changing this file needs `omarchy restart shell` (the shell caches plugin QML); see
// ~/customization/CLAUDE.md for how to restart without the windows sliding.
Item {
  id: root

  property var shell: null

  // --- Settings -------------------------------------------------------------
  readonly property int barHeight: Style.bar.sizeHorizontal  // same height as the normal bar
  readonly property real backgroundAlpha: 0.35     // like the bar's HUD fill (hudFillAlpha)
  readonly property real fillAlpha: 0.5            // the progress fill
  readonly property int finalStretchMs: 60 * 1000  // fill turns ember red for the last minute
  readonly property string chimeSound: "/usr/share/sounds/freedesktop/stereo/complete.oga"
  // Colours follow the theme: accent, red, muted grey and background (copper, ember red,
  // dim grey and near-black in cyberdeck).
  readonly property color copper: Color.accent
  readonly property color ember: Color.urgent
  readonly property color pausedColor: Color.muted
  readonly property color background: Color.background
  readonly property int introMs: 2000              // length of the TV-glitch start animation
  readonly property real introChroma: 0            // 0 = black and white; 1 = colour, with a red/blue split
  readonly property int stillTimeoutMs: 400        // play without the still if it hasn't come by then
  readonly property int colourPeekMs: 20000        // Super+Alt+C: colour for this long, then grey again
  readonly property int breakMin: 5                // break after a session
  readonly property int breakAfterMin: 10          // only after sessions at least this long (focused)
  readonly property string breakSound: "/usr/share/sounds/freedesktop/stereo/bell.oga"

  // --- Paths ----------------------------------------------------------------
  readonly property string home: Quickshell.env("HOME")
  readonly property string envScript: home + "/.config/omarchy/plugins/sampsonml.deepwork/env.sh"
  readonly property string stateDir: home + "/.local/state/sampsonml/deepwork"
  readonly property string sessionPath: stateDir + "/session.json"
  readonly property string logPath: stateDir + "/sessions.jsonl"
  readonly property string restPath: stateDir + "/rest.json"
  readonly property string shellJsonPath: home + "/.config/omarchy/shell.json"
  readonly property string toggleLua: home + "/.local/state/omarchy/toggles/hypr/sampsonml-deepwork.lua"

  // --- Session state (mirrored to session.json) -----------------------------
  property bool active: false
  property double startedAt: 0      // ms since epoch
  property double plannedMs: 0      // 0 = open-ended
  property double pausedAt: 0       // ms since epoch while paused, otherwise 0
  property double pausedTotalMs: 0  // paused time plus sleep/shell downtime
  property bool timeUpNotified: false
  property double lastTick: 0
  property bool takeover: false     // timer bar shown (env.sh says when the bar is out of the way)
  property real introT: 1           // 0..1 while the start animation plays; 1 = idle
  property real introSeed: 0
  property bool introCapturing: false  // taking the stills of the screens before it plays
  property int stillsReady: 0
  property bool pendingEnter: false    // run env.sh enter once the animation covers the screen
  property bool greyOn: false          // env.sh made the screen grey for this session
  property bool colourPeek: false      // Super+Alt+C: showing colour for a moment
  property double restStartedAt: 0     // the break (mirrored to rest.json); 0 = none
  property double restUntil: 0
  property int goalMin: 0              // daily goal from the pill's shell.json entry; 0 = none

  property double now: Date.now()
  readonly property bool paused: active && pausedAt > 0
  readonly property bool openEnded: plannedMs <= 0
  readonly property double focusedMs: active
    ? Math.max(0, (paused ? pausedAt : now) - startedAt - pausedTotalMs) : 0
  readonly property double remainingMs: openEnded ? 0 : plannedMs - focusedMs
  readonly property bool overtime: active && !openEnded && remainingMs <= 0
  readonly property real fraction: openEnded ? 0 : Math.max(0, Math.min(1, remainingMs / plannedMs))
  readonly property color fillColor: paused ? pausedColor
    : (overtime || remainingMs <= finalStretchMs ? ember : copper)
  readonly property real progress: openEnded ? 0 : (overtime ? 1 : 1 - fraction)

  // "23:41" or "1:05:09". Countdowns round up, so it reads 0:01 rather than 0:00 at the end.
  function clockText(ms, roundUp) {
    var s = Math.max(0, roundUp ? Math.ceil(ms / 1000) : Math.floor(ms / 1000))
    var h = Math.floor(s / 3600)
    var m = Math.floor((s % 3600) / 60)
    var sec = s % 60
    return (h > 0 ? h + ":" : "") + (m < 10 ? "0" : "") + m + ":" + (sec < 10 ? "0" : "") + sec
  }

  property bool lockedNotice: false  // "WORKSPACE LOCKED" for a moment after a nudge
  readonly property string barLabel: lockedNotice ? "WORKSPACE LOCKED"
    : (paused ? "PAUSED" : (overtime ? "OVERTIME" : "DEEP WORK"))

  function nudge() {
    if (!active) return "not running"
    lockedNotice = true
    lockedNoticeTimer.restart()
    return "locked"
  }

  Timer {
    id: lockedNoticeTimer
    interval: 1500
    onTriggered: root.lockedNotice = false
  }
  readonly property string barTime: openEnded ? clockText(focusedMs, false)
    : (overtime ? "+" + clockText(-remainingMs, false) : clockText(remainingMs, true))

  // --- Helpers --------------------------------------------------------------
  function minutesText(ms) {
    var total = Math.max(0, Math.round(ms / 60000))
    var h = Math.floor(total / 60)
    var m = total % 60
    return h > 0 ? (h + "h " + (m < 10 ? "0" : "") + m + "m") : (m + " min")
  }

  function label() {
    if (!active) return "off"
    var text
    if (openEnded) text = minutesText(focusedMs) + " so far"
    else if (overtime) text = Math.max(1, Math.ceil(-remainingMs / 60000)) + " min over"
    else text = Math.max(1, Math.ceil(remainingMs / 60000)) + " min left"
    return paused ? "paused · " + text : text
  }

  function saveSession() {
    sessionFile.setText(JSON.stringify({
      active: active, startedAt: startedAt, plannedMs: plannedMs, pausedAt: pausedAt,
      pausedTotalMs: pausedTotalMs, timeUpNotified: timeUpNotified, heartbeat: Date.now()
    }) + "\n")
  }

  function run(argv) {
    Quickshell.execDetached(argv)
  }

  // Sum of today's logged sessions (by start date, local time), in ms.
  function todayLoggedMs() {
    var text = ""
    try { text = logFile.text() } catch (e) { text = "" }
    var today = new Date()
    var total = 0
    String(text || "").split("\n").forEach(function(line) {
      if (!line.trim()) return
      try {
        var e = JSON.parse(line)
        var d = new Date(e.start)
        if (d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth()
            && d.getDate() === today.getDate()) total += Number(e.focusedMin || 0) * 60000
      } catch (err) {}
    })
    return total
  }

  // "3h", "2h 30m" or "45 min".
  function goalText(minutes) {
    return minutes % 60 === 0 && minutes >= 60 ? (minutes / 60) + "h" : minutesText(minutes * 60000)
  }

  // The daily goal lives on the bar pill's entry in shell.json ({"id": "deepwork", "goal": 180}).
  function readGoal() {
    var goal = 0
    try {
      var layout = JSON.parse(String(shellJson.text() || "{}")).bar.layout
      for (var section in layout)
        (layout[section] || []).forEach(function(e) { if (e && e.id === "deepwork") goal = Number(e.goal) || 0 })
    } catch (e) { goal = 0 }
    goalMin = goal
  }

  // Colour for a moment (Super+Alt+C). Clearing screen_shader works live; `hyprctl reload`
  // re-reads the session's toggle file, which brings the grey back.
  function colour() {
    if (!active) return "not running"
    if (!greyOn) return "the screen isn't grey"
    if (colourPeek) {
      greyBack()
      return "grey"
    }
    colourPeek = true
    run(["hyprctl", "eval", 'hl.config({ decoration = { screen_shader = "" } })'])
    colourTimer.restart()
    return "colour for " + Math.round(colourPeekMs / 1000) + " s"
  }

  function greyBack() {
    colourTimer.stop()
    if (!colourPeek) return
    colourPeek = false
    if (active) run(["hyprctl", "reload"])
  }

  Timer {
    id: colourTimer
    interval: root.colourPeekMs
    onTriggered: root.greyBack()
  }

  // --- Breaks -------------------------------------------------------------------
  readonly property bool resting: restUntil > 0

  function saveRest() {
    restFile.setText(JSON.stringify({ start: restStartedAt, until: restUntil }) + "\n")
  }

  function startRest(minutes) {
    var m = Number(minutes)
    if (!isFinite(m) || m < 0) return "bad length: " + minutes
    if (m === 0) return endRest(false)
    if (active) return "a session is running"
    beginRest(m)
    return "break: " + clockText(restUntil - Date.now(), true)
  }

  function beginRest(minutes) {
    var t = Date.now()
    restStartedAt = t
    restUntil = t + Math.round(minutes * 60000)
    saveRest()
  }

  // finished: the time ran out (bell and notification), rather than being cut short.
  function endRest(finished) {
    if (!resting) return "no break"
    restStartedAt = 0
    restUntil = 0
    saveRest()
    if (finished) {
      run(["pw-play", breakSound])
      run(["notify-send", "-a", "Deep work", "Break's over",
           "Super+D when you're ready for the next session."])
    }
    return "break over"
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.resting
    onTriggered: {
      var late = Date.now() - root.restUntil
      // More than a minute late means the laptop slept through the end: no bell then.
      if (late >= 0) root.endRest(late < 60000)
    }
  }

  // The start animation. First each screen's overlay maps (still transparent) and takes a
  // still of the screen; once they're in (or after stillTimeoutMs), glitch.frag plays.
  function playIntro() {
    if (introCapturing) return "already starting"
    introAnim.stop()
    introT = 1                // unmaps the overlays, so the stills are taken afresh
    introSeed = Math.random() * 100
    stillsReady = 0
    introCapturing = true
    stillTimeout.restart()
    return "intro"
  }

  function stillReady() {
    stillsReady += 1
    if (stillsReady >= Quickshell.screens.length) beginIntro()
  }

  function beginIntro() {
    if (!introCapturing) return
    stillTimeout.stop()
    introT = 0
    introAnim.restart()
    introCapturing = false
    // The overlay now covers the screen, so the desktop can change behind it.
    if (pendingEnter) {
      pendingEnter = false
      queueEnv("enter")
    }
  }

  // --- Actions --------------------------------------------------------------
  function start(minutes) {
    if (active) return "already running: " + label()
    var m = Number(minutes)
    if (!isFinite(m) || m < 0) return "bad length: " + minutes
    var t = Date.now()
    if (resting) endRest(false)   // the Super+D menu has already asked about the break
    active = true
    greyOn = false
    colourPeek = false
    startedAt = t
    lastTick = t
    now = t
    plannedMs = Math.round(m * 60000)
    pausedAt = 0
    pausedTotalMs = 0
    timeUpNotified = false
    takeover = false
    saveSession()
    // env.sh enter waits until the animation covers the screen (beginIntro).
    if (introCapturing) {
      pendingEnter = true
    } else if (introT < 1) {
      queueEnv("enter")       // a preview is already playing
    } else {
      pendingEnter = true
      playIntro()
    }
    return "started: " + label()
  }

  function end() {
    if (!active) return "not running"
    var t = Date.now()
    if (paused) {
      pausedTotalMs += t - pausedAt
      pausedAt = 0
    }
    now = t
    var focused = focusedMs
    var focusedMin = Math.round(focused / 60000)
    var entry = {
      start: new Date(startedAt).toISOString(),
      end: new Date(t).toISOString(),
      focusedMin: focusedMin,
      plannedMin: openEnded ? null : Math.round(plannedMs / 60000)
    }
    var beforeMs = todayLoggedMs()
    var todayMs = beforeMs + focusedMin * 60000
    run(["bash", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" >> "$1"',
         "deepwork-log", logPath, JSON.stringify(entry)])

    var lines = ["Today: " + goalText(Math.round(todayMs / 60000)) + (goalMin > 0 ? " of " + goalText(goalMin) : "")]
    var goalMs = goalMin * 60000
    if (goalMin > 0 && beforeMs < goalMs && todayMs >= goalMs) lines.push("Daily goal reached.")
    if (focusedMin >= breakAfterMin) {
      lines.push(breakMin + "-min break: stand up and look away from the screen.")
      beginRest(breakMin)
    }
    // The summary is sent once do-not-disturb is back off (after env.sh leave).
    pendingSummary = ["notify-send", "-a", "Deep work",
      "Deep work done · " + minutesText(focused), lines.join("\n")]
    colourTimer.stop()
    colourPeek = false
    dismissTimeUp()
    pendingEnter = false      // ended before the animation got going: nothing to enter
    queueEnv("leave")
    active = false
    pausedAt = 0
    saveSession()
    return "ended after " + minutesText(focused)
  }

  function extend(minutes) {
    if (!active) return "not running"
    if (openEnded) return "open-ended: nothing to extend"
    var add = Math.round(Number(minutes) * 60000)
    if (!isFinite(add) || add <= 0) return "bad length: " + minutes
    now = Date.now()
    plannedMs = overtime ? focusedMs + add : plannedMs + add
    timeUpNotified = false
    dismissTimeUp()
    saveSession()
    return "extended: " + label()
  }

  function pause() {
    if (!active) return "not running"
    if (paused) return "already paused"
    pausedAt = Date.now()
    saveSession()
    return label()
  }

  function resume() {
    if (!active) return "not running"
    if (!paused) return "not paused"
    var t = Date.now()
    pausedTotalMs += t - pausedAt
    pausedAt = 0
    now = t
    lastTick = t
    saveSession()
    return label()
  }

  function statusJson() {
    now = Date.now()
    return JSON.stringify({
      active: active, paused: paused, openEnded: openEnded, overtime: overtime,
      plannedMin: Math.round(plannedMs / 60000), focusedMs: Math.round(focusedMs),
      remainingMs: Math.round(remainingMs), label: label(), lockedNotice: lockedNotice,
      grey: greyOn, colourPeek: colourPeek,
      resting: resting, restLeft: resting ? clockText(restUntil - Date.now(), true) : "",
      todayMin: Math.round(todayLoggedMs() / 60000), goalMin: goalMin
    })
  }

  // Summary of the "time's up" alert on screen, so ending or extending can dismiss it.
  property string timeUpSummary: ""

  function timeUp() {
    timeUpNotified = true
    saveSession()
    run(["pw-play", chimeSound])
    // Critical + the default "notify-send" app name is what gets through Omarchy's
    // do-not-disturb; critical notifications stay until dismissed.
    timeUpSummary = "Time's up · " + minutesText(plannedMs)
    run(["notify-send", "-u", "critical", timeUpSummary,
         "Still in deep work. Super+D to end it or add 10 minutes."])
  }

  function dismissTimeUp() {
    if (!timeUpSummary) return
    run(["omarchy-shell", "notifications", "dismiss", timeUpSummary])
    timeUpSummary = ""
  }

  // --- env.sh, one call at a time ---------------------------------------------
  property var envQueue: []
  property var pendingSummary: null

  function queueEnv(action) {
    envQueue = envQueue.concat([action])
    if (!envProc.running) runNextEnv()
  }

  function runNextEnv() {
    if (envQueue.length === 0) return
    var action = envQueue[0]
    envQueue = envQueue.slice(1)
    envProc.command = ["bash", envScript, action]
    envProc.action = action
    envProc.running = true
  }

  Process {
    id: envProc
    property string action: ""
    // "ready": the bar is hidden, show the timer bar. "quiet": leaving, hide it.
    stdout: SplitParser {
      onRead: function(line) {
        if (line === "ready" && root.active) root.takeover = true
        else if (line === "grey" && root.active) root.greyOn = true
        else if (line === "quiet") {
          root.takeover = false
          root.greyOn = false
        }
      }
    }
    onExited: function(code) {
      // In case a signal line was missed.
      if (action === "enter") root.takeover = root.active
      else if (action === "leave") root.takeover = root.active
      if (action === "leave" && root.pendingSummary) {
        root.run(root.pendingSummary)
        root.pendingSummary = null
      }
      root.runNextEnv()
    }
  }

  // --- Files ------------------------------------------------------------------
  FileView {
    id: sessionFile
    path: root.sessionPath
    blockLoading: true
    atomicWrites: true
    printErrors: false
  }

  FileView {
    id: logFile
    path: root.logPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  FileView {
    id: restFile
    path: root.restPath
    blockLoading: true
    atomicWrites: true
    printErrors: false
  }

  FileView {
    id: shellJson
    path: root.shellJsonPath
    watchChanges: true
    printErrors: false
    onLoaded: root.readGoal()
    onFileChanged: reload()
  }

  // Read once at startup, to tell whether a running session's screen is grey.
  FileView {
    id: toggleFile
    path: root.toggleLua
    blockLoading: true
    printErrors: false
  }

  // Pick up a session (or a break) that was running when the shell stopped.
  Component.onCompleted: {
    // The bar pill watches the log, so make sure it exists from the start.
    run(["bash", "-c", 'mkdir -p "$1" && touch "$2"', "deepwork-init", stateDir, logPath])
    var r = null
    try { r = JSON.parse(String(restFile.text() || "")) } catch (e) { r = null }
    if (r && Number(r.until) > Date.now()) {
      restStartedAt = Number(r.start) || Date.now()
      restUntil = Number(r.until)
    } else if (r && Number(r.until) > 0) {
      saveRest()                // ended while the shell was down
    }
    var s = null
    try { s = JSON.parse(String(sessionFile.text() || "")) } catch (e) { s = null }
    if (!s || !s.active) return
    var t = Date.now()
    active = true
    startedAt = Number(s.startedAt) || t
    plannedMs = Number(s.plannedMs) || 0
    pausedAt = Number(s.pausedAt) || 0
    pausedTotalMs = Number(s.pausedTotalMs) || 0
    timeUpNotified = !!s.timeUpNotified
    // Time the shell was down doesn't count as focused (the last heartbeat is at most
    // 30 s old when it stops normally).
    var heartbeat = Number(s.heartbeat) || t
    if (!pausedAt && t - heartbeat > 30000) pausedTotalMs += t - heartbeat
    lastTick = t
    now = t
    takeover = true
    try { greyOn = String(toggleFile.text() || "").indexOf("screen_shader") >= 0 } catch (e) { greyOn = false }
    saveSession()
  }

  // --- Clock ------------------------------------------------------------------
  Timer {
    interval: 1000
    repeat: true
    running: root.active && !root.paused
    triggeredOnStart: true
    onTriggered: {
      var t = Date.now()
      // A gap of more than 30 s means the laptop slept; don't count it.
      if (root.lastTick > 0 && t - root.lastTick > 30000) {
        root.pausedTotalMs += t - root.lastTick - 1000
        root.saveSession()
      }
      root.lastTick = t
      root.now = t
      if (!root.openEnded && !root.timeUpNotified && root.remainingMs <= 0) root.timeUp()
    }
  }

  // Heartbeat, so a shell restart can tell how long it was down.
  Timer {
    interval: 30000
    repeat: true
    running: root.active
    onTriggered: root.saveSession()
  }

  // --- The timer bar -----------------------------------------------------------
  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: timerBar
      required property var modelData
      screen: modelData
      visible: root.active && root.takeover
      color: "transparent"
      anchors { top: true; left: true; right: true }
      implicitHeight: root.barHeight
      exclusionMode: ExclusionMode.Normal
      exclusiveZone: root.barHeight
      WlrLayershell.layer: WlrLayer.Top
      // looknfeel.lua blurs this namespace, like the bar.
      WlrLayershell.namespace: "sampsonml-deepwork"

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.background.r, root.background.g, root.background.b, root.backgroundAlpha)
      }

      // Progress: fills from the left as the session goes on.
      Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: Math.round(parent.width * root.progress)
        color: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, root.fillAlpha)
      }

      // Thin bottom edge in the fill colour, so the strip reads as a frame.
      Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Qt.rgba(root.fillColor.r, root.fillColor.g, root.fillColor.b, 0.8)
      }

      // The readout sits on a small dark pill, so it stays readable once the fill reaches it.
      Rectangle {
        anchors.centerIn: parent
        width: readout.implicitWidth + Style.space(24)
        height: Math.round(parent.height * 0.7)
        radius: height / 2
        color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.75)
      }

      Row {
        id: readout
        anchors.centerIn: parent
        spacing: Style.space(10)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.barLabel
          color: root.paused ? root.pausedColor : (root.overtime ? root.ember : root.copper)
          font.family: Style.font.family
          font.pixelSize: Style.font.body - 2
          font.weight: Font.DemiBold
          font.letterSpacing: 1.5
          renderType: Text.NativeRendering
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.barTime
          color: Color.foreground
          font.family: Style.font.family
          font.pixelSize: Style.font.body - 2
          font.weight: Font.DemiBold
          font.features: { "tnum": 1 }
          renderType: Text.NativeRendering
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.run([root.home + "/.local/bin/deepwork"])
      }
    }
  }

  // --- The start animation: a TV glitch (glitch.frag) -------------------------------
  NumberAnimation {
    id: introAnim
    target: root
    property: "introT"
    from: 0
    to: 1
    duration: root.introMs
  }

  Timer {
    id: stillTimeout
    interval: root.stillTimeoutMs
    onTriggered: root.beginIntro()
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: introWin
      required property var modelData
      screen: modelData
      visible: root.introCapturing || root.introT < 1
      color: "transparent"
      anchors { top: true; bottom: true; left: true; right: true }
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "sampsonml-deepwork-intro"
      // Empty input region: clicks and typing go straight through.
      mask: Region {}

      // A still of this screen, taken afresh each run while the overlay is still
      // transparent; the shader tears it up.
      Loader {
        id: still
        anchors.fill: parent
        active: introWin.visible
        sourceComponent: ScreencopyView {
          captureSource: introWin.modelData
          live: false
          paintCursor: false
          onHasContentChanged: if (hasContent) root.stillReady()
        }
      }

      ShaderEffectSource {
        id: stillTexture
        sourceItem: still.item
        hideSource: true
        visible: false
        textureSize: still.item && still.item.hasContent ? still.item.sourceSize : Qt.size(0, 0)
      }

      ShaderEffect {
        anchors.fill: parent
        property variant frame: stillTexture
        property real hasFrame: still.item && still.item.hasContent ? 1 : 0
        property real t: root.introT
        property real seconds: root.introMs / 1000
        property real seed: root.introSeed
        property vector2d sizePx: Qt.vector2d(width, height)
        property real chroma: root.introChroma
        fragmentShader: Qt.resolvedUrl("glitch.frag.qsb")
      }
    }
  }

  // --- IPC ----------------------------------------------------------------------
  IpcHandler {
    target: "deepwork"

    function start(minutes: string): string { return root.start(minutes) }
    function end(): string { return root.end() }
    function extend(minutes: string): string { return root.extend(minutes) }
    function pause(): string { return root.pause() }
    function resume(): string { return root.resume() }
    function status(): string { return root.statusJson() }
    function intro(): string { return root.playIntro() }
    function nudge(): string { return root.nudge() }
    function colour(): string { return root.colour() }
    function rest(minutes: string): string { return root.startRest(minutes) }
  }
}
OMARCHY_EOF
cat > ~/.config/omarchy/plugins/sampsonml.deepwork/env.sh <<'OMARCHY_EOF'
#!/bin/bash
# sampsonml.deepwork (4 Nov 2026): turns the desktop side of deep-work mode on and off.
# Service.qml runs it; you can also run it by hand to test or to clean up.
#
#   env.sh enter   apply everything, and save what it changed in FLAGS,
#                  e.g. "bar=1 dnd=1 awake=0" (1 = this script changed it)
#   env.sh leave   undo the Hyprland changes, plus whatever FLAGS says enter changed (so a
#                  bar you had hidden before the session stays hidden). Also the way to
#                  clean up by hand if the shell crashed mid-session.
#
# What "enter" changes:
#   - Hyprland: no gaps, no borders, unfocused windows dimmed to DIM, and the workspace
#     locked (the user's request): the workspace each monitor shows when the session starts
#     is the only one it can show until the session ends. Written as an Omarchy toggle file
#     (~/.local/state/omarchy/toggles/hypr/), which Hyprland loads after
#     ~/.config/hypr/*.lua, so a config reload mid-session keeps it.
#   - the screen goes mostly grey (GREY; the user's pick, 4 Nov 2026): grey.glsl, next to
#     this file, as Hyprland's screen shader. Super+Alt+C shows colour for a moment
#     (`omarchy-shell deepwork colour`).
#   - the bar is hidden (Omarchy's `bar-off` flag)
#   - notifications: Omarchy's do-not-disturb (critical system alerts still show)
#   - idle: "stay awake", so the 1-hour idle lock doesn't fire mid-session
#
# Windows don't slide while this happens: a second toggle file switches the windowsMove
# animation off for QUIET_SECONDS, so they jump straight to their new size.
#
# The plugin's timer bar takes the bar's place. env.sh prints "ready" once the bar is
# hidden (the plugin then shows the timer bar) and "quiet" when leaving (the plugin hides
# it), both while windows can't slide.

set -u

DIM=0.4            # dim_strength for unfocused windows (looknfeel.lua uses 0.12)
GREY=1             # 1 = grey screen during sessions, 0 = keep colour (amount: KEEP in grey.glsl)
QUIET_SECONDS=0.6  # long enough for the bar to hide/show before animations come back

TOGGLES="$HOME/.local/state/omarchy/toggles/hypr"
DEEPWORK_LUA="$TOGGLES/sampsonml-deepwork.lua"
QUIET_LUA="$TOGGLES/sampsonml-deepwork-quiet.lua"
BAR_FLAG="$HOME/.local/state/omarchy/toggles/bar-off"
AWAKE_FLAG="$HOME/.local/state/omarchy/indicators/stay-awake"
FLAGS="$HOME/.local/state/sampsonml/deepwork/env-flags"
GREY_SHADER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/grey.glsl"

quiet_start() {
  mkdir -p "$TOGGLES"
  cat > "$QUIET_LUA" <<'EOF'
-- sampsonml deep-work mode: present for under a second while the mode turns on or off,
-- so windows jump to their new size instead of sliding. Removed by env.sh.
hl.animation({ leaf = "windowsMove", enabled = false })
EOF
}

quiet_end() {
  sleep "$QUIET_SECONDS"
  rm -f "$QUIET_LUA"
  hyprctl reload >/dev/null
}

hypr_on() {
  mkdir -p "$TOGGLES"
  # The workspace each monitor shows right now, e.g.  ["HDMI-A-1"] = 2,
  local locked
  locked=$(hyprctl monitors -j | jq -r '.[] | "  [\"\(.name)\"] = \(.activeWorkspace.id),"')
  local shader=""
  [[ $GREY == 1 && -f $GREY_SHADER ]] && shader=", screen_shader = \"$GREY_SHADER\""
  cat > "$DEEPWORK_LUA" <<EOF
-- sampsonml deep-work mode is on: windows edge to edge, no borders, other windows dimmed,
-- the screen grey (if GREY=1 in env.sh) and the workspace locked. Written by
-- ~/.config/omarchy/plugins/sampsonml.deepwork/env.sh and removed when the session
-- ends. If it's left over after a crash, run
-- \`~/.config/omarchy/plugins/sampsonml.deepwork/env.sh leave\`.
hl.config({
  general = { gaps_in = 0, gaps_out = 0, border_size = 0 },
  decoration = { dim_strength = $DIM$shader },
})

-- Super+Alt+C: colour for a moment (the plugin turns the grey back on after it).
o.bind("SUPER + ALT + C", "Deep work: show colour", "omarchy-shell deepwork colour")

-- Workspace lock. The workspace each monitor showed when the session started:
local locked = {
$locked
}
-- Shows "WORKSPACE LOCKED" on the timer bar for a moment.
local nudge = "omarchy-shell deepwork nudge"

-- The workspace-switching keys (Omarchy's default/hypr/bindings/tiling.lua) only nudge.
-- Moving a window silently (Super+Shift+Alt+number) still works: it doesn't switch.
for ws = 1, 10 do
  local key = "code:" .. tostring(ws + 9)
  for _, mods in ipairs({ "SUPER + ", "SUPER + SHIFT + " }) do
    hl.unbind(mods .. key)
    o.bind(mods .. key, nil, nudge)
  end
end
for _, keys in ipairs({ "SUPER + TAB", "SUPER + SHIFT + TAB", "SUPER + CTRL + TAB",
                        "SUPER + mouse_down", "SUPER + mouse_up" }) do
  hl.unbind(keys)
  o.bind(keys, nil, nudge)
end

-- Anything else that switches (an app shortcut focusing a window elsewhere, a gesture,
-- hyprctl) is switched straight back.
hl.on("workspace.active", function()
  for _, m in ipairs(hl.get_monitors()) do
    local want = locked[m.name]
    local ws = m.active_workspace
    if want and ws and ws.id ~= want then
      hl.dispatch(hl.dsp.focus({ workspace = tostring(want) }))
      hl.exec_cmd(nudge)
    end
  end
end)
EOF
}

case "${1:-}" in
  enter)
    quiet_start
    hypr_on
    hyprctl reload >/dev/null
    [[ $GREY == 1 && -f $GREY_SHADER ]] && echo "grey"

    bar=0
    if [[ ! -e $BAR_FLAG ]]; then
      omarchy-toggle-bar on >/dev/null 2>&1 && bar=1
    fi
    echo "ready"

    dnd=0
    if [[ $(omarchy-shell notifications isDnd 2>/dev/null) == off ]]; then
      omarchy-shell notifications setDnd on >/dev/null 2>&1 && dnd=1
    fi

    awake=0
    if [[ ! -e $AWAKE_FLAG ]]; then
      omarchy-toggle-idle stay-awake >/dev/null 2>&1 && awake=1
    fi

    # Keep anything an earlier, unfinished session recorded: those changes are still in place.
    mkdir -p "$(dirname "$FLAGS")"
    if [[ -f $FLAGS ]]; then
      grep -q 'bar=1' "$FLAGS" && bar=1
      grep -q 'dnd=1' "$FLAGS" && dnd=1
      grep -q 'awake=1' "$FLAGS" && awake=1
    fi
    echo "bar=$bar dnd=$dnd awake=$awake" > "$FLAGS"

    quiet_end
    echo "bar=$bar dnd=$dnd awake=$awake"
    ;;

  leave)
    flags=$(cat "$FLAGS" 2>/dev/null)
    quiet_start
    hyprctl reload >/dev/null
    echo "quiet"
    [[ $flags == *bar=1* ]] && omarchy-toggle-bar off >/dev/null 2>&1
    rm -f "$DEEPWORK_LUA"
    hyprctl reload >/dev/null
    [[ $flags == *dnd=1* ]] && omarchy-shell notifications setDnd off >/dev/null 2>&1
    [[ $flags == *awake=1* ]] && omarchy-toggle-idle allow-idle >/dev/null 2>&1
    rm -f "$FLAGS"
    quiet_end
    echo "left (${flags:-nothing recorded})"
    ;;

  *)
    echo "usage: env.sh enter | leave" >&2
    exit 1
    ;;
esac
OMARCHY_EOF
chmod +x ~/.config/omarchy/plugins/sampsonml.deepwork/env.sh
cat > ~/.config/omarchy/plugins/sampsonml.deepwork/grey.glsl <<'OMARCHY_EOF'
#version 300 es
// Grey screen for deep-work sessions (sampsonml.deepwork, 4 Nov 2026; the user's pick from
// the "less distracting" ideas). A Hyprland screen shader, not a Qt one: env.sh enter sets
// it as decoration.screen_shader in the session's toggle file, so the whole screen loses
// most of its colour until the session ends. Bright colour is what makes thumbnails,
// badges and feeds pull at you; in grey only the work stands out.
//
// No time uniform, so it isn't hit by the screen_shader animation problem described in
// ~/customization/CLAUDE.md. Hyprland reads this file when the config loads; after
// editing it mid-session, run `hyprctl reload`.

precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;

// How much colour stays: 0 = fully grey, 1 = unchanged.
const float KEEP = 0.25;

void main() {
    vec4 c = texture(tex, v_texcoord);
    float y = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
    fragColor = vec4(mix(vec3(y), c.rgb, KEEP), c.a);
}
OMARCHY_EOF
cat > ~/.config/omarchy/plugins/sampsonml.deepwork/glitch.frag <<'OMARCHY_EOF'
#version 440
// TV-glitch intro for a deep-work session (sampsonml.deepwork, 4 Nov 2026; the user asked
// for "a tv glitch style thing" in place of the earlier rising embers). Source for
// glitch.frag.qsb; after editing, rebuild it and restart the shell:
//   /usr/lib/qt6/bin/qsb --qt6 -o glitch.frag.qsb glitch.frag
//
// `frame` is a still of the screen taken just before it starts (Service.qml). The
// sequence, with t running 0..1 (2 s by default):
//   0.00-0.28  the picture breaks up: bands of it tear sideways, the lines jitter, it
//              jumps up and down, strips turn to static, and the colour drains to grey
//   0.28-0.38  the set switches off: the picture squashes into a white line across the
//              middle, which shrinks to a dot and goes out
//   0.38-0.60  no signal: black, with faint snow and a dim band rolling down
//   0.60-1.00  the signal comes back: the black breaks into bands that open onto the
//              screen (now in deep-work mode) at random times, some flicking back to
//              static, with faint scanlines that fade out
// The screen behind is hidden from 0 to 0.6, so the bar turning into the timer bar
// happens out of sight. At t = 1 nothing is drawn. Black and white (the user's taste);
// `chroma` > 0 keeps the colour and adds a red/blue split to the torn bands.
// Output is premultiplied alpha. See-through parts stay at alpha <= 0.18, below the
// ignore_alpha (0.2) of the deep-work blur rule in looknfeel.lua.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float t;         // 0..1 across the effect
    float seconds;   // length of the effect, s
    float seed;      // new every run, so the glitches differ each time
    vec2 sizePx;     // overlay size, logical px
    float hasFrame;  // 1 once the still has arrived; without it the picture is black
    float chroma;    // 0 = black and white
};
layout(binding = 1) uniform sampler2D frame;

const float BREAK_END = 0.28;
const float OFF_END = 0.38;
const float BLACK_END = 0.60;
const vec3 LUMA = vec3(0.299, 0.587, 0.114);

float hash11(float p) {
    p = fract(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// The still; black outside it.
vec3 picture(vec2 q) {
    if (q.x < 0.0 || q.x > 1.0 || q.y < 0.0 || q.y > 1.0) return vec3(0.0);
    return textureLod(frame, q, 0.0).rgb * hasFrame;
}

// TV snow in cells of 1.5 logical px, new every tick.
float snow(vec2 p, float tick) {
    return hash12(floor(p / 1.5) + vec2(tick * 37.0, seed * 13.0));
}

// Scanlines every 3 logical px: 0 between lines, 1 on them.
float scanline(vec2 p) {
    return 0.5 + 0.5 * sin(p.y * 6.2832 / 3.0);
}

vec4 breakUp(vec2 uv, vec2 p, float tick, float k) {
    float amt = mix(0.3, 1.0, k);   // glitchier as it goes
    float s = seed;

    // Vertical hold: on some ticks the whole picture jumps up or down.
    float jump = step(hash11(tick * 1.31 + s), 0.3 * amt) * (hash11(tick * 2.17 + s) - 0.5) * 0.06 * amt;
    // Bands of random height, laid out afresh every tick; some tear sideways.
    float bh = mix(0.015, 0.09, hash11(tick * 3.7 + s));
    float band = floor((uv.y + hash11(tick * 5.9 + s)) / bh);
    float tear = step(hash12(vec2(band, tick + s)), 0.3 * amt)
               * (hash12(vec2(band * 1.7, tick * 2.3 + s)) - 0.5) * 0.3 * amt;
    // Every line wobbles a little.
    float line = floor(p.y / 2.0);
    float wobble = (hash12(vec2(line, tick * 0.37 + s)) - 0.5) * 0.006 * amt;

    vec2 q = vec2(uv.x + tear + wobble, uv.y + jump);
    vec3 c;
    if (chroma > 0.0) {
        float split = chroma * (abs(tear) * 0.15 + 0.002 * amt);
        c = vec3(picture(q + vec2(split, 0.0)).r, picture(q).g, picture(q - vec2(split, 0.0)).b);
    } else {
        c = picture(q);
    }
    // The colour drains to grey.
    c = mix(c, vec3(dot(c, LUMA)), smoothstep(0.0, 0.7, k) * (1.0 - min(chroma, 1.0)));

    // Strips of static, and the odd bright line.
    float static_ = step(1.0 - 0.18 * amt, hash12(vec2(band * 3.1 + 7.0, tick * 0.71 + s)));
    c = mix(c, vec3(snow(p, tick) * 0.85), static_);
    float streak = step(0.996, hash12(vec2(line * 0.5, tick + s * 3.0)));
    c = mix(c, vec3(0.9), streak * amt * 0.6);

    // Scanlines and flicker.
    c *= 1.0 - 0.22 * amt * scanline(p);
    c *= 1.0 + (hash11(tick * 9.7 + s) - 0.5) * 0.35 * amt;
    return vec4(clamp(c, 0.0, 1.0), 1.0);
}

vec4 switchOff(vec2 uv, float k) {
    float squash = smoothstep(0.0, 0.55, k);
    float h = mix(1.0, 0.0025, squash);          // picture height, fraction of the screen
    float w = 1.0 - smoothstep(0.5, 0.95, k);    // then the line shrinks to a dot
    vec2 c = uv - 0.5;
    if (abs(c.y) > h * 0.5 || abs(c.x) > w * 0.5) return vec4(0.0, 0.0, 0.0, 1.0);
    vec2 q = vec2(0.5 + c.x / max(w, 0.001), 0.5 + c.y / h);
    vec3 img = picture(q);
    img = mix(img, vec3(dot(img, LUMA)), 1.0 - min(chroma, 1.0));
    img = mix(img, vec3(1.0), smoothstep(0.6, 1.0, squash));   // turns white as it becomes the line
    img *= 1.0 - smoothstep(0.85, 1.0, k);       // and goes out
    return vec4(img, 1.0);
}

vec4 noSignal(vec2 uv, vec2 p, float time, float tick, float k) {
    float bandY = fract(time * 0.7 + seed);
    float roll = exp(-pow((uv.y - bandY) / 0.08, 2.0));
    float v = snow(p, tick) * (0.07 + 0.08 * roll) * smoothstep(0.0, 0.25, k);
    return vec4(vec3(v), 1.0);
}

vec4 comeBack(vec2 uv, vec2 p, float tick, float k) {
    float band = floor(uv.y * 36.0);
    float open = step(hash12(vec2(band, seed)) * 0.65, k);   // each band opens at its own time
    // An open band sometimes flicks back to static for a tick, less often as it settles.
    float relapse = step(hash12(vec2(band * 1.9, tick + seed)), 0.25 * (1.0 - k)) * open;
    open *= 1.0 - relapse;
    vec3 closed = vec3(snow(p, tick) * mix(0.12, 0.6, relapse));
    float scanA = 0.18 * (1.0 - smoothstep(0.6, 1.0, k)) * scanline(p);
    float a = mix(1.0, scanA, open);
    vec3 rgb = closed * (1.0 - open);             // open bands: only the dark scanlines
    return vec4(rgb, a);
}

void main() {
    if (t >= 1.0) { fragColor = vec4(0.0); return; }
    vec2 uv = qt_TexCoord0;
    vec2 p = uv * sizePx;
    float time = t * seconds;
    float tick = floor(time * 24.0);              // the glitches change 24 times a second

    vec4 o;
    if (t < BREAK_END) o = breakUp(uv, p, tick, t / BREAK_END);
    else if (t < OFF_END) o = switchOff(uv, (t - BREAK_END) / (OFF_END - BREAK_END));
    else if (t < BLACK_END) o = noSignal(uv, p, time, tick, (t - OFF_END) / (BLACK_END - OFF_END));
    else o = comeBack(uv, p, tick, (t - BLACK_END) / (1.0 - BLACK_END));
    fragColor = o * qt_Opacity;
}
OMARCHY_EOF
```

Compile the shader. `qsb` comes with Qt (`qt6-shadertools`, normally already installed as a dependency):

```bash
[ -x /usr/lib/qt6/bin/qsb ] || omarchy pkg add qt6-shadertools
cd ~/.config/omarchy/plugins/sampsonml.deepwork && /usr/lib/qt6/bin/qsb --qt6 -o glitch.frag.qsb glitch.frag && cd ~
```

The menu, `~/.local/bin/deepwork` (it uses Omarchy's menu, and `jq`):

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/deepwork <<'OMARCHY_EOF'
#!/bin/bash
# deepwork (sampsonml, 4 Nov 2026): the Super+D menu for deep-work mode.
#
# No session running: pick a length (25, 50 or 90 min, or open-ended). The menu's title
# shows today's total against the daily goal. During the break after a session it asks
# first: "Keep resting" (the default) or "Start anyway".
# Session running: end it, add 10 minutes, pause/resume, or show colour for a moment
# (the screen is grey during a session; Super+Alt+C does the same).
#
# The work is done by the sampsonml.deepwork shell plugin
# (~/.config/omarchy/plugins/sampsonml.deepwork/); this only shows Omarchy's menu and
# calls the plugin over IPC. `deepwork <method> [arg]` passes straight through, e.g.
# `deepwork start 50`, `deepwork end`, `deepwork status`.

set -uo pipefail

if [[ $# -gt 0 ]]; then
  exec omarchy-shell deepwork "$@"
fi

status=$(omarchy-shell deepwork status 2>/dev/null)
if [[ -z $status ]] || ! jq -e . >/dev/null 2>&1 <<<"$status"; then
  notify-send "Deep work" "The shell isn't running the sampsonml.deepwork plugin. Try: omarchy restart shell"
  exit 1
fi

TIMER=$'\U000F051B'      # nf-md-timer
OPEN=$'\U000F051F'       # nf-md-timer_sand
STOP=$'\U000F04DB'       # nf-md-stop
PLUS=$'\U000F0415'       # nf-md-plus
PAUSE=$'\U000F03E4'      # nf-md-pause
PLAY=$'\U000F040A'       # nf-md-play
COFFEE=$'\U000F0176'     # nf-md-coffee
PALETTE=$'\U000F03D8'    # nf-md-palette

# "2h 35m", "45m"; "3h" for whole hours.
duration() {
  local h=$(($1 / 60)) m=$(($1 % 60))
  if ((h > 0 && m == 0)); then echo "${h}h"
  elif ((h > 0)); then printf '%dh %02dm\n' "$h" "$m"
  else echo "${m}m"; fi
}

if [[ $(jq -r .active <<<"$status") != true ]]; then
  if [[ $(jq -r .resting <<<"$status") == true ]]; then
    choice=$(omarchy-menu-select "On a break · $(jq -r .restLeft <<<"$status") left" \
      "$COFFEE"$'\t'"Keep resting" \
      "$TIMER"$'\t'"Start anyway") || exit 0
    [[ $choice == "Start anyway" ]] || exit 0
  fi
  today=$(duration "$(jq -r .todayMin <<<"$status")")
  goal=$(jq -r .goalMin <<<"$status")
  if ((goal > 0)); then title="Deep work · $today of $(duration "$goal") today"
  else title="Deep work · $today today"; fi
  choice=$(omarchy-menu-select "$title" \
    "$TIMER"$'\t'"25 min" \
    "$TIMER"$'\t'"50 min" \
    "$TIMER"$'\t'"90 min" \
    "$OPEN"$'\t'"Open-ended") || exit 0
  case $choice in
    "25 min") minutes=25 ;;
    "50 min") minutes=50 ;;
    "90 min") minutes=90 ;;
    "Open-ended") minutes=0 ;;
    *) exit 0 ;;
  esac
  omarchy-shell deepwork start "$minutes" >/dev/null
  exit 0
fi

label=$(jq -r .label <<<"$status")
options=("$STOP"$'\t'"End now")
[[ $(jq -r .openEnded <<<"$status") != true ]] && options+=("$PLUS"$'\t'"Add 10 min")
if [[ $(jq -r .paused <<<"$status") == true ]]; then
  options+=("$PLAY"$'\t'"Resume")
else
  options+=("$PAUSE"$'\t'"Pause")
fi
if [[ $(jq -r .colourPeek <<<"$status") == true ]]; then
  options+=("$PALETTE"$'\t'"Back to grey")
elif [[ $(jq -r .grey <<<"$status") == true ]]; then
  options+=("$PALETTE"$'\t'"Show colour (20 s)")
fi

choice=$(omarchy-menu-select "Deep work · $label" "${options[@]}") || exit 0
case $choice in
  "End now") omarchy-shell deepwork end ;;
  "Add 10 min") omarchy-shell deepwork extend 10 ;;
  "Pause") omarchy-shell deepwork pause ;;
  "Resume") omarchy-shell deepwork resume ;;
  "Show colour (20 s)" | "Back to grey") omarchy-shell deepwork colour ;;
esac >/dev/null
OMARCHY_EOF
chmod +x ~/.local/bin/deepwork
```

### 7.5 Daily to-do list

A to-do list for the day (5 Nov 2026; you chose the design): a pill right of the deep-work pill reading `tasks 3/5 ✓` (all lowercase, as you asked). It fills with the theme's accent as you tick tasks off and turns solid once they're all done. With nothing planned it says `plan the day` in the accent colour.

- **Left click** opens a dropdown with today's date, progress, the tasks (click one to tick it, × to delete it) and a box to add one. The cursor starts in the box, so you can type a task and press Enter straight away. Keys: in the box, Enter adds, Esc clears it or closes, and ↑ or Tab moves to the list. In the list, j/k move, Space ticks, x deletes, a goes back to the box and e opens Neovim.
- **Right click** (or *Edit in Neovim* in the dropdown) opens the list in Neovim.
- **The list is a markdown checklist in `~/todo.md`**, headed with the date (`# 2026-11-05 Thursday`, then `- [ ] task` / `- [x] task`). Edits made in Neovim show up in the bar straight away, and other lines (notes, sub-headings) are left alone.
- **A new day:** the first check after midnight (on load and every minute) clears the ticked tasks, keeps the unticked ones marked with the day they came from (`(from Wed 4 Nov)`, shown as `↻ Wed 4 Nov`) and moves the heading to today.
- `omarchy-shell sampsonml.todo add "<task>"` adds a task from a script, and `status` prints `done/total`.

The plugin is four files: `Model.js` (reading and changing the list, as plain functions), `BarWidget.qml` (the pill and the file), `Panel.qml` (the dropdown) and the manifest. It's placed in the bar by `shell.json` (step 7.6).

```bash
mkdir -p ~/.config/omarchy/plugins/sampsonml.todo
cat > ~/.config/omarchy/plugins/sampsonml.todo/manifest.json <<'OMARCHY_EOF'
{
  "schemaVersion": 1,
  "id": "sampsonml.todo",
  "name": "Today's Tasks",
  "version": "1.0.0",
  "author": "sampsonml",
  "description": "A daily to-do list: a 'Tasks 3/5' pill that fills as tasks are ticked off, and a dropdown to add, tick and delete them. The list is a markdown checklist in ~/todo.md, so it can also be edited in Neovim. Unticked tasks carry over to the next day.",
  "kinds": [
    "bar-widget"
  ],
  "entryPoints": {
    "barWidget": "BarWidget.qml"
  },
  "barWidget": {
    "displayName": "Today's Tasks",
    "description": "Daily to-do list with a dropdown checklist",
    "category": "Productivity",
    "allowMultiple": false
  }
}
OMARCHY_EOF
cat > ~/.config/omarchy/plugins/sampsonml.todo/Model.js <<'OMARCHY_EOF'
.pragma library

// Daily to-do list (sampsonml, 5 Nov 2026): the list is a markdown checklist in a plain
// file (~/todo.md by default), so it can be edited in Neovim as well as in the dropdown.
//
//   # 2026-11-05 Thursday
//
//   - [ ] Write the referee report
//   - [x] Email Rudy
//   - [ ] Fix figure 3 (from Wed 4 Nov)
//
// The first heading that holds an ISO date says which day the list is for. When a new
// day starts, rollover() drops the ticked tasks, keeps the unticked ones (marking each
// with the day it was first carried from, once) and moves the heading to today. Any
// other lines (notes, sub-headings) are left alone. Every change is made line by line,
// so nothing else in the file is touched.
//
// Pure functions only: BarWidget.qml reads and writes the file. Keeping it free of QML
// means it can be tested with node (drop the .pragma line and eval it).

var TASK_RE = /^(\s*)([-*+])\s+\[([ xX])\]\s?(.*)$/
var DATE_HEADING_RE = /^#{1,6}\s.*?(\d{4}-\d{2}-\d{2})/
var FROM_RE = /\s+\(from ([^)]+)\)\s*$/

var DAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

function pad(n) { return n < 10 ? "0" + n : String(n) }

// Local date as "2026-11-05".
function isoDate(d) {
  return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate())
}

function dateFromIso(iso) {
  var m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(iso || ""))
  return m ? new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 12) : null
}

// "Wed 4 Nov"
function shortDay(iso) {
  var d = dateFromIso(iso)
  return d ? DAYS[d.getDay()].slice(0, 3) + " " + d.getDate() + " " + MONTHS[d.getMonth()] : ""
}

// "# 2026-11-05 Thursday"
function heading(iso) {
  var d = dateFromIso(iso)
  return "# " + iso + (d ? " " + DAYS[d.getDay()] : "")
}

function splitLines(text) {
  return String(text || "").replace(/\r\n/g, "\n").split("\n")
}

// Lines back to text, with exactly one newline at the end.
function joinLines(lines) {
  return lines.join("\n").replace(/\n*$/, "") + "\n"
}

// { date: "2026-11-05" or "", tasks: [{ line, done, text, from, raw }] }
// `text` is the task without its "(from ...)" mark; `from` is that mark ("" if none).
function parse(text) {
  var lines = splitLines(text)
  var date = ""
  var tasks = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (!date) {
      var h = DATE_HEADING_RE.exec(line)
      if (h) { date = h[1]; continue }
    }
    var m = TASK_RE.exec(line)
    if (!m) continue
    var body = m[4]
    var from = ""
    var f = FROM_RE.exec(body)
    if (f) { from = f[1]; body = body.slice(0, f.index) }
    tasks.push({ line: i, done: m[3] !== " ", text: body.trim(), from: from, raw: line })
  }
  return { date: date, tasks: tasks }
}

// A brand-new list for today.
function fresh(todayIso) {
  return heading(todayIso) + "\n\n"
}

// The text for today, or null if the file is already today's (or dated in the future,
// e.g. after the clock was wrong; it's left alone then).
function rollover(text, todayIso) {
  var lines = splitLines(text)
  var parsed = parse(text)
  if (parsed.date === todayIso || (parsed.date && parsed.date > todayIso)) return null
  if (!parsed.date) {
    // No date yet (a list written by hand): take it as today's and add the heading.
    var body = String(text || "").replace(/^\n+/, "")
    return body.trim() ? joinLines([heading(todayIso), ""].concat(splitLines(body))) : fresh(todayIso)
  }
  var fromDay = shortDay(parsed.date)
  var out = []
  var headingDone = false
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (!headingDone && DATE_HEADING_RE.test(line)) {
      out.push(heading(todayIso))
      headingDone = true
      continue
    }
    var m = TASK_RE.exec(line)
    if (m) {
      if (m[3] !== " ") continue            // done yesterday: cleared
      if (!FROM_RE.test(m[4]) && fromDay) line = line.replace(/\s*$/, "") + " (from " + fromDay + ")"
    }
    // Removing ticked tasks can leave blank lines next to each other: keep one.
    if (line.trim() === "" && out.length > 0 && out[out.length - 1].trim() === "") continue
    out.push(line)
  }
  return joinLines(out)
}

// Where `task` is in `lines` now: its own line if that still holds it, else the first
// line with the same text (the file may have been edited since it was read), else -1.
function findLine(lines, task) {
  if (!task) return -1
  if (task.line >= 0 && task.line < lines.length && lines[task.line] === task.raw) return task.line
  for (var i = 0; i < lines.length; i++) if (lines[i] === task.raw) return i
  return -1
}

function toggle(text, task) {
  var lines = splitLines(text)
  var i = findLine(lines, task)
  if (i < 0) return null
  var m = TASK_RE.exec(lines[i])
  if (!m) return null
  var done = m[3] !== " "
  lines[i] = lines[i].replace(/\[([ xX])\]/, done ? "[ ]" : "[x]")
  return joinLines(lines)
}

function remove(text, task) {
  var lines = splitLines(text)
  var i = findLine(lines, task)
  if (i < 0) return null
  lines.splice(i, 1)
  return joinLines(lines)
}

// One line of plain text: newlines become spaces, outer spaces go.
function cleanTaskText(s) {
  return String(s || "").replace(/[\r\n]+/g, " ").trim()
}

// Adds "- [ ] <text>" after the last task, or after the date heading if there is none.
function add(text, taskText, todayIso) {
  var t = cleanTaskText(taskText)
  if (!t) return null
  var source = String(text || "").trim() ? text : fresh(todayIso)
  var lines = splitLines(source)
  while (lines.length > 0 && lines[lines.length - 1].trim() === "") lines.pop()
  var parsed = parse(source)
  var newLine = "- [ ] " + t
  if (parsed.tasks.length > 0) {
    lines.splice(parsed.tasks[parsed.tasks.length - 1].line + 1, 0, newLine)
  } else {
    var at = -1
    for (var i = 0; i < lines.length; i++) if (DATE_HEADING_RE.test(lines[i])) { at = i; break }
    if (at < 0) lines.push(newLine)
    else {
      // Keep a blank line between the heading and the list.
      if (at + 1 >= lines.length || lines[at + 1].trim() !== "") lines.splice(at + 1, 0, "")
      lines.splice(at + 2, 0, newLine)
    }
  }
  return joinLines(lines)
}
OMARCHY_EOF
cat > ~/.config/omarchy/plugins/sampsonml.todo/BarWidget.qml <<'OMARCHY_EOF'
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Today's tasks (sampsonml, 5 Nov 2026; the user chose every design point): a pill in the
// bar, right of the deep-work pill, reading "tasks 3/5 ✓". It fills with the theme's
// accent as tasks are ticked off and turns solid (dark text) once all are done. With no
// tasks it says "plan the day" in the accent colour instead. Both all lowercase: the
// user asked for that.
//
// Left click: the dropdown (Panel.qml) to add, tick and delete tasks.
// Right click: the list in Neovim (omarchy-launch-editor).
//
// The list lives in a markdown checklist, ~/todo.md (Model.js has the format). This widget
// owns the file: it reads it (and picks up edits made in Neovim), writes every change the
// dropdown makes, and at the first check of a new day (on load and every minute) carries
// the unticked tasks over and clears the ticked ones.
//
// There's one instance per monitor. They all watch the same file, and the new-day
// rewrite gives the same text whichever instance does it, so they can't disagree.
//
// shell.json entry: { "id": "sampsonml.todo" }, optional "file" (default "~/todo.md").
// IPC: omarchy-shell sampsonml.todo toggle | open | close | add "<task>" | status
BarWidget {
  id: root
  moduleName: "sampsonml.todo"

  readonly property string home: Quickshell.env("HOME")
  readonly property string filePath: {
    var p = String(setting("file", "~/todo.md"))
    return p.indexOf("~/") === 0 ? home + p.slice(1) : p
  }

  // The list as last read or written.
  property string fileText: ""
  property bool fileReady: false
  property var tasks: []
  property string listDate: ""
  property date today: new Date()

  readonly property int total: tasks.length
  readonly property int doneCount: {
    var n = 0
    for (var i = 0; i < tasks.length; i++) if (tasks[i].done) n++
    return n
  }
  readonly property bool allDone: total > 0 && doneCount === total
  readonly property bool planned: total > 0
  readonly property real progress: total > 0 ? doneCount / total : 0

  // ---- File -------------------------------------------------------------------
  function applyText(text) {
    fileText = text
    var parsed = Model.parse(text)
    tasks = parsed.tasks
    listDate = parsed.date
  }

  function write(text) {
    if (text === null || text === undefined) return
    applyText(text)
    todoFile.setText(text)
  }

  // A new day: carry the unticked tasks over (Model.rollover returns null if the list
  // is already today's).
  function ensureToday() {
    today = new Date()
    if (!fileReady) return
    write(Model.rollover(fileText, Model.isoDate(today)))
  }

  function toggleTask(index) {
    if (index >= 0 && index < tasks.length) write(Model.toggle(fileText, tasks[index]))
  }

  function removeTask(index) {
    if (index >= 0 && index < tasks.length) write(Model.remove(fileText, tasks[index]))
  }

  function addTask(text) {
    ensureToday()
    write(Model.add(fileText, text, Model.isoDate(today)))
  }

  function openEditor() {
    close()
    Util.execArgv(["omarchy-launch-editor", filePath])
  }

  function tooltipText() {
    if (!planned) return "Nothing planned for today yet\nClick to add tasks · right-click: edit in Neovim"
    return "Today: " + doneCount + " of " + total + " tasks done"
      + "\nClick to open · right-click: edit in Neovim"
  }

  FileView {
    id: todoFile
    path: root.filePath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: {
      root.fileReady = true
      root.applyText(String(todoFile.text() || ""))
      root.ensureToday()
    }
    // Usually: no file yet. Create it, but only if it's still missing: Neovim saves by
    // renaming, so for a moment the file can be absent, and writing then would clobber
    // what it saves (set -C makes the shell refuse to overwrite an existing file).
    onLoadFailed: {
      if (createProc.running) return
      createProc.command = ["bash", "-c", 'set -C; printf "%s" "$2" > "$1" 2>/dev/null; true',
        "todo-create", root.filePath, Model.fresh(Model.isoDate(new Date()))]
      createProc.running = true
    }
    onFileChanged: reload()
  }

  Process {
    id: createProc
    onExited: todoFile.reload()
  }

  // A new day while nothing else happens (also re-reads the file, in case a change
  // notification was missed).
  Timer {
    interval: 60000
    repeat: true
    running: true
    onTriggered: todoFile.reload()
  }

  // ---- Dropdown (same shape as the clock's calendar: the bar finds a panel through
  //      open/close/opened on the widget root). --------------------------------------
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    todoFile.reload()
    if (panelLoader.item) panelLoader.item.open()
  }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { opened ? close() : open() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "sampsonml.todo"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function add(task: string): void { root.addTask(task) }
    function status(): string { return root.doneCount + "/" + root.total }
  }

  // ---- The pill ---------------------------------------------------------------------
  readonly property color accent: Commons.Color.accent
  readonly property color dark: Commons.Color.background
  readonly property color textColor: bar ? bar.barForeground : Commons.Color.foreground
  readonly property real pillHeight: Math.round(barSize * 0.6)
  readonly property real padX: Style.space(9)
  readonly property int textSize: Style.font.body - 2  // bar text size (see mortality.qml)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: pill.width + Style.space(4)
    tooltipText: root.tooltipText()

    onPressed: function(b) {
      if (b === Qt.RightButton) root.openEditor()
      else root.togglePanel()
    }

    Item {
      id: pill
      anchors.centerIn: parent
      width: row.implicitWidth + root.padX * 2
      height: root.pillHeight

      // Progress from the left: a full-size rounded shape clipped to the progress
      // width, so the left end stays round (as on the deep-work pill).
      Item {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: Math.round(parent.width * (root.allDone ? 1 : root.progress))
        clip: true

        Rectangle {
          width: pill.width
          height: pill.height
          radius: height / 2
          color: root.allDone ? root.accent : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3)
        }
      }

      Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: "transparent"
        border.width: 1
        border.color: root.accent
      }

      Row {
        id: row
        anchors.centerIn: parent
        // "plan the day" has descenders (p, y) that touched the bottom border when
        // centred, so it sits a point higher (the user asked, 5 Nov 2026).
        anchors.verticalCenterOffset: root.planned ? 0 : -1
        spacing: Style.space(5)

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: root.planned ? "tasks " + root.doneCount + "/" + root.total : "plan the day"
          color: root.allDone ? root.dark : (root.planned ? root.textColor : root.accent)
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: root.textSize
          font.features: { "tnum": 1 }
          renderType: Text.NativeRendering
        }

        // A tick (nf-md-check, U+F012C, written as a UTF-16 surrogate pair).
        Text {
          visible: root.planned
          anchors.verticalCenter: parent.verticalCenter
          text: "󰄬"
          color: root.allDone ? root.dark : root.accent
          font.family: "Iosevka Nerd Font Propo"
          font.pixelSize: root.textSize + 1
          renderType: Text.NativeRendering
        }
      }
    }
  }
}
OMARCHY_EOF
cat > ~/.config/omarchy/plugins/sampsonml.todo/Panel.qml <<'OMARCHY_EOF'
import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// The to-do dropdown (sampsonml, 5 Nov 2026): today's date and progress, the tasks
// (click one to tick it, × to delete it; carried-over ones show the day they're from),
// a box to add tasks and a button that opens the list in Neovim.
//
// It opens with the cursor in the add box, so you can type a task and press Enter
// straight away. Keys:
//   in the box:   Enter adds · Esc clears the box, or closes if it's empty · ↑ or Tab: the list
//   in the list:  j/k or ↑/↓ move · Space or Enter ticks · x deletes · a, i or o: back to
//                 the box (so does ↓ past the last task) · e: Neovim · Esc closes
//
// BarWidget.qml owns the list and the file; this panel only shows it and calls back.
Panel {
  id: root
  moduleName: "sampsonml.todo"
  ipcTarget: "sampsonml.todo"
  manageIpc: false

  property var anchorItem: null
  // The bar knows the widget in its slot, not this panel, so the widget is what the
  // popout coordinator compares against (see the clock's Panel.qml).
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var host: hostWidget

  readonly property var tasks: host ? host.tasks : []
  readonly property int total: host ? host.total : 0
  readonly property int doneCount: host ? host.doneCount : 0

  // Keyboard cursor in the list (-1: none); shown only while the list has focus.
  property int cursor: -1
  property bool listFocused: false

  readonly property color fg: bar ? bar.foreground : Commons.Color.foreground
  readonly property color dimFg: Qt.darker(fg, 1.6)
  readonly property color accent: Commons.Color.accent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string iconFont: "Iosevka Nerd Font Propo"

  function open() {
    cursor = -1
    listFocused = false
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function focusAdd() {
    listFocused = false
    cursor = -1
    addField.forceActiveFocus()
  }

  function focusList(index) {
    if (total === 0) return
    cursor = Math.max(0, Math.min(index, total - 1))
    listFocused = true
    keyCatcher.forceActiveFocus()
    ensureVisible(cursor)
  }

  function moveCursor(delta) {
    var next = cursor + delta
    if (next >= total) { focusAdd(); return }
    cursor = Math.max(0, next)
    ensureVisible(cursor)
  }

  function ensureVisible(index) {
    var item = taskRepeater.itemAt(index)
    if (!item) return
    if (item.y < listScroll.contentY) listScroll.contentY = item.y
    else if (item.y + item.height > listScroll.contentY + listScroll.height)
      listScroll.contentY = item.y + item.height - listScroll.height
  }

  function addFromField() {
    var t = addField.text
    if (!String(t).trim()) return
    if (host) host.addTask(t)
    addField.text = ""
    Qt.callLater(function() { listScroll.contentY = Math.max(0, listScroll.contentHeight - listScroll.height) })
  }

  function deleteAtCursor() {
    if (!host || cursor < 0 || cursor >= total) return
    host.removeTask(cursor)
    Qt.callLater(function() {
      if (root.total === 0) root.focusAdd()
      else root.cursor = Math.min(root.cursor, root.total - 1)
    })
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: addField
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: addField.activeFocus
      onMoveRequested: function(dx, dy) {
        if (dy === 0) return
        if (root.cursor < 0) root.focusList(dy > 0 ? 0 : root.total - 1)
        else root.moveCursor(dy)
      }
      onActivateRequested: if (root.host && root.cursor >= 0) root.host.toggleTask(root.cursor)
      onDeleteRequested: root.deleteAtCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.focusAdd() }
      onTextKey: function(t) {
        if (t === "a" || t === "i" || t === "o") root.focusAdd()
        else if (t === "e" && root.host) root.host.openEditor()
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        // ---- Today and how far through the list you are.
        Item {
          width: parent.width
          height: Math.max(dateText.implicitHeight, countText.implicitHeight)

          Text {
            id: dateText
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: Qt.formatDate(root.host ? root.host.today : new Date(), "dddd d MMMM")
            color: root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Text {
            id: countText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: root.total === 0 ? "Nothing planned yet"
              : (root.doneCount === root.total ? "All done" : root.doneCount + " of " + root.total + " done")
            color: root.total > 0 && root.doneCount === root.total ? root.accent : root.dimFg
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Item {
          width: parent.width
          height: Style.space(4)
          visible: root.total > 0

          Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
          }

          Rectangle {
            width: Math.round(parent.width * (root.total > 0 ? root.doneCount / root.total : 0))
            height: parent.height
            radius: height / 2
            color: root.accent
            Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
          }
        }

        // ---- The tasks.
        Text {
          width: parent.width
          visible: root.total === 0
          topPadding: Style.space(4)
          bottomPadding: Style.space(4)
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          text: "What's on today? Type a task below and press Enter."
          color: root.dimFg
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        Flickable {
          id: listScroll
          width: parent.width
          visible: root.total > 0
          height: Math.min(listColumn.implicitHeight, Style.space(380))
          contentWidth: width
          contentHeight: listColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height

          Column {
            id: listColumn
            width: listScroll.width
            spacing: Style.space(2)

            Repeater {
              id: taskRepeater
              model: root.tasks
              delegate: TaskRow {}
            }
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.fg
        }

        // ---- Add a task.
        TextField {
          id: addField
          width: parent.width
          placeholderText: "Add a task and press Enter"
          foreground: root.fg
          font.family: root.fontFamily

          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.addFromField()
              event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              if (addField.text !== "") addField.text = ""
              else root.close()
              event.accepted = true
            } else if (event.key === Qt.Key_Up || event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
              root.focusList(root.total - 1)
              event.accepted = true
            }
          }
        }

        Item {
          width: parent.width
          height: editButton.implicitHeight

          Button {
            id: editButton
            anchors.left: parent.left
            iconText: ""  // nf-custom-vim
            text: "Edit in Neovim"
            fontSize: Style.font.bodySmall
            foreground: root.fg
            fontFamily: root.fontFamily
            bordered: true
            onClicked: if (root.host) root.host.openEditor()
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - editButton.width - Style.space(12)
            horizontalAlignment: Text.AlignRight
            textFormat: Text.PlainText
            elide: Text.ElideLeft
            text: root.listFocused ? "j/k move · space ticks · x deletes · a adds"
              : (root.total > 0 ? "↑ to the list" : "")
            color: root.dimFg
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }

  // One task: checkbox, text (struck through once done), the day it was carried over
  // from, and a × on hover.
  component TaskRow: Item {
    id: row

    required property var modelData
    required property int index

    readonly property bool done: modelData.done === true
    readonly property bool hot: rowMouse.containsMouse || deleteMouse.containsMouse
      || (root.listFocused && root.cursor === index)

    width: listColumn.width
    height: Math.max(taskText.implicitHeight, Style.space(22)) + Style.space(10)

    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: row.hot ? Style.hoverFillFor(root.fg, root.accent) : "transparent"
    }

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: if (root.host) root.host.toggleTask(row.index)
    }

    // nf-md-checkbox_marked / checkbox_blank_outline (U+F0132 / U+F0131).
    Text {
      id: box
      x: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: row.done ? "󰄲" : "󰄱"
      color: row.done ? root.accent : root.dimFg
      font.family: root.iconFont
      font.pixelSize: Style.font.title + 2
    }

    Text {
      id: taskText
      anchors.left: box.right
      anchors.leftMargin: Style.space(10)
      anchors.right: fromLabel.visible ? fromLabel.left : deleteSlot.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      wrapMode: Text.Wrap
      text: row.modelData.text
      color: row.done ? root.dimFg : root.fg
      font.strikeout: row.done
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    // Carried over: "↻ Wed 4 Nov".
    Text {
      id: fromLabel
      visible: String(row.modelData.from || "") !== ""
      anchors.right: deleteSlot.left
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: "↻ " + row.modelData.from
      color: root.dimFg
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Item {
      id: deleteSlot
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      width: Style.space(24)
      height: parent.height

      // nf-md-close (U+F0156).
      Text {
        anchors.centerIn: parent
        visible: row.hot
        text: "󰅖"
        color: deleteMouse.containsMouse ? Commons.Color.urgent : root.dimFg
        font.family: root.iconFont
        font.pixelSize: Style.font.title
      }

      MouseArea {
        id: deleteMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.host) root.host.removeTask(row.index)
      }
    }
  }
}
OMARCHY_EOF
```

### 7.6 Bar layout, idle and plugin settings

`shell.json` is read as it is, without merging in Omarchy's defaults. It does four things:
- **Bar layout:** uses the cloned bar, workspaces and lock plugins, and places the custom widgets.
- **Idle:** turns the screensaver off (`0`) and locks after 3600 s (1 hour) of idle.
- **Lock screen:** enables `sampsonml.lock` instead of `omarchy.lock`.
- **Deep work:** enables the `sampsonml.deepwork` plugin (step 7.4) and puts its pill after the workspace pills.
- **To-do list:** puts the `sampsonml.todo` pill (step 7.5) after the deep-work pill.

The `birth` value is the mortality counter's start date, and `goal` on the deep-work pill is the daily target in minutes.

`~/.config/omarchy/shell.json`:

```bash
mkdir -p ~/.config/omarchy
cat > ~/.config/omarchy/shell.json <<'OMARCHY_EOF'
{
  "version": 1,
  "idle": {
    "screensaver": 0,
    "lock": 3600
  },
  "bar": {
    "position": "top",
    "transparent": false,
    "centerAnchor": "sampsonml.clock",
    "layout": {
      "left": [
        {
          "id": "beaker-menu",
          "type": "qml"
        },
        {
          "id": "sampsonml.workspaces"
        },
        {
          "id": "deepwork",
          "type": "qml",
          "goal": 180
        },
        {
          "id": "sampsonml.todo"
        }
      ],
      "center": [
        {
          "id": "omarchy.indicators"
        },
        {
          "id": "sampsonml.clock",
          "format": "dddd HH:mm",
          "formatAlt": "d MMMM 'W'ww yyyy",
          "verticalFormat": "HH\n—\nmm"
        },
        {
          "id": "omarchy.keyboard-layout"
        },
        {
          "id": "omarchy.weather"
        },
        {
          "id": "omarchy.system-update"
        }
      ],
      "right": [
        {
          "id": "mortality",
          "type": "qml",
          "birth": "1992-03-25",
          "decimals": 7
        },
        {
          "id": "omarchy.tray"
        },
        {
          "id": "omarchy.agents"
        },
        {
          "id": "omarchy.bluetooth"
        },
        {
          "id": "princeton-vpn",
          "type": "qml"
        },
        {
          "id": "omarchy.network"
        },
        {
          "id": "omarchy.audio"
        },
        {
          "id": "omarchy.monitor"
        },
        {
          "id": "power-draw",
          "type": "qml"
        },
        {
          "id": "omarchy.power"
        }
      ]
    },
    "id": "sampsonml.bar"
  },
  "plugins": [
    {
      "id": "sampsonml.lock"
    },
    {
      "id": "sampsonml.deepwork"
    }
  ],
  "disabledPlugins": [
    "omarchy.lock"
  ],
  "cloneSourceRestores": [
    "sampsonml.lock"
  ]
}
OMARCHY_EOF
```

```bash
omarchy restart shell    # custom widgets in bar/modules/ only load on a shell restart
```

Check:
- The bar has the copper frame, beaker, numbered workspace pills, deep-work pill, `plan the day` to-do pill, mortality pill, VPN globe and, on battery, the power-draw readout.
- To see the lock screen without locking, run `omarchy-shell lock preview`. Click it to dismiss.
- QML errors are logged to `/run/user/1000/quickshell/by-id/*/log.log`. The `pluginBarApiFor is not a function`, `invalid context` and `outside of the config folder` warnings are harmless and come from stock Omarchy.

---

## 8. tmux

The prefix is **C-j**. tmux has:
- vim-style `h/j/k/l` pane movement, `|` and `-` splits, and windows numbered from 1
- the status bar at the top: session and window tabs as rounded pills, plus CPU, memory and clock
- pane borders labelled by role (`▷ EDITOR :: nvim`)
- a second status row with host, kernel and uptime
- a command menu on `prefix Space`

New sessions get codenames like `NEXUS-7F3A`. Panes stay transparent so Ghostty's blur shows through.

The file has two halves. Everything after the `run '~/.tmux/plugins/tpm/tpm'` line must stay after it, or the tokyo-night theme plugin overwrites it. Colours are named (`${THEME_ACCENT}` …) from the block at the top, which the theme-colours hook (step 4) rewrites on every theme switch; the values shown are cyberdeck's.

`~/.config/tmux/tmux.conf`:

```bash
mkdir -p ~/.config/tmux
cat > ~/.config/tmux/tmux.conf <<'OMARCHY_EOF'
# Tmux config file 
# Matt Sampson

# Colours follow the Omarchy theme (sampsonml, 4 Nov 2026): the block below holds the
# current theme's colours, and ~/.config/omarchy/hooks/theme-set.d/theme-colours rewrites
# it on every theme switch and reloads this file. Don't edit the values here. The rest of
# this file uses them as ${THEME_*}, which tmux expands when it reads the file (inside
# double quotes only). The values shown are cyberdeck's.
# >>> theme colours
%hidden THEME_ACCENT="#8d8d8d"
%hidden THEME_CYAN="#b0b0b0"
%hidden THEME_YELLOW="#cecece"
%hidden THEME_GREEN="#b6b6b6"
%hidden THEME_RED="#a4a4a4"
%hidden THEME_MUTED="#7a7a7a"
%hidden THEME_BACKGROUND="#000000"
%hidden THEME_DARK_FOREGROUND="#505050"
%hidden THEME_PILL_BACKGROUND="#1a1a1a"
%hidden THEME_PANE_BORDER="#1a1a1a"
%hidden THEME_SUBTLE_FOREGROUND="#505050"
# <<< theme colours

unbind r
bind r source-file ~/.config/tmux/tmux.conf\; display "Reloaded tmux config!"
set -g prefix C-j
set -g mouse on

# Split vertically
unbind %
bind | split-window -h    # Prefix | to create vertical split
# Split horizontally
unbind '"'
bind - split-window -v    # Prefix - to create horizontal split

# {Neo}Vim like pane navigation
bind-key h select-pane -L 
bind-key j select-pane -D 
bind-key k select-pane -U 
bind-key l select-pane -R

# increase scroll-back history
set -g history-limit 10000

# start window index at 1 instead of 0
set -g base-index 1

# List of plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sidebar'
set -g @plugin 'omerxx/tmux-sessionx'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'nikolovlazar/tokyo-night-tmux'
#set -g @plugin 'TanglingTreats/tmux-everforest' # Adds to the list of plugins
#set -g @tmux-everforest 'dark-medium' # Sets the option to select the theme. Also the default.
#set -g @plugin "janoamaral/tokyo-night-tmux"

# Setup tmux theme
set -g @tokyo-night-tmux_window_id_style fsquare
set -g @tokyo-night-tmux_pane_id_style hsquare
set -g @tokyo-night-tmux_zoom_id_style dsquare
set -g status on
set -g @tokyo-night-tmux_show_path 0
set -g @tokyo-night-tmux_path_format relative # 'relative' or 'full'
set -g @tokyo-night-tmux_show_datetime 0
set -g @plugin 'tmux-plugins/tmux-cpu'

# status bar location
set-option -g status-position top

# nicer colours
set-option -g default-terminal "screen-256color"

# when plugins not loading 
# ~/.tmux/plugins/tpm/scripts/install_plugins.sh
# Initialize TMUX plugin manager 
run '~/.tmux/plugins/tpm/tpm'

# Prefix indicator: session pill (rounded Nerd Font caps U+E0B6/U+E0B4) is the theme accent (copper #d08a52 in cyberdeck) and turns the theme green (moss #9fb565, matches the focused
# window icon) with a keyboard icon (U+F11C) while prefix is active.
# Kept after the TPM run line so the theme plugin doesn't overwrite it.
set -g status-left "#{?client_prefix,#[fg=${THEME_GREEN}],#[fg=${THEME_ACCENT}]}#[bg=default]#[fg=${THEME_BACKGROUND} bold]#{?client_prefix,#[bg=${THEME_GREEN}] ,#[bg=${THEME_ACCENT}]}#S#[nobold bg=default]#{?client_prefix,#[fg=${THEME_GREEN}],#[fg=${THEME_ACCENT}]}#[default] "

# --- Transparent panes ---
# Omarchy's omarchy-theme-set-tmux sets window-style/window-active-style to the theme
# background on every theme change, which hides Ghostty's background-opacity.
# Reset them here on reload; ~/.config/omarchy/hooks/theme-set.d/tmux-transparent
# does the same after each theme change and also clears each pane's OSC 11 background.
set -g window-style default
set -g window-active-style default

# --- Cyberdeck customisations ---
# Everything below sits after the TPM run line because the tokyo-night theme
# resets status-right and the pane-border options when it loads.

# HUD readout on the right of the status bar, as rounded pills. The tmux-cpu scripts are called
# directly because the theme clears status-right before tmux-cpu could fill in
# its #{cpu_percentage}/#{ram_percentage} placeholders.
set -g status-right "#[fg=${THEME_CYAN} bg=default]#[fg=${THEME_BACKGROUND} bg=${THEME_CYAN}]CPU #(~/.config/tmux/plugins/tmux-cpu/scripts/cpu_percentage.sh)#[fg=${THEME_CYAN} bg=default]#[default] #[fg=${THEME_YELLOW} bg=default]#[fg=${THEME_BACKGROUND} bg=${THEME_YELLOW}]MEM #(~/.config/tmux/plugins/tmux-cpu/scripts/ram_percentage.sh)#[fg=${THEME_YELLOW} bg=default]#[default] #[fg=${THEME_GREEN} bg=default]#[fg=${THEME_BACKGROUND} bg=${THEME_GREEN}]%H:%M:%S#[fg=${THEME_GREEN} bg=default]#[default] "
set -g status-interval 1

# Neon pane borders: heavy lines, ember red active pane, a role label on each pane
set -g pane-border-lines heavy
set -g pane-border-indicators arrows
set -g pane-border-style "fg=${THEME_PANE_BORDER}"
set -g pane-active-border-style "fg=${THEME_RED}"
set -g pane-border-status top

# Pane role: a sci-fi name based on the program running in the pane.
# Add programs by extending a regex, or add a new #{?...} branch before the final fallback.
set -g @pane-role "\
#{?#{m/r:^(n?vim?|nano|hx|helix|emacs)$,#{pane_current_command}},EDITOR,\
#{?#{m/r:^(ssh|mosh|mosh-client|sftp)$,#{pane_current_command}},UPLINK,\
#{?#{m/r:^(btop|htop|top|nvtop)$,#{pane_current_command}},MONITOR,\
#{?#{m/r:^(lazygit|git|tig)$,#{pane_current_command}},VCS,\
#{?#{m/r:^(claude)$,#{pane_current_command}},AI AGENT,\
#{?#{m/r:^(python3?|ipython|node|lua|irb)$,#{pane_current_command}},REPL,\
#{?#{m/r:^(make|cargo|npm|pnpm|go|gcc|cmake)$,#{pane_current_command}},BUILD,\
#{?#{m/r:^(man|less|bat)$,#{pane_current_command}},DOCS,\
#{?#{m/r:^(bash|zsh|fish|sh)$,#{pane_current_command}},TERMINAL,\
PROCESS}}}}}}}}}"
set -g pane-border-format " #{?pane_active,#[fg=${THEME_RED} bold]▷,#[fg=${THEME_MUTED}]▷} #{E:@pane-role} :: #{pane_current_command} "

# Command deck menu (prefix Space). Replaces the default next-layout binding.
bind Space display-menu -T "#[fg=${THEME_YELLOW} bold]◢ COMMAND DECK ◣" -x C -y C \
  "Split  ⇆"        | "split-window -h" \
  "Split  ⇅"        - "split-window -v" \
  "Zoom node"       z "resize-pane -Z" \
  "Uplink (git)"    g "display-popup -E -w 85% -h 85% -d '#{pane_current_path}' lazygit" \
  "Sys monitor"     b "display-popup -E -w 90% -h 90% btop" \
  "" \
  "Terminate node"  x "kill-pane"

# --- Pill bar ---
# Window tabs as rounded pills (Nerd Font caps U+E0B6/U+E0B4), using the theme's icons and
# number scripts: teal pill for the focused window, dark pill with a golden-olive
# "last window" marker for the others.
set -g window-status-current-format " #[fg=${THEME_CYAN} bg=default]#[fg=${THEME_BACKGROUND} bg=${THEME_CYAN}] #(~/.config/tmux/plugins/tokyo-night-tmux/src/custom-number.sh #I fsquare) #[bold]#W#[nobold]#{?window_zoomed_flag, #(~/.config/tmux/plugins/tokyo-night-tmux/src/custom-number.sh #P dsquare), #(~/.config/tmux/plugins/tokyo-night-tmux/src/custom-number.sh #P hsquare)}#[fg=${THEME_CYAN} bg=default]#[default]"
set -g window-status-format " #[fg=${THEME_PILL_BACKGROUND} bg=default]#[fg=${THEME_DARK_FOREGROUND} bg=${THEME_PILL_BACKGROUND}] #(~/.config/tmux/plugins/tokyo-night-tmux/src/custom-number.sh #I fsquare) #W#{?window_zoomed_flag, #(~/.config/tmux/plugins/tokyo-night-tmux/src/custom-number.sh #P dsquare), #(~/.config/tmux/plugins/tokyo-night-tmux/src/custom-number.sh #P hsquare)}#{?window_last_flag,#[fg=${THEME_YELLOW}] 󰁯,}#[fg=${THEME_PILL_BACKGROUND} bg=default]#[default]"
# tmux underlines the focused tab by default (window-status-current-style underscore)
set -g window-status-current-style default
set -g message-style "fg=${THEME_BACKGROUND},bg=${THEME_ACCENT}"
set -g message-command-style "fg=${THEME_ACCENT},bg=${THEME_BACKGROUND}"
set -g menu-border-style "fg=${THEME_ACCENT}"
set -g menu-selected-style "fg=${THEME_BACKGROUND},bg=${THEME_ACCENT}"

# --- Session codenames ---
# New sessions that tmux would name 0, 1, 2... get a codename like NEXUS-7F3A.
# Sessions you name yourself (tmux new -s foo, sessionx) are left alone.
set-hook -g session-created 'run-shell "~/.config/tmux/scripts/codename.sh #{q:session_id} #{q:session_name}"'

# --- Second status row ---
# Centred host / kernel / uptime readout inside a copper outline pill
# (thin rounded Nerd Font caps U+E0B7 / U+E0B5).
set -g status 2
set -g status-format[1] "#[align=centre]#[fg=${THEME_ACCENT}] #[fg=${THEME_MUTED}]HOST #[fg=${THEME_CYAN}]#H #[fg=${THEME_MUTED}]· KERNEL #[fg=${THEME_YELLOW}]#(uname -r) #[fg=${THEME_MUTED}]· UPTIME #[fg=${THEME_GREEN}]#(~/.config/tmux/scripts/uptime.sh) #[fg=${THEME_ACCENT}]"
OMARCHY_EOF
```

`~/.config/tmux/scripts/codename.sh`:

```bash
mkdir -p ~/.config/tmux/scripts
cat > ~/.config/tmux/scripts/codename.sh <<'OMARCHY_EOF'
#!/usr/bin/env bash
# Rename a new tmux session to a sci-fi codename (e.g. NEXUS-7F3A), but only
# if tmux gave it a default numeric name. Called by the session-created hook
# in tmux.conf with: <session_id> <session_name>
id="$1"
name="$2"
[[ "$name" =~ ^[0-9]+$ ]] || exit 0

words=(NEXUS ORBITAL VECTOR CIPHER HALO NOVA ECHO SPECTRE PULSAR QUASAR
       ZENITH AXIOM NEON KESTREL ONYX VANTA HELIX RONIN AURORA LUMEN)

# Try a few times in case the codename is already taken
for _ in 1 2 3 4 5; do
  new="${words[RANDOM % ${#words[@]}]}-$(printf '%04X' $(( (RANDOM << 1 ^ RANDOM) & 0xFFFF )))"
  tmux has-session -t "=$new" 2>/dev/null || { tmux rename-session -t "$id" "$new"; exit 0; }
done
OMARCHY_EOF
```

```bash
chmod +x ~/.config/tmux/scripts/codename.sh
```

`~/.config/tmux/scripts/uptime.sh`:

```bash
mkdir -p ~/.config/tmux/scripts
cat > ~/.config/tmux/scripts/uptime.sh <<'OMARCHY_EOF'
#!/usr/bin/env bash
# Compact uptime for the tmux status bar, e.g. "2d 04h 17m"
awk '{ s = int($1); printf "%dd %02dh %02dm", s / 86400, s % 86400 / 3600, s % 3600 / 60 }' /proc/uptime
OMARCHY_EOF
```

```bash
chmod +x ~/.config/tmux/scripts/uptime.sh
```

Notes for Claude Code about this tmux setup:

`~/.config/tmux/CLAUDE.md`:

```bash
mkdir -p ~/.config/tmux
cat > ~/.config/tmux/CLAUDE.md <<'OMARCHY_EOF'
# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal tmux configuration directory (`~/.config/tmux`), not a software project. There is no build, lint, or test step. There is no `~/.tmux.conf`, so tmux loads `tmux.conf` from here via the XDG path.

## Applying and checking changes

- Reload in a running session: `prefix r` (prefix is **C-j**, not C-b), or `tmux source-file ~/.config/tmux/tmux.conf`
- Check syntax without touching the user's sessions: `tmux -L test -f ~/.config/tmux/tmux.conf start-server \; kill-server` (errors print to stderr). To test hooks, start sessions in the test server instead: `tmux -L test -f ~/.config/tmux/tmux.conf new-session -d \; new-session -d -s named`, then `tmux -L test ls` and `tmux -L test kill-server`.
- Install plugins after adding an `@plugin` line: `prefix I`, or `~/.tmux/plugins/tpm/scripts/install_plugins.sh` (the comment in `tmux.conf` gives this fallback for when plugins don't load)

## Structure

- `tmux.conf` is the only file tmux loads. It sets the core options and keybindings (vim-style `h/j/k/l` pane navigation, `|`/`-` splits, windows numbered from 1, status bar at the top) and declares plugins through TPM. The file has two halves around `run '~/.tmux/plugins/tpm/tpm'`:
  - **Before the `run` line:** `@plugin` declarations (TPM reads these when it runs), `@tokyo-night-tmux_*` options, and core settings the theme doesn't touch.
  - **After the `run` line:** anything the theme sets when it loads, because it would otherwise overwrite these. This includes `status-left`, `status-right`, the window tab formats, `pane-border-*`, `message-style`, `menu-*` styles, `status 2` / `status-format[1]` and the `session-created` hook. Don't move these above the `run` line.
- **Colours follow the Omarchy theme** (since 4 Nov 2026; the user wants a theme switch to change colours and nothing else). The top of `tmux.conf` has a block between `# >>> theme colours` and `# <<< theme colours` with lines like `%hidden THEME_ACCENT="#d08a52"`, and the rest of the file uses them as `${THEME_ACCENT}` etc. tmux expands these when it reads the file, and only inside double quotes, so keep coloured strings double-quoted. The Omarchy hook `~/.config/omarchy/hooks/theme-set.d/theme-colours` rewrites the block from the new theme's `colors.toml` on every theme switch and runs `tmux source-file` on this file. Don't edit the block by hand (run the hook to refresh it); to recolour something, pick a different `THEME_*` name. Names: `ACCENT`, `CYAN`, `YELLOW`, `GREEN`, `RED`, `MUTED`, `BACKGROUND`, `DARK_FOREGROUND`, `PILL_BACKGROUND`, `PANE_BORDER`, `SUBTLE_FOREGROUND` (each the `colors.toml` key of the same name; the last three only exist in the cyberdeck theme, and other themes fall back to `selection`, `selection` and `dark_foreground`). Checked 4 Nov 2026: with cyberdeck's values the converted file gives exactly the same `show -g` / `show -gw` options and key bindings as before.
- The "cyberdeck" look is all in the after-TPM section. In the cyberdeck theme its colours come from the main wallpaper (a long-exposure night hillside): copper `#d08a52` (accent), teal `#6fb3b8` (cyan), golden olive `#d8c07a` (yellow), moss `#9fb565` (green), ember red `#d9705a` (red), dark indigo `#23263d` for inactive pills, `#5c6170` for dim text and `#0e0d12` for text on pills. It includes:
  - a CPU/MEM/clock display in `status-right`
  - pane borders labelled by role, e.g. `▷ EDITOR :: nvim` (active pane in ember red `#d9705a`). The program-to-role mapping is the `@pane-role` user option, a chain of `#{m/r:...}` regex matches ending in a `PROCESS` fallback
  - a `prefix Space` command-deck menu, which replaces tmux's default `next-layout` binding
  - a second status row showing host, kernel and uptime (centred, between thin copper rounded caps U+E0B7 and U+E0B5 that act as an outline pill)
  - the session name and window tabs drawn as rounded pills using Nerd Font caps (U+E0B6 and U+E0B4). The tabs reuse the theme's icons and `custom-number.sh` scripts: a teal pill for the focused window and a dark `#23263d` pill for the others
- `status-right` calls the `tmux-cpu` scripts directly (`plugins/tmux-cpu/scripts/*.sh`), not through its `#{cpu_percentage}` placeholders. The theme clears `status-right` before `tmux-cpu` can fill in the placeholders, so they would never be replaced.
- Panes are kept transparent so Ghostty's `background-opacity` shows through. On every theme change Omarchy's `omarchy-theme-set-tmux` sets `window-style`/`window-active-style` to the theme background and sends OSC 11 to each pane. `tmux.conf` resets both styles to `default`, and the Omarchy hook `~/.config/omarchy/hooks/theme-set.d/tmux-transparent` resets them again after each theme change and sends OSC 111 to every pane. Don't add a `bg=` to `window-style` or `window-active-style`, because it would make the panes solid again.
- `scripts/` holds helper scripts that `tmux.conf` calls:
  - `codename.sh` runs from the `session-created` hook. It renames sessions that tmux gave a numeric name to codenames like `NEXUS-7F3A`, and leaves sessions the user named alone.
  - `uptime.sh` prints a compact uptime for the second status row.
- Plugins are installed into `plugins/` inside this directory: TPM uses the XDG location because the config is in `~/.config/tmux`. `tmux.conf` still starts TPM from an older copy in `~/.tmux/plugins/tpm`, and that works fine. TPM manages these plugins: tpm, tmux-sidebar, tmux-sessionx, tmux-sensible, tokyo-night-tmux (nikolovlazar fork), tmux-cpu. Theme options are set through `@tokyo-night-tmux_*` variables in `tmux.conf`, which the plugin reads with `tmux show -g`. Set these variables before the TPM `run` line.
OMARCHY_EOF
```

Install the plugin manager, then the plugins: tpm, tmux-sidebar, tmux-sessionx, tmux-sensible, the nikolovlazar fork of tokyo-night-tmux, and tmux-cpu.

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
tmux -L test -f ~/.config/tmux/tmux.conf start-server \; kill-server   # syntax check only
```

Then open a tmux terminal with **Super+Alt+Return** (Omarchy's tmux shortcut; a plain terminal plus `tmux` also works) and press **C-j**, then **Shift+I**. TPM installs the plugins into `~/.config/tmux/plugins/`. Reload with `C-j r`.

---

## 9. Starship prompt

A two-line prompt:
- **Line 1:** dim `╭─`, `user@host`, the directory in a copper pill, the git branch in an indigo pill, git status, and the command's duration if it took over 2 s.
- **Line 2:** `╰─❯` in copper, or `╰─✗` in ember red after an error.

Its colours are named (`theme_accent` …) from the `[palettes.theme]` table at the end, which the theme-colours hook (step 4) rewrites on every theme switch.

`~/.config/starship.toml`:

```bash
mkdir -p ~/.config
cat > ~/.config/starship.toml <<'OMARCHY_EOF'
# Cyberdeck two-line prompt: pills matching the tmux bar and Omarchy "cyberdeck" theme.
#   ╭─ user@host ( ~/dir ) ( branch ) status ⟨ 2.3s ⟩
#   ╰─❯
# Colours follow the Omarchy theme (sampsonml, 4 Nov 2026): they're named (theme_accent,
# theme_cyan, ...) from the [palettes.theme] table at the end, which
# ~/.config/omarchy/hooks/theme-set.d/theme-colours rewrites on every theme switch.
palette = "theme"
add_newline = true
command_timeout = 200
format = '[╭─](theme_muted) $username$hostname$directory$git_branch$git_status$cmd_duration$line_break$character'

[username]
show_always = true
format = '[$user](theme_subtle_foreground)'

[hostname]
ssh_only = false
format = '[@$hostname](theme_subtle_foreground) '

[directory]
truncation_length = 3
truncation_symbol = "…/"
format = '[](fg:theme_accent)[ $path$read_only ](fg:theme_accent bold)[](fg:theme_accent) '
read_only = " 󰌾"

[git_branch]
symbol = " "
format = '[](fg:theme_pill_background)[$symbol$branch](fg:theme_green bg:theme_pill_background)[](fg:theme_pill_background) '

[cmd_duration]
min_time = 2000
format = '[⟨ $duration ⟩](theme_yellow) '

[character]
success_symbol = "[╰─❯](bold theme_accent)"
error_symbol = "[╰─✗](bold theme_red)"

[git_status]
format     = '[$all_status]($style)'
style      = "theme_yellow"
ahead      = "⇡${count} "
diverged   = "⇕⇡${ahead_count}⇣${behind_count} "
behind     = "⇣${count} "
conflicted = " "
up_to_date = " "
untracked  = "? "
modified   = " "
stashed    = ""
staged     = ""
renamed    = ""
deleted    = ""

# The current theme's colours (cyberdeck's shown). Don't edit: the theme-colours hook
# rewrites the lines between the markers.
[palettes.theme]
# >>> theme colours
theme_accent = "#8d8d8d"
theme_cyan = "#b0b0b0"
theme_yellow = "#cecece"
theme_green = "#b6b6b6"
theme_red = "#a4a4a4"
theme_muted = "#7a7a7a"
theme_background = "#000000"
theme_dark_foreground = "#505050"
theme_pill_background = "#1a1a1a"
theme_pane_border = "#1a1a1a"
theme_subtle_foreground = "#505050"
# <<< theme colours
OMARCHY_EOF
```

---

## 10. Neovim and Python

Omarchy's LazyVim config, plus three extras: neo-tree, Python (pyright + ruff; pick a virtualenv with `<leader>cv`) and Markdown (rendering, marksman, markdownlint, preview).

`~/.config/nvim/lazyvim.json`:

```bash
mkdir -p ~/.config/nvim
cat > ~/.config/nvim/lazyvim.json <<'OMARCHY_EOF'
{
  "extras": [
    "lazyvim.plugins.extras.editor.neo-tree",
    "lazyvim.plugins.extras.lang.markdown",
    "lazyvim.plugins.extras.lang.python"
  ],
  "install_version": 8,
  "news": {
    "NEWS.md": "10960"
  },
  "version": 8
}
OMARCHY_EOF
```

Plugin versions pinned at the time of writing, for an identical plugin set:

`~/.config/nvim/lazy-lock.json`:

```bash
mkdir -p ~/.config/nvim
cat > ~/.config/nvim/lazy-lock.json <<'OMARCHY_EOF'
{
  "LazyVim": { "branch": "main", "commit": "999700997f72227187d49d8b92667183dc7fc809" },
  "aether": { "branch": "v3", "commit": "567efb778534e11ee1072d4fe27178f705a27d8a" },
  "ashen.nvim": { "branch": "main", "commit": "bfb04bd50b69d863469b2deb9fb361cf0d945ba7" },
  "bamboo.nvim": { "branch": "master", "commit": "1309bc88bffcf1bedc3e84e7fa9004de93da774a" },
  "blink.cmp": { "branch": "main", "commit": "78336bc89ee5365633bcf754d93df01678b5c08f" },
  "bufferline.nvim": { "branch": "main", "commit": "655133c3b4c3e5e05ec549b9f8cc2894ac6f51b3" },
  "catppuccin": { "branch": "main", "commit": "edefef779ab08ce1a4a404713e3012b0d202bd35" },
  "conform.nvim": { "branch": "master", "commit": "016802de402556da54c36bd7359b441266b01cdd" },
  "ethereal.nvim": { "branch": "main", "commit": "a0ec73332e537228981b6a4f465cef82bb3e1d36" },
  "everforest-nvim": { "branch": "main", "commit": "a0e9edc57379e8feafc6ba207c26dbb12fc1b6d8" },
  "flash.nvim": { "branch": "main", "commit": "5f0f270fdc7c5b0c21d903ee85b9cb06f2ac636a" },
  "flexoki-neovim": { "branch": "main", "commit": "c3e2251e813d29d885a7cbbe9808a7af234d845d" },
  "friendly-snippets": { "branch": "main", "commit": "b2ea5c41a150ba72fb656eedb4ed0a86d138d945" },
  "gitsigns.nvim": { "branch": "main", "commit": "4bcd99167c265f135886b282baad77afe06206b2" },
  "grug-far.nvim": { "branch": "main", "commit": "91b7e58b6ffc6ddad5acb7a7c1df21257724449e" },
  "gruvbox.nvim": { "branch": "main", "commit": "154eb5ff5b96d0641307113fa385eaf0d36d9796" },
  "hackerman.nvim": { "branch": "main", "commit": "d7699ce7639686b8f3a5ae108b496a32ee5c076d" },
  "kanagawa.nvim": { "branch": "master", "commit": "bb85e4bfc8d89b0e62c8fa53ccdd13d12e2f77b3" },
  "lazy.nvim": { "branch": "main", "commit": "85c7ff3711b730b4030d03144f6db6375044ae82" },
  "lazydev.nvim": { "branch": "main", "commit": "ff2cbcba459b637ec3fd165a2be59b7bbaeedf0d" },
  "lualine.nvim": { "branch": "master", "commit": "221ce6b2d999187044529f49da6554a92f740a96" },
  "lumon.nvim": { "branch": "master", "commit": "f8ce95213e57b379089da23abc36a1fc39936b63" },
  "markdown-preview.nvim": { "branch": "master", "commit": "a923f5fc5ba36a3b17e289dc35dc17f66d0548ee" },
  "mason-lspconfig.nvim": { "branch": "main", "commit": "3a5cd6d562a01f6829a35ae761dc383264ea452b" },
  "mason.nvim": { "branch": "main", "commit": "2a6940af80375532e5e9e7c1f2fc6319a1b7a69d" },
  "matteblack.nvim": { "branch": "main", "commit": "a8a039f5d6189b28d76fa0221e64965efec7e996" },
  "miasma.nvim": { "branch": "main", "commit": "466456f08d1a114c983c0d24e8fc01339e3b0a27" },
  "mini.ai": { "branch": "main", "commit": "a4f5648dedf435e6306205135d1babb563b55d28" },
  "mini.icons": { "branch": "main", "commit": "eab3e692d796d78ea6ffc978d8a380ff26fcf4e3" },
  "mini.pairs": { "branch": "main", "commit": "03eb1f0062a2cee5314d1ac3939246e4bb21352e" },
  "monokai-pro.nvim": { "branch": "master", "commit": "a68e38b8e55d69a215d0f02598900a79c356da9d" },
  "neo-tree.nvim": { "branch": "main", "commit": "bb9779f532ef9ec62486a840fb5db44591aeff0f" },
  "nightfox.nvim": { "branch": "main", "commit": "4dacd3f0185a2227bdf3b6c0975a8f0bf87cac9a" },
  "noice.nvim": { "branch": "main", "commit": "7bfd942445fb63089b59f97ca487d605e715f155" },
  "nui.nvim": { "branch": "main", "commit": "10fc361835c856ba4233ef5ea135b919bf3dce97" },
  "nvim-lint": { "branch": "master", "commit": "52107ce2076a27a285af781248e2c59bad817cd0" },
  "nvim-lspconfig": { "branch": "master", "commit": "adfbb74472f6c231b651b650a89f414c2680fb31" },
  "nvim-treesitter": { "branch": "main", "commit": "0195cd62fa89950f34c0e0d648ea7897ab85d4d3" },
  "nvim-treesitter-textobjects": { "branch": "main", "commit": "5c7b0263797dfd1bd6202f2b219f3b53a80b2187" },
  "nvim-ts-autotag": { "branch": "main", "commit": "d7220b55e16ed3c04e88086256def5d282429493" },
  "persistence.nvim": { "branch": "main", "commit": "b20b2a7887bd39c1a356980b45e03250f3dce49c" },
  "plenary.nvim": { "branch": "master", "commit": "74b06c6c75e4eeb3108ec01852001636d85a932b" },
  "render-markdown.nvim": { "branch": "main", "commit": "8e8795368391036643b622875a6da6a51bcd33f4" },
  "retro-82.nvim": { "branch": "master", "commit": "41b8c42ed0099eb43824903ef606a6b051d33505" },
  "rose-pine": { "branch": "main", "commit": "ff483051a47e27d84bdef47703538df1ed9f4a47" },
  "snacks.nvim": { "branch": "main", "commit": "882c996cf28183f4d63640de0b4c02ec886d01f2" },
  "todo-comments.nvim": { "branch": "main", "commit": "31e3c38ce9b29781e4422fc0322eb0a21f4e8668" },
  "tokyonight.nvim": { "branch": "main", "commit": "cdc07ac78467a233fd62c493de29a17e0cf2b2b6" },
  "trouble.nvim": { "branch": "main", "commit": "bd67efe408d4816e25e8491cc5ad4088e708a69a" },
  "ts-comments.nvim": { "branch": "main", "commit": "a59d6092213447450191122c9346f309161504cb" },
  "vantablack.nvim": { "branch": "main", "commit": "8a05ea96343914f1001e937b4fa7d9d44b51d221" },
  "venv-selector.nvim": { "branch": "main", "commit": "cc4bb3975de8835291f9bb45889e96c6b2795fc4" },
  "which-key.nvim": { "branch": "main", "commit": "3aab2147e74890957785941f0c1ad87d0a44c15a" },
  "white.nvim": { "branch": "main", "commit": "e3c3c3cc4b943b521032299e4f9b0d84a02e06d1" }
}
OMARCHY_EOF
```

```bash
nvim    # first start installs plugins; then run :Lazy restore to match the lock file exactly
```

Leave Neovim open on first start until Mason finishes (`:Mason` shows progress). The extras install `pyright`, `ruff`, `marksman`, `markdownlint-cli2` and `markdown-toc` by themselves, alongside LazyVim's defaults (`lua-language-server`, `shfmt`, `stylua`).

**uv** (the Python package and project manager used for all Python work) installs to `~/.local/bin` with its official installer:

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

For pyright to find a project's `.venv`, start Neovim from inside the activated venv or with `uv run nvim`, or pick the venv with `<leader>cv`.

---

## 11. Web apps, email and default apps

### Chromium

Sign in to **both** Google accounts in Chromium (the personal Gmail and the Princeton Google Workspace account). The calendar web apps choose between them with `?authuser=`.

### Web apps

The icons come from `~/omarchy-assets/` (step 0). These must use the same URLs as the shortcuts in `bindings.lua`:

```bash
omarchy webapp install "Google Calendar" "https://calendar.google.com/calendar/u/0/r?authuser=msampsonroko@gmail.com" ~/omarchy-assets/google-calendar.png
omarchy webapp install "Princeton Calendar" "https://calendar.google.com/calendar/r?authuser=ms0821@princeton.edu" ~/omarchy-assets/princeton-calendar.png
omarchy webapp install "Overleaf" "https://www.overleaf.com/project" ~/omarchy-assets/overleaf.png
```

### Thunderbird (email)

Thunderbird keeps its profile in `~/.config/thunderbird/`, not `~/.thunderbird`. If you copied the profile in step 0, put it back there and skip to the last bullet. Otherwise, set it up by hand:

- **Personal Gmail:** add it normally. Thunderbird detects Gmail and signs in through Google (OAuth2).
- **Princeton:** this is a **Google Workspace (Gmail) account, not Exchange.** Thunderbird's automatic setup picks Microsoft 365 because of how `princeton.edu`'s mail records are set up. That Microsoft mailbox exists but is empty. Choose **Configure manually**:
  - Incoming: IMAP, `imap.gmail.com`, port 993, SSL/TLS, OAuth2
  - Outgoing: SMTP, `smtp.gmail.com`, port 465, SSL/TLS, OAuth2
  - Username: the full `@princeton.edu` address
- **Unified inbox:** folder pane ⋯ → Folder Modes → **Unified Folders**.
- **Princeton identity:** full name "Matt Wiemann Sampson", reply above the quote, and the signature placed below the reply. Copy the signature text from the old machine.
- **Notifications off:** Settings → General → Incoming Mails: untick **Show an alert** and **Play a sound**.
- **When Thunderbird asks to become the default mail app, say yes.** That makes `mailto:` links open Thunderbird. It registers itself in `~/.config/mimeapps.list` as `userapp-Thunderbird-*.desktop`.

**Storage and battery:** by default Thunderbird downloads every Gmail folder, including All Mail and Important, which are mostly duplicates of the Inbox. That's about 20 GB and several hours of downloading, which also uses battery. To store less, untick "Select this folder for offline use" on **All Mail** and **Important** (right-click → Properties → Synchronization). Let the first sync finish on the charger with the lid open, because sleep pauses it.

### arxiv-digest (daily arXiv digest web app)

The tool lives in `~/Projects/arxiv-digest` (GitHub: SampsonML/arxiv-digest). The launcher entry adds "arxiv-digest", with its test-tube icon, to the app launcher; `Super+Shift+R` opens it as well.

```bash
git clone https://github.com/SampsonML/arxiv-digest ~/Projects/arxiv-digest
cd ~/Projects/arxiv-digest && uv sync
uv run arxiv-digest init               # or copy ~/.config/arxiv-digest/config.toml across
uv run arxiv-digest shortcut install   # app launcher entry + icon
```

To carry over past digests and the record of papers already seen, also copy `~/Projects/arxiv-digest/digests/` and `~/.local/share/arxiv-digest/`. The first Claude-ranked run needs Claude Code signed in (`claude auth login`).

### Default apps

Chromium is the default browser out of the box. Thunderbird handles `mailto:` once you accept its prompt above. This replaces Omarchy's default, HEY. Check with:

```bash
xdg-mime query default x-scheme-handler/mailto
```

---

## 12. Princeton VPN

Princeton's GlobalProtect VPN, using the open-source client (`globalprotect-openconnect`, installed in step 2). Princeton signs you in through the web browser (Princeton sign-in plus Duo), so no password is stored anywhere.

`~/.local/bin/princeton-vpn`:

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/princeton-vpn <<'OMARCHY_EOF'
#!/bin/bash
# Princeton GlobalProtect VPN, using the open-source client from the
# globalprotect-openconnect package (gpauth + gpclient).
#
# Princeton's portal uses browser single sign-on (SAML through Palo Alto's
# Cloud Authentication Service), so you sign in with ms0821@princeton.edu + Duo
# on Princeton's login page in your default browser. gpclient's -u/--user flag
# only applies to password portals, so it is not used here.
#
#   princeton-vpn                 connect to vpn.princeton.edu in this terminal (Ctrl+C disconnects)
#   princeton-vpn library         same, for vpnlocal.princeton.edu (Library e-resources)
#   princeton-vpn off             disconnect
#   princeton-vpn status          print connected / connecting / disconnected
#   princeton-vpn toggle [library]
#                                 used by the bar globe: connect in the background
#                                 (admin rights via the polkit password prompt), or
#                                 disconnect if already connected/connecting
#
# The tunnel interface is named pvpn0 so the status check and the bar can find it.
# Background connections log to ~/.local/state/princeton-vpn/vpn.log.

IFACE=pvpn0
STATE_DIR="$HOME/.local/state/princeton-vpn"
LOG="$STATE_DIR/vpn.log"
STOP_MARKER="$STATE_DIR/stopping"

portal_for() {
  case "${1:-}" in
  "" | main) echo vpn.princeton.edu ;;
  library | lib) echo vpnlocal.princeton.edu ;;
  *)
    echo "unknown portal: $1 (use 'library' or nothing)" >&2
    exit 1
    ;;
  esac
}

status() {
  if [[ -e /sys/class/net/$IFACE ]]; then
    echo connected
  elif pgrep -x gpauth >/dev/null || pgrep -f '^(/usr/bin/)?gpclient connect' >/dev/null; then
    echo connecting
  else
    echo disconnected
  fi
}

notify() {
  notify-send -a "Princeton VPN" -i network-vpn "$@" 2>/dev/null || true
}

disconnect() {
  mkdir -p "$STATE_DIR"
  touch "$STOP_MARKER"
  # gpauth runs as you (waiting on the browser sign-in); gpclient runs as root.
  pkill -x gpauth 2>/dev/null
  if pgrep -f '^(/usr/bin/)?gpclient connect' >/dev/null; then
    if [[ -t 0 ]]; then sudo gpclient disconnect; else pkexec gpclient disconnect; fi
  fi
}

# Background connection: browser sign-in as you, then the tunnel as root via pkexec.
connect_background() {
  local portal=$1
  mkdir -p "$STATE_DIR"
  rm -f "$STOP_MARKER"
  echo "=== $(date '+%F %T') connecting to $portal" >"$LOG"

  # Tell the user once the tunnel is up (gives up after 5 minutes).
  (
    for _ in $(seq 1 300); do
      if [[ -e /sys/class/net/$IFACE ]]; then
        notify "Princeton VPN connected" "$portal"
        exit 0
      fi
      kill -0 $$ 2>/dev/null || exit 0 # the connection attempt has ended
      sleep 1
    done
  ) &

  gpauth "$portal" --browser default 2>>"$LOG" |
    pkexec gpclient connect "$portal" --cookie-on-stdin --auto-gateway --interface "$IFACE" >>"$LOG" 2>&1
  local codes=("${PIPESTATUS[@]}")
  echo "=== $(date '+%F %T') exited (gpauth ${codes[0]}, gpclient ${codes[1]})" >>"$LOG"

  if [[ -e $STOP_MARKER ]]; then
    rm -f "$STOP_MARKER"
    notify "Princeton VPN disconnected"
  else
    notify -u critical "Princeton VPN stopped" "Connection ended or failed. Details: $LOG"
  fi
}

case "${1:-}" in
status)
  status
  ;;
off | disconnect)
  disconnect
  ;;
toggle)
  if [[ $(status) == disconnected ]]; then
    portal=$(portal_for "${2:-}") || exit 1
    setsid -f "$0" _background "$portal" >/dev/null 2>&1
  else
    disconnect
  fi
  ;;
_background)
  connect_background "$2"
  ;;
"" | library | lib | main)
  portal=$(portal_for "${1:-}") || exit 1
  # -E keeps your desktop session's environment so the sign-in can open in your browser.
  exec sudo -E gpclient connect --browser default --auto-gateway --interface "$IFACE" "$portal"
  ;;
*)
  echo "usage: princeton-vpn [library|off|status|toggle [library]]" >&2
  exit 1
  ;;
esac
OMARCHY_EOF
```

```bash
chmod +x ~/.local/bin/princeton-vpn
```

| Command | Does |
|---|---|
| `princeton-vpn` | Connects in the foreground (`library` uses the Library VPN, `vpnlocal.princeton.edu`) |
| `princeton-vpn toggle [library]` | Connects or disconnects in the background. The bar globe uses this. |
| `princeton-vpn off` | Disconnects |
| `princeton-vpn status` | Prints `connected`, `connecting` or `disconnected` |

Test it: click the globe in the bar. Chromium opens Princeton's sign-in page; after Duo, a system password prompt appears, and then the globe turns teal.
- If sign-in hangs, check `/tmp/gpcallback.log`.
- Background connections log to `~/.local/state/princeton-vpn/vpn.log`.

---

## 13. SSH

There are two cluster hosts, `rusty` (Flatiron) and `dellag` (Princeton Della GPU). Both use connection sharing, so only the first `ssh` to a host asks for a password and Duo. Later `ssh`, `scp` and `rsync` reuse that connection.

`~/.ssh/config`:

```bash
mkdir -p ~/.ssh
cat > ~/.ssh/config <<'OMARCHY_EOF'
# HPCs
#

# flatiron cluster
Host rusty
  SetEnv TERM=xterm-256color
  HostName gateway.flatironinsitute.org
  User msampson
  Port 61022
  ControlMaster auto
  ControlPath ~/.ssh/cm-%C
  ControlPersist yes


# Princeton clusters

# Della-GPU
Host dellag
  SetEnv TERM=xterm-256color
  HostName della-gpu.princeton.edu
  User ms0821
  ControlMaster auto
  ControlPath ~/.ssh/cm-%C
  ControlPersist yes
OMARCHY_EOF
```

```bash
chmod 700 ~/.ssh
```

If `ssh` hangs after the laptop sleeps or the VPN changes, the shared connection has gone stale. Close it with `ssh -O exit dellag` (or `rusty`) and connect again.

---

## 14. Claude Code notes

- Copy the whole `~/customization/` folder across. It holds `CLAUDE.md`, the map of every customization that Claude Code reads, and this file. Claude Code's memory for that folder is in `~/.claude/projects/-home-sampsonml-customization/memory/` and can be copied too.
- Omarchy's default AI agent is Claude:

  ```bash
  mkdir -p ~/.config/omarchy/defaults && echo claude > ~/.config/omarchy/defaults/agent
  ```

- The Kinesis Advantage 360 Pro needs nothing here. Its keymap is stored on the keyboard and was set with the Kinesis Clique app on the Mac.

---

## 15. Final check

```bash
hyprctl reload && hyprctl configerrors                  # Hyprland config loads cleanly
cat ~/.local/state/omarchy/current/theme.name           # cyberdeck
omarchy menu keybindings --print | grep -i -E 'calendar|overleaf|email'
tmux -L test -f ~/.config/tmux/tmux.conf start-server \; kill-server
princeton-vpn status                                    # disconnected
ssh -G dellag | grep -i control                         # controlmaster auto + a controlpath
xdg-mime query default x-scheme-handler/mailto          # userapp-Thunderbird-….desktop
desktop-file-validate ~/.local/share/applications/arxiv-digest.desktop && echo ok
systemctl is-enabled fprintd-resume-restart.service    # enabled
omarchy-shell deepwork status | jq .active              # false
```

Then check by eye:
- Slightly rounded, copper/teal-bordered windows, and the bar frame outlined in the same copper → teal.
- `omarchy theme set vantablack` recolours everything (window borders, bar frame, pills, tmux, prompt) and changes nothing else apart from the wallpaper; `omarchy theme set cyberdeck` brings it all back.
- The HUD-framed bar with workspace pills, the deep-work pill, mortality, globe and power draw.
- The two-line copper prompt and tmux pills.
- The HUD lock screen (`omarchy-shell lock preview`).
- `Super+Shift+C` / `L` / `E` open the right apps.
- Closing the lid on battery locks the screen and the laptop sleeps.
- After the laptop wakes, a finger on the reader unlocks the lock screen.
- `Super+D` → 25 min glitches the screen like a TV losing signal, then brings it back grey, with the bar turned into the deep-work timer; `Super+Alt+C` shows colour for 20 s; `Super+D` → End now brings the bar and colour back.
