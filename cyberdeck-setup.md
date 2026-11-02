# Cyberdeck setup guide: tmux, Ghostty and Omarchy

**For:** a Claude Code agent setting up a fresh Omarchy install (target: Lenovo ThinkPad T14s Gen 3, Intel Core i5-1245U, 16 GB, 14" 1080p-class screen; section 11 has the laptop adjustments) to match the source machine, a desktop mini PC with Omarchy 4.0.6, tmux 3.8, Ghostty 1.4.0, Starship 1.27.0 and Hyprland 0.56.2.

The look is a "modern hacker but professional" cyberdeck style:
- **Colours:** taken from the main wallpaper: copper, teal, golden olive and moss on a night-indigo, near-black background.
- **tmux:** a pill-shaped status bar, panes labelled by role, transparent panes, a command menu and session codenames.
- **Ghostty:** a see-through background with blur.
- **Omarchy theme "cyberdeck":** a custom colour theme. The main wallpaper is a long-exposure night photo of a flowering hillside, downloaded from the user's GitHub repo, with two generated backup wallpapers.
- **Hyprland:** a rotating copper-to-teal border on the focused window, a faint glow and square corners.
- **Prompt:** a two-line Starship prompt.
- **Top bar:** a floating HUD frame with a copper outline, numbered workspace pills (copper for the active one), a science-beaker menu button, a ticking "mortality counter" (age in years to 7 decimals) and larger icons.

Every file below is the exact content from the source machine.

---

## 0. Ground rules for the agent

- **Load the `omarchy` skill** before editing anything in `~/.config/hypr/`, `~/.config/omarchy/` or `~/.config/ghostty/`. Never edit `/usr/share/omarchy/`; reading it is fine.
- **Back up before overwriting:** `cp file file.bak.$(date +%s)`. A fresh Omarchy install may already ship some of these files, so look at each target before you replace it.
- **Nerd Font characters:** many files below contain Private Use Area glyphs, such as the rounded pill caps U+E0B6 and U+E0B4. They're invisible or look like boxes in many viewers. Copy the code blocks byte for byte, and don't retype or "clean up" lines that look like they have stray spaces. Section 10 has a check that confirms every glyph survived. If you can't copy them reliably, write those lines with Python using `\uXXXX` escapes.
- **Never run `starship config`:** with no arguments it opens an editor and hangs the shell. Use `starship print-config` or `starship prompt` to test.
- **Commands needing `sudo`:** they can't prompt for a password from Claude Code's `!` shell. Ask the user to run them in a real terminal, or use the polkit route (for example `hostnamectl` without `sudo`).
- **Check each step** with the commands given before moving on, and tell the user what changed.
- **Laptop:** do the hardware check in section 11a before starting, and apply the rest of section 11 after section 10.

## 1. Questions to ask the user first

1. **Hostname:** what should the machine be called? The source machine is `mini-beast`. The name shows in the tmux status row and the prompt. Have the user run `hostnamectl set-hostname <name>` in their terminal; it goes through polkit.
2. **Rotating border:** on a laptop this redraws continuously and costs a little battery. Ask whether to keep it (section 6).
3. **Lock screen on battery:** section 5h keeps the screen on while locked when plugged in, and lets it turn off after 5 seconds on battery. Ask whether they want that, or the screen on even on battery.
4. **Birth date for the mortality counter:** section 5j shows the user's age in the top bar. Ask for their birth date (`YYYY-MM-DD`), and the time of birth if they know it (`YYYY-MM-DDTHH:MM`); without a time it counts from midnight. It's stored only in `~/.config/omarchy/shell.json`.
5. **Wallpaper repo URL:** section 5c downloads the main wallpaper (`dr-hero-bg.webp`) from the user's GitHub repo. If `<REPO-RAW-URL>` in section 5c is still a placeholder, ask the user for the link to the image in their repo. If the repo is private, ask them to run `gh auth login` first (section 5c explains how to download it).

## 2. Packages and fonts

Check each of these and install what's missing with `omarchy pkg add <pkg>`:

```bash
tmux -V                       # need >= 3.4 (pane-border-lines/indicators, menu styles); source uses 3.8
command -v git lazygit btop starship magick
fc-list | grep -i 'Iosevka Nerd Font Mono' | head -1   # package: ttf-iosevka-nerd
ghostty --version             # >= 1.2 for background-blur via ext-background-effect-v1
```

Packages: `tmux git lazygit btop starship imagemagick ttf-iosevka-nerd`. Omarchy normally ships most of these already.

## 3. Ghostty

Replace `~/.config/ghostty/config` with the following, after backing it up and comparing it with Omarchy's default. Compared with the default, this adds:
- `background-opacity = 0.8` and `background-blur = true`
- the Iosevka Nerd Font Mono font at size 14
- the extra keybinds

```ini
# Dynamic theme colors
config-file = ?"~/.local/state/omarchy/current/theme/ghostty.conf"

#opacity
background-opacity = 0.8
background-blur = true

# Font
font-family = "Iosevka Nerd Font Mono"
font-style = Regular
font-size = 14

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
```

Apply it with `omarchy restart terminal`, which sends Ghostty a reload signal and is safe.

**Blur:** Ghostty asks the compositor to blur through the `ext-background-effect-v1` protocol. Omarchy ships with Hyprland's blur turned off (`decoration.blur.enabled = false`), so the blur may not be visible. Treat that as optional and ask the user before turning on Hyprland blur.

## 4. tmux

### 4a. Files

Create these files:
- `~/.config/tmux/tmux.conf`
- `~/.config/tmux/scripts/codename.sh` (executable)
- `~/.config/tmux/scripts/uptime.sh` (executable)
- `~/.config/tmux/CLAUDE.md`

There is no `~/.tmux.conf`; tmux reads its config from `~/.config/tmux`. The prefix key is **C-j**.

`~/.config/tmux/tmux.conf`:

```tmux
# Tmux config file 
# Matt Sampson

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

# Prefix indicator: session pill (rounded Nerd Font caps U+E0B6/U+E0B4) is copper (#d08a52) and turns moss (#9fb565, matches the focused
# window icon) with a keyboard icon (U+F11C) while prefix is active.
# Kept after the TPM run line so the theme plugin doesn't overwrite it.
set -g status-left "#{?client_prefix,#[fg=#9fb565],#[fg=#d08a52]}#[bg=default]#[fg=#0e0d12 bold]#{?client_prefix,#[bg=#9fb565] ,#[bg=#d08a52]}#S#[nobold bg=default]#{?client_prefix,#[fg=#9fb565],#[fg=#d08a52]}#[default] "

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
set -g status-right "#[fg=#6fb3b8 bg=default]#[fg=#0e0d12 bg=#6fb3b8]CPU #(~/.config/tmux/plugins/tmux-cpu/scripts/cpu_percentage.sh)#[fg=#6fb3b8 bg=default]#[default] #[fg=#d8c07a bg=default]#[fg=#0e0d12 bg=#d8c07a]MEM #(~/.config/tmux/plugins/tmux-cpu/scripts/ram_percentage.sh)#[fg=#d8c07a bg=default]#[default] #[fg=#9fb565 bg=default]#[fg=#0e0d12 bg=#9fb565]%H:%M:%S#[fg=#9fb565 bg=default]#[default] "
set -g status-interval 1

# Neon pane borders: heavy lines, ember red active pane, a role label on each pane
set -g pane-border-lines heavy
set -g pane-border-indicators arrows
set -g pane-border-style "fg=#2e3148"
set -g pane-active-border-style "fg=#d9705a"
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
set -g pane-border-format " #{?pane_active,#[fg=#d9705a bold]▷,#[fg=#5c6170]▷} #{E:@pane-role} :: #{pane_current_command} "

# Command deck menu (prefix Space). Replaces the default next-layout binding.
bind Space display-menu -T "#[fg=#d8c07a bold]◢ COMMAND DECK ◣" -x C -y C \
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
set -g window-status-current-format " #[fg=#6fb3b8 bg=default]#[fg=#0e0d12 bg=#6fb3b8] #(~/.config/tmux/plugins/tokyo-night-tmux/src/custom-number.sh #I fsquare) #[bold]#W#[nobold]#{?window_zoomed_flag, #(~/.config/tmux/plugins/tokyo-night-tmux/src/custom-number.sh #P dsquare), #(~/.config/tmux/plugins/tokyo-night-tmux/src/custom-number.sh #P hsquare)}#[fg=#6fb3b8 bg=default]#[default]"
set -g window-status-format " #[fg=#23263d bg=default]#[fg=#9fa39f bg=#23263d] #(~/.config/tmux/plugins/tokyo-night-tmux/src/custom-number.sh #I fsquare) #W#{?window_zoomed_flag, #(~/.config/tmux/plugins/tokyo-night-tmux/src/custom-number.sh #P dsquare), #(~/.config/tmux/plugins/tokyo-night-tmux/src/custom-number.sh #P hsquare)}#{?window_last_flag,#[fg=#d8c07a] 󰁯,}#[fg=#23263d bg=default]#[default]"
# tmux underlines the focused tab by default (window-status-current-style underscore)
set -g window-status-current-style default
set -g message-style "fg=#0e0d12,bg=#d08a52"
set -g message-command-style "fg=#d08a52,bg=#0e0d12"
set -g menu-border-style "fg=#d08a52"
set -g menu-selected-style "fg=#0e0d12,bg=#d08a52"

# --- Session codenames ---
# New sessions that tmux would name 0, 1, 2... get a codename like NEXUS-7F3A.
# Sessions you name yourself (tmux new -s foo, sessionx) are left alone.
set-hook -g session-created 'run-shell "~/.config/tmux/scripts/codename.sh #{q:session_id} #{q:session_name}"'

# --- Second status row ---
# Centred host / kernel / uptime readout inside a copper outline pill
# (thin rounded Nerd Font caps U+E0B7 / U+E0B5).
set -g status 2
set -g status-format[1] "#[align=centre]#[fg=#d08a52] #[fg=#5c6170]HOST #[fg=#6fb3b8]#H #[fg=#5c6170]· KERNEL #[fg=#d8c07a]#(uname -r) #[fg=#5c6170]· UPTIME #[fg=#9fb565]#(~/.config/tmux/scripts/uptime.sh) #[fg=#d08a52]"
```

`~/.config/tmux/scripts/codename.sh`:

```bash
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
```

`~/.config/tmux/scripts/uptime.sh`:

```bash
#!/usr/bin/env bash
# Compact uptime for the tmux status bar, e.g. "2d 04h 17m"
awk '{ s = int($1); printf "%dd %02dh %02dm", s / 86400, s % 86400 / 3600, s % 3600 / 60 }' /proc/uptime
```

`~/.config/tmux/CLAUDE.md`, which documents the setup for future agents:

````markdown
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
- The "cyberdeck" look is all in the after-TPM section. Its colours come from the main wallpaper (a long-exposure night hillside): copper `#d08a52` (accent), teal `#6fb3b8`, golden olive `#d8c07a`, moss `#9fb565`, ember red `#d9705a`, dark indigo `#23263d` for inactive pills, `#5c6170` for dim text and `#0e0d12` for text on pills. It includes:
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
````

Then run `chmod +x ~/.config/tmux/scripts/*.sh`.

### 4b. Plugins (TPM)

`tmux.conf` starts TPM from `~/.tmux/plugins/tpm`. Because the config lives in `~/.config/tmux`, TPM installs the plugins into **`~/.config/tmux/plugins/`**, and `tmux.conf` hard-codes paths there: the `tmux-cpu` scripts and `tokyo-night-tmux/src/custom-number.sh`.

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
tmux new-session -d -s setup        # TPM's installer needs a running server
~/.tmux/plugins/tpm/scripts/install_plugins.sh
tmux kill-session -t setup
ls ~/.config/tmux/plugins           # expect: tmux-cpu tmux-sensible tmux-sessionx tmux-sidebar tokyo-night-tmux tpm
```

If the installer puts the plugins elsewhere, clone them directly into `~/.config/tmux/plugins/`:
- `tmux-plugins/tmux-sidebar`
- `omerxx/tmux-sessionx`
- `tmux-plugins/tmux-sensible`
- `nikolovlazar/tokyo-night-tmux`
- `tmux-plugins/tmux-cpu`

All of these are on GitHub.

### 4c. Check

```bash
tmux -L test -f ~/.config/tmux/tmux.conf start-server \; kill-server      # no output = no errors
tmux -L test -f ~/.config/tmux/tmux.conf new-session -d \; new-session -d -s named
tmux -L test ls        # unnamed sessions get codenames like AURORA-3340; 'named' keeps its name
tmux -L test kill-server
~/.config/tmux/plugins/tmux-cpu/scripts/cpu_percentage.sh   # prints e.g. 3.1%
```

### 4d. Why it's built this way

- **Before and after the TPM line:** the `tokyo-night-tmux` theme overwrites `status-left` and `status-right`, the window formats, the pane-border options and `message-style` when it loads. So all customisations sit **after** the `run '~/.tmux/plugins/tpm/tpm'` line, and the `@plugin` and `@tokyo-night-tmux_*` lines stay before it.
- **`tmux-cpu`:** its `#{cpu_percentage}` placeholders never get filled in, because the theme clears `status-right` first. The config calls the scripts directly instead.
- **Focused-tab underline:** tmux 3.8 underlines the focused tab by default (`window-status-current-style underscore`), so the config sets it to `default`.
- **Commas in tmux formats:** inside `#{?cond,a,b}`, separate the parts of `#[...]` styles with spaces, not commas. A comma ends the branch.

## 5. Omarchy

### 5a. Hook that keeps tmux panes transparent

`omarchy-theme-set-tmux` runs on every theme change and paints every tmux pane with the theme background in two ways: it sets `window-style` and `window-active-style`, and it sends OSC 11 to each pane. That hides Ghostty's transparency. This hook undoes only the background parts.

Save this as a file named `tmux-transparent`, then install it with `omarchy hook install theme-set ./tmux-transparent`. The installer puts it in `~/.config/omarchy/hooks/theme-set.d/`.

```bash
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
```

Before relying on it, read `$(which omarchy-theme-set-tmux)` and `$(which omarchy-theme-set)` to confirm that this Omarchy version still sets `window-style` and sends OSC 11, and that it still runs the `theme-set` hooks **after** the tmux step. On 4.0.6 the post-theme commands run in parallel and are awaited, then `omarchy-hook theme-set` runs.

### 5b. Theme "cyberdeck"

```bash
mkdir -p ~/.config/omarchy/themes/cyberdeck/backgrounds
```

`~/.config/omarchy/themes/cyberdeck/colors.toml`:

```toml
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
```

`~/.config/omarchy/themes/cyberdeck/icons.theme`:

```text
Yaru-purple
```

Compare these against a stock theme to make sure the theme format hasn't changed: `ls /usr/share/omarchy/themes/catppuccin` and `cat /usr/share/omarchy/themes/catppuccin/colors.toml`.

### 5c. Wallpapers

There are three wallpapers in `~/.config/omarchy/themes/cyberdeck/backgrounds/`. Omarchy cycles through them in filename order with `omarchy theme bg next`.

| File | What it is | Source |
|---|---|---|
| `0-perplexity-hero.png` | **Main wallpaper.** A long-exposure night photo: indigo sky, copper and teal light trails, a flash-lit hillside with white flowers | `dr-hero-bg.webp` in the user's GitHub repo, cropped |
| `1-nightfield.png` | A generated, original take on the same style | `nightfield.sh` below |
| `2-grid.png` | A dark grid with copper and cyan glows | the `magick` command below |

The T14s panel is 16:10: either 1920x1200, or 2880x1800 on the 2.8K OLED. Check with `hyprctl monitors`, and set `W`/`H` below to match.

**Main wallpaper, from the repo.** The source image is 2757x1379 (2:1), so crop it from the centre to 16:10 and then scale it to the screen size.

```bash
# Replace with the raw link to dr-hero-bg.webp in the user's repo.
# A GitHub page link (https://github.com/<user>/<repo>/blob/<branch>/<path>/dr-hero-bg.webp) becomes
#   https://raw.githubusercontent.com/<user>/<repo>/<branch>/<path>/dr-hero-bg.webp
IMAGE_URL='<REPO-RAW-URL>'

mkdir -p ~/Downloads ~/.config/omarchy/themes/cyberdeck/backgrounds
curl -fL -o ~/Downloads/dr-hero-bg.webp "$IMAGE_URL"
# Private repo: curl gets a 404. Use the GitHub CLI instead (after `gh auth login`):
#   gh api -H 'Accept: application/vnd.github.raw' repos/<user>/<repo>/contents/<path>/dr-hero-bg.webp > ~/Downloads/dr-hero-bg.webp

magick identify ~/Downloads/dr-hero-bg.webp        # expect: WEBP 2757x1379
W=1920 H=1200                                       # 2880 1800 on the 2.8K OLED
magick ~/Downloads/dr-hero-bg.webp -gravity center -crop 2206x1379+0+0 +repage -resize ${W}x${H}! -quality 95 \
  ~/.config/omarchy/themes/cyberdeck/backgrounds/0-perplexity-hero.png
```

On the 2880x1800 panel this upscales the image about 1.3x. The photo is soft, so that looks fine.

This photo is Perplexity's artwork. It's fine as the user's own wallpaper, but don't copy it anywhere public.

**Backup wallpapers.** Either copy `1-nightfield.png`, `2-grid.png` and `nightfield.sh` from the source machine, or regenerate them with the commands below. Both render at 1920x1200; on a 2880x1800 panel, upscale them with `magick in.png -resize 2880x1800 out.png`.

**Night field** is an original long-exposure-style night hillside: an indigo sky, copper and teal light trails, and a flash-lit bushy ridge with pale flowers. It takes about 25 seconds to render. Save this as `~/.config/omarchy/themes/cyberdeck/nightfield.sh`, make it executable, and run `nightfield.sh ~/.config/omarchy/themes/cyberdeck/backgrounds/1-nightfield.png 7`. The last argument is the seed; a different number gives a different hillside.

```bash
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
```

**Grid:** a near-black gradient with a faint cyan grid, copper and cyan glows, and a small corner tag:

```bash
cd ~/.config/omarchy/themes/cyberdeck/backgrounds && W=1920 H=1200 && FONT=$(fc-match -f '%{file}' 'Iosevka Nerd Font Mono') && \
magick -size ${W}x${H} -define gradient:extent=Diagonal radial-gradient:'#141626'-'#07080c' \
  \( -size 1700x1700 -define gradient:extent=Minimum radial-gradient:'rgba(203,166,247,0.20)'-'rgba(203,166,247,0)' \) -geometry -550-650 -compose over -composite \
  \( -size 1500x1500 -define gradient:extent=Minimum radial-gradient:'rgba(137,221,255,0.13)'-'rgba(137,221,255,0)' \) -geometry +1050+300 -composite \
  \( -size ${W}x${H} xc:none -fill none -stroke 'rgba(137,221,255,0.05)' -strokewidth 1 -draw "$(for x in $(seq 0 48 $W); do printf 'line %d,0 %d,%d ' $x $x $H; done; for y in $(seq 0 48 $H); do printf 'line 0,%d %d,%d ' $y $W $y; done)" \) -geometry +0+0 -composite \
  -stroke none -fill 'rgba(120,130,175,0.6)' -font "$FONT" -pointsize 15 -gravity southeast -annotate +40+32 'CYBERDECK // SYS ONLINE' \
  -depth 8 2-grid.png
```

### 5d. Apply the theme

```bash
omarchy theme set cyberdeck
omarchy theme bg set ~/.config/omarchy/themes/cyberdeck/backgrounds/0-perplexity-hero.png
omarchy theme current          # Cyberdeck
tmux show -g window-style      # if a tmux server is running: should print 'window-style default' (the hook ran)
hyprctl getoption general:col.active_border   # gradient data: eed08a52 ee6fb3b8 45deg
```

### 5e. Top bar icon size

`~/.config/omarchy/shell.toml` is the user override, merged over the theme's `shell.toml`. The bar has no icon-size setting: icon size, icon spacing and bar height all scale with `[font] base-size` (base-size / 12), which also scales every text size and the spacing in menus and notifications. To enlarge only the icons, raise `base-size`, pin each text token back to its base-size 14 value, and shrink `[spacing] scale` by the same ratio (14 / 18). Use:

```toml
[font]
# Bar icons, icon spacing and bar height scale with base-size / 12; there is no
# separate icon-size setting. base-size is set high (18) to enlarge the bar icons
# (~20px, up from ~15px at base-size 14), and every text token below is pinned to
# its base-size 14 value so text in the bar, menus and notifications stays the
# same size as before.
base-size = 18
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
# Spacing grows with base-size too; 14/18 keeps panels, menus and notifications
# at their base-size 14 dimensions.
scale = 0.7778

[bar]
# Bar height at base-size 12; scaled with base-size (24 -> 36px at base-size 18,
# up from ~33px) so the larger icons have room.
size-horizontal = 24

# These were ignored by the shell (it only reads size-horizontal / size-vertical
# under [bar]); icon sizes come from base-size above.
# icon-size = 18
# icon-canvas = 20
# icon-slot = 32
```

On Omarchy 4.0.6, `/usr/share/omarchy/shell/Commons/Style.qml` reads `[font] base-size` and per-token font keys (`caption`, `body-small`, `body`, `subtitle`, `title`, `heading`, `display`, `display-large`, `icon-small`, `icon`, `icon-large`), `[spacing] scale` and `scale-with-font`, and `[bar] size-horizontal`, `size-vertical` and `scale-with-font`. Keys like `icon-size` are ignored. Recheck `Style.qml` on the new install in case the keys or the default token multipliers have changed; the pinned values above are `round(14 × multiplier)`.

The bar reloads this file automatically. Check: `hyprctl layers -j | jq -c '.[].levels[][] | select(.namespace=="omarchy-bar") | {w,h}'` gives `h` 36 before 5i, and 41 after it. Bar icons draw at about 20 px (about 15 px at base-size 14), and menu and notification text is unchanged.

**Tell the user:** the monitor panel's text-size control and `omarchy display text size` rewrite `base-size`, which changes the icon size again and undoes the pinning ratio.

### 5f. Lock screen with an unblurred wallpaper

The built-in lock screen (`omarchy.lock`) already shows the current wallpaper, but it blurs it at full strength. The blur is fixed in the code, so the user chose to clone the plugin and turn the blur off. **Tell the user that the clone stops receiving Omarchy's lock-screen updates** (including security fixes), and confirm they still want it.

```bash
omarchy plugin clone omarchy.lock      # creates ~/.config/omarchy/plugins/<username>.lock and switches to it
```

In `~/.config/omarchy/plugins/<username>.lock/LockView.qml`, inside the `MultiEffect` that sits on top of the `wallpaper` Image, replace
`blurEnabled: root.loadBackground && wallpaper.status === Image.Ready` with `blurEnabled: false`. Leave everything else alone.

Then run `omarchy restart shell`. This removes the old built-in lock's IPC handler; before the restart, the journal warns that another handler is registered for target `lock`. Check:

```bash
omarchy plugin list | grep -i lock     # omarchy.lock disabled, <username>.lock enabled
omarchy-shell lock preview             # shows the lock screen without locking; then:
omarchy-shell lock hidePreview
```

To undo: `omarchy plugin remove <username>.lock` and `omarchy plugin enable omarchy.lock`, then `omarchy restart shell`.

### 5g. Lock screen HUD clock and status line

This adds two things to the cloned lock screen from 5f, both display-only; nothing touches the password field or authentication:
- **Clock:** a large `HH:mm` above the password box, with `SUN 01 NOV 2026 · W44` under it (the week number is copper).
- **Status line:** a terminal-style line under the box, on a dark backing so it stays readable over the bright flowers. It shows:
  - `SYSTEM LOCKED // <HOSTNAME> ▮` while idle, with a blinking cursor and ` · N FAILED` after failed attempts
  - `AUTHENTICATING… ▮` in copper while typing
  - `VERIFYING…` while checking the password
  - `ACCESS DENIED · ATTEMPT N` in red after a wrong password

Make three edits to `~/.config/omarchy/plugins/<username>.lock/LockView.qml`:

1. Add `import Quickshell.Io` after `import QtQuick.Effects`.
2. Insert this block in the root `Item`, just before `signal submitPassword(string password)`:

```qml
  // --- Cyberdeck additions: HUD clock + terminal-style status line ---------
  // Display-only; nothing here touches the password field or authentication.
  property var now: new Date()
  property bool cursorOn: true
  property string hostName: "LOCALHOST"
  readonly property string statusText: authenticatingPassword ? "VERIFYING…"
    : errorState ? "ACCESS DENIED · ATTEMPT " + failedAttempts
    : passwordInput.text.length > 0 ? "AUTHENTICATING…"
    : "SYSTEM LOCKED // " + hostName + (failedAttempts > 0 ? " · " + failedAttempts + " FAILED" : "")

  // ISO-8601 week number (Qt's date formats don't have one)
  function isoWeek(d) {
    var t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
    var day = t.getUTCDay() || 7
    t.setUTCDate(t.getUTCDate() + 4 - day)
    var yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1))
    return Math.ceil(((t - yearStart) / 86400000 + 1) / 7)
  }

  FileView {
    id: hostFile
    path: "/etc/hostname"
    onLoaded: {
      var h = hostFile.text().trim()
      if (h.length > 0) root.hostName = h.toUpperCase()
    }
  }

  Timer {
    interval: 1000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  Timer {
    interval: 530
    running: root.visible
    repeat: true
    onTriggered: root.cursorOn = !root.cursorOn
  }
  // -------------------------------------------------------------------------
```

3. Insert this block inside the main `Rectangle`, right after the full-screen `MouseArea` and before `BorderSurface {` (the password field, `id: inputField`):

```qml
    // Cyberdeck: large HUD clock with date and ISO week, above the password field
    Column {
      id: hudClock
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: inputField.top
      anchors.bottomMargin: 56
      spacing: 4
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#d0000000"
        shadowBlur: 0.8
        shadowVerticalOffset: 2
        shadowHorizontalOffset: 0
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Qt.formatDateTime(root.now, "HH:mm")
        color: Commons.Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(Style.font.display * 4)
        font.weight: Font.Light
        font.letterSpacing: 4
      }

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        Text {
          textFormat: Text.PlainText
          text: Qt.formatDateTime(root.now, "ddd dd MMM yyyy").toUpperCase()
          color: Commons.Color.lock.text
          opacity: 0.85
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.letterSpacing: 3
        }
        Text {
          textFormat: Text.PlainText
          text: "·"
          color: Commons.Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
        }
        Text {
          textFormat: Text.PlainText
          text: "W" + root.isoWeek(root.now)
          color: Commons.Color.accent
          font.family: Style.font.family
          font.pixelSize: Style.font.heading
          font.letterSpacing: 3
        }
      }
    }

    // Cyberdeck: dark backing so the status line stays readable over bright wallpaper
    Rectangle {
      anchors.centerIn: statusLine
      width: statusLine.implicitWidth + 28
      height: statusLine.implicitHeight + 12
      color: Commons.Color.lock.background
      opacity: 0.75
      radius: Style.cornerRadius
    }

    // Cyberdeck: terminal-style status line under the password field
    Text {
      id: statusLine
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: inputField.bottom
      anchors.topMargin: 18
      textFormat: Text.PlainText
      text: root.statusText + ((root.errorState || root.authenticatingPassword) ? "" : (root.cursorOn ? " ▮" : "  "))
      color: root.errorState ? Commons.Color.lock.textError
        : (root.authenticatingPassword || passwordInput.text.length > 0) ? Commons.Color.accent
        : Commons.Color.lock.text
      opacity: (root.errorState || root.authenticatingPassword || passwordInput.text.length > 0) ? 1.0 : 0.8
      font.family: Style.font.family
      font.pixelSize: Style.font.subtitle
      font.letterSpacing: 2.5
      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#d0000000"
        shadowBlur: 0.7
        shadowVerticalOffset: 1
        shadowHorizontalOffset: 0
      }
    }
```

**Hot reload doesn't pick these up:** the shell's hot reload keeps a cached copy of `LockView.qml`, so run `omarchy restart shell` after editing. Check with `omarchy-shell lock preview`, then `omarchy-shell lock hidePreview`, and look for errors with `qs log --pid $(pgrep -f 'quickshell -n -p /usr/share/omarchy/shell' | head -1) | grep -i lockview`. The preview disables input, so only the idle state shows there.

### 5h. Lock screen keeps the display on (when plugged in)

The built-in lock screen turns the display and keyboard backlight off after 5 seconds without input (`idleBlankTimer` in the lock's `Service.qml` runs `omarchy-brightness-keyboard off; omarchy-brightness-display off`). The user wants the screen to stay on the whole time it's locked while plugged in; on battery it still turns off after 5 seconds, to save power. Nothing else turns the display off: the idle settings in `shell.json` (screensaver at 150 s, lock at 300 s) and the Hyprland config have no screen-off timer.

This edits the cloned lock from 5f. Back up `~/.config/omarchy/plugins/<username>.lock/Service.qml`, then:

1. Add `import Quickshell.Services.UPower` after `import Quickshell.Services.Pam`.
2. Replace

```qml
  function armBlankTimer() {
    idleBlankTimer.armedAt = Date.now()
    idleBlankTimer.restart()
  }
```

with:

```qml
  // Cyberdeck: keep the display on while locked, unless running on battery.
  // The built-in lock turns the display (and keyboard backlight) off after 5 s
  // without input; that now only happens on battery. Machines without a
  // battery (the mini PC) always count as on AC, so the display stays on.
  // Set this to false to keep it on even on battery, or true to always blank.
  readonly property bool blankDisplayWhenLocked: UPower.onBattery

  // Plugging in or unplugging while locked takes effect straight away.
  onBlankDisplayWhenLockedChanged: if (lockRequested) armBlankTimer()

  function armBlankTimer() {
    if (!blankDisplayWhenLocked) {
      idleBlankTimer.stop()
      return
    }
    idleBlankTimer.armedAt = Date.now()
    idleBlankTimer.restart()
  }
```

Every path that would blank the display goes through `armBlankTimer()` (locking, waking, finishing a password check), so this covers them all; unlocking still runs `omarchy-system-wake` as before. `UPower.onBattery` is UPower's `OnBattery` property (`busctl get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery`), which is `false` on machines without a battery.

Then run `omarchy restart shell` (hot reload doesn't pick up edits to the cloned lock). Check:

```bash
omarchy plugin list | grep -i lock     # <username>.lock enabled
omarchy-shell lock isLocked            # false (the lock service answers)
qs log --pid $(pgrep -f 'quickshell -n -p /usr/share/omarchy/shell' | head -1) | grep -iE 'lock.*Service.qml|UPower'   # no errors
```

`omarchy-shell lock preview` doesn't run the blank timer, so ask the user to lock for real (`omarchy system lock` or Super + Ctrl + L) and leave it alone for more than 5 seconds: the screen should stay on when plugged in and turn off on battery.

**OLED burn-in:** if the display is OLED, tell the user a lock screen left on for hours can burn in, because the clock and status line don't move.

To change it: set `blankDisplayWhenLocked` to `false` (always on) or `true` (always off after 5 s, the Omarchy default), then `omarchy restart shell`.

### 5i. Top bar: cyberdeck HUD frame, workspace pills and beaker button

The user chose this design through a series of questions:
- **Frame:** the horizontal bar floats as a HUD frame. It sits half a window gap below the screen edge and a full window gap in from each side, so it lines up with the tiled windows below. Inside is a translucent dark fill (75%); the outline is copper at 0.55 opacity, even all the way around, with square corners. There are no dividers between the left, centre and right groups, and the frame is static (no hover or alert effects).
- **Workspaces:** numbered pills without leading zeros (workspace 10 shows `0`). The focused one is filled with the theme accent (copper) with dark text; the others are hollow, outlined in light grey when they have windows and dim grey when empty.
- **Menu button:** the Omarchy logo at the top left is replaced by a science beaker (Octicons "beaker", U+F499) in the normal bar text colour, at the same size as the other bar icons.
- **Unchanged:** the clock (`Sunday 19:40`) and all the other widgets.

This needs copies of two built-in plugins, `omarchy.bar` and `omarchy.workspaces`. **Tell the user that the copies stop receiving Omarchy's updates to the bar and workspaces widget**, and confirm they still want them. The menu button is a separate custom widget, so the Omarchy menu itself stays built-in and keeps updating.

```bash
cp ~/.config/omarchy/shell.json ~/.config/omarchy/shell.json.bak.$(date +%s)
omarchy plugin clone omarchy.bar          # creates ~/.config/omarchy/plugins/<username>.bar and switches to it
omarchy plugin clone omarchy.workspaces   # creates ~/.config/omarchy/plugins/<username>.workspaces and switches to it
```

**1. The frame.** Make four edits to `~/.config/omarchy/plugins/<username>.bar/Bar.qml`:

1. Add `import QtQuick.Shapes` after `import QtQuick.Layouts`.
2. Insert this block right after the line `readonly property int barSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal` (at the root level, around line 570):

```qml
  // --- Cyberdeck HUD frame (<username>) ---
  // Horizontal bars float as a HUD frame: a translucent dark fill inside an
  // even copper outline with square corners. hudNotch > 0 cuts the corners at
  // 45° and hudCornerAccents adds bright copper corner brackets. Vertical
  // bars keep the stock look. barSize stays the content height (widgets size
  // themselves from it); the window adds the edge gap on top of that.
  readonly property bool hudEnabled: !vertical
  // Gap between screen edge and frame: half the Hyprland window gap, as
  // Omarchy uses for panels. Sides use the full gap so the frame lines up
  // with tiled windows below it.
  readonly property int hudEdgeGap: hudEnabled ? Style.gapsOut : 0
  readonly property int hudSideGap: hudEnabled ? Style.gapsOut * 2 : 0
  readonly property int hudOuterSize: barSize + hudEdgeGap
  // Corner cut size; 0 gives square corners (the accents become L-brackets).
  readonly property real hudNotch: 0
  readonly property real hudAccentLength: Math.round(barSize * 0.38)
  readonly property real hudFillAlpha: 0.75
  readonly property color hudCopper: "#d08a52"
  readonly property real hudOutlineAlpha: 0.55
  readonly property color hudOutline: Qt.rgba(hudCopper.r, hudCopper.g, hudCopper.b, hudOutlineAlpha)
  // Bright copper brackets on each corner. Off: the outline is one even
  // copper all the way round.
  readonly property bool hudCornerAccents: false
  readonly property color hudFill: Qt.rgba(background.r, background.g, background.b, transparent ? 0 : hudFillAlpha)
```

3. In `component BarPanel: PanelWindow`, inside `margins { … }`, change `-root.barSize` to `-root.hudOuterSize` on the `top:` and `bottom:` lines only (left and right stay `-root.barSize`).
4. In the same component, replace these lines:

```qml
    implicitHeight: root.vertical ? 0 : root.barSize
    color: root.transparent ? "transparent" : root.background
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-bar"
    WlrLayershell.layer: WlrLayer.Top

    Loader {
      anchors.fill: parent
```

with:

```qml
    implicitHeight: root.vertical ? 0 : root.hudOuterSize
    color: root.hudEnabled || root.transparent ? "transparent" : root.background
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-bar"
    WlrLayershell.layer: WlrLayer.Top
    // Only the frame takes input; the gaps around it click through.
    mask: Region { item: hudFrame }

    // The HUD frame. In vertical mode it fills the window and draws nothing.
    Item {
      id: hudFrame
      x: root.hudSideGap
      y: root.position === "bottom" ? 0 : root.hudEdgeGap
      width: parent.width - root.hudSideGap * 2
      height: root.vertical ? parent.height : root.barSize

      Shape {
        id: hudShape
        anchors.fill: parent
        visible: root.hudEnabled
        preferredRendererType: Shape.CurveRenderer

        readonly property real w: width
        readonly property real h: height
        readonly property real n: root.hudNotch
        readonly property real a: root.hudAccentLength
        // Inset half a pixel so 1px strokes land on whole pixels.
        readonly property real o: 0.5

        // Fill and dim outline: a rectangle, corners cut at 45° when hudNotch > 0.
        ShapePath {
          fillColor: root.hudFill
          strokeColor: root.hudOutline
          strokeWidth: 1
          joinStyle: ShapePath.MiterJoin
          startX: hudShape.n; startY: hudShape.o
          PathLine { x: hudShape.w - hudShape.n; y: hudShape.o }
          PathLine { x: hudShape.w - hudShape.o; y: hudShape.n }
          PathLine { x: hudShape.w - hudShape.o; y: hudShape.h - hudShape.n }
          PathLine { x: hudShape.w - hudShape.n; y: hudShape.h - hudShape.o }
          PathLine { x: hudShape.n; y: hudShape.h - hudShape.o }
          PathLine { x: hudShape.o; y: hudShape.h - hudShape.n }
          PathLine { x: hudShape.o; y: hudShape.n }
          PathLine { x: hudShape.n; y: hudShape.o }
        }

        // Bright copper accents tracing each corner.
        ShapePath {
          fillColor: "transparent"
          strokeColor: root.hudCornerAccents ? root.hudCopper : "transparent"
          strokeWidth: 1.5
          joinStyle: ShapePath.MiterJoin
          capStyle: ShapePath.FlatCap
          // top-left
          startX: hudShape.n + hudShape.a; startY: hudShape.o
          PathLine { x: hudShape.n; y: hudShape.o }
          PathLine { x: hudShape.o; y: hudShape.n }
          PathLine { x: hudShape.o; y: Math.min(hudShape.h / 2, hudShape.n + hudShape.a * 0.5) }
          // top-right
          PathMove { x: hudShape.w - hudShape.n - hudShape.a; y: hudShape.o }
          PathLine { x: hudShape.w - hudShape.n; y: hudShape.o }
          PathLine { x: hudShape.w - hudShape.o; y: hudShape.n }
          PathLine { x: hudShape.w - hudShape.o; y: Math.min(hudShape.h / 2, hudShape.n + hudShape.a * 0.5) }
          // bottom-right
          PathMove { x: hudShape.w - hudShape.n - hudShape.a; y: hudShape.h - hudShape.o }
          PathLine { x: hudShape.w - hudShape.n; y: hudShape.h - hudShape.o }
          PathLine { x: hudShape.w - hudShape.o; y: hudShape.h - hudShape.n }
          PathLine { x: hudShape.w - hudShape.o; y: Math.max(hudShape.h / 2, hudShape.h - hudShape.n - hudShape.a * 0.5) }
          // bottom-left
          PathMove { x: hudShape.n + hudShape.a; y: hudShape.h - hudShape.o }
          PathLine { x: hudShape.n; y: hudShape.h - hudShape.o }
          PathLine { x: hudShape.o; y: hudShape.h - hudShape.n }
          PathLine { x: hudShape.o; y: Math.max(hudShape.h / 2, hudShape.h - hudShape.n - hudShape.a * 0.5) }
        }
      }
    }

    Loader {
      // Content sits inside the frame, pulled in past the notched corners.
      x: hudFrame.x + (root.hudEnabled ? root.hudNotch * 0.5 : 0)
      y: hudFrame.y
      width: hudFrame.width - (root.hudEnabled ? root.hudNotch : 0)
      height: hudFrame.height
```

Keep the rest of the `Loader` (its `sourceComponent` line and `HoverHandler`) as it is.

`barSize` stays the content height, because every widget sizes itself from it; the window adds the edge gap on top. The bar popups (audio, network and so on) position themselves from the bar window's real height, so they clear the frame. The input mask makes the gaps around the frame click-through.

**2. The workspace pills.** Make three edits to `~/.config/omarchy/plugins/<username>.workspaces/Workspaces.qml`:

1. Insert this block right after the line `readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)`:

```qml
  // --- Cyberdeck pills (<username>) ---
  // Every workspace is a rounded pill showing its number, like the tmux window
  // tabs. The focused one is filled with the theme accent (copper #d08a52 in
  // cyberdeck); the rest are hollow, outlined in light grey when they have
  // windows and dim grey when empty.
  readonly property color pillFocused: Color.accent
  readonly property color pillFocusedText: "#0e0d12"
  readonly property color pillOccupiedBorder: "#9fa39f"
  readonly property color pillOccupiedText: "#dde2da"
  readonly property color pillEmptyBorder: "#5c6170"
  readonly property color pillEmptyText: "#5c6170"
  readonly property real pillHeight: Math.round(root.barSize * 0.6)
  readonly property real pillWidth: Math.round(pillHeight * 1.35)
```

2. In the `GridLayout`, change `columnSpacing: root.vertical ? 0 : Style.space(1)` to `columnSpacing: root.vertical ? 0 : Style.space(4)`.
3. In the `WidgetButton` inside the `Repeater`, replace everything from `bar: root.bar` to the `onPressed` line (the `bar`, `text`, `opacity`, `horizontalMargin`, `verticalPadding`, `fixedWidth`, `fixedHeight` and `onPressed` lines) with:

```qml
        id: wsButton
        bar: root.bar
        text: modelData === 10 ? "0" : String(modelData)
        foreground: focused ? root.pillFocusedText : (occupied ? root.pillOccupiedText : root.pillEmptyText)
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : root.pillWidth
        fixedHeight: root.vertical ? root.pillHeight + Style.space(2) : root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }

        Rectangle {
          z: -1
          anchors.centerIn: parent
          width: root.pillWidth
          height: root.pillHeight
          radius: height / 2
          color: wsButton.focused ? root.pillFocused : "transparent"
          border.width: wsButton.focused ? 0 : 1
          border.color: wsButton.occupied ? root.pillOccupiedBorder : root.pillEmptyBorder

          Behavior on color { ColorAnimation { duration: 140 } }
        }
```

This drops the stock focused-workspace glyph (U+F14FB) and the 50% opacity on empty workspaces.

**3. The beaker menu button.** Create `~/.config/omarchy/bar/modules/beaker-menu.qml`:

```qml
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
```

The icon is written as the escape `\uf499`, so there's no raw glyph to lose when copying. Then swap it in for the built-in menu button:

```bash
cd ~/.config/omarchy
jq '.bar.layout.left |= map(if .id == "omarchy.menu" then {"id":"beaker-menu","type":"qml"} else . end)' shell.json > shell.json.tmp && mv shell.json.tmp shell.json
jq -c '.bar.layout.left' shell.json     # [{"id":"beaker-menu","type":"qml"},{"id":"<username>.workspaces"}]
```

**4. Apply and check.** Hot reload doesn't pick up QML edits to the copied plugins (the shell keeps a cached copy), so run `omarchy restart shell` after every edit. Then:

```bash
omarchy plugin list | grep -E 'bar|workspaces'   # <username>.bar and <username>.workspaces enabled
hyprctl layers -j | jq -c '.[].levels[][] | select(.namespace=="omarchy-bar") | {w,h}'   # h = 41 (36 content + 5 gap)
qs log --pid $(pgrep -f 'quickshell -n -p /usr/share/omarchy/shell' | head -1) | grep -iE 'Bar.qml|Workspaces.qml|beaker'   # no errors
omarchy-shell shell toggle omarchy.menu '{"menu":"root"}'   # the Omarchy menu opens; run it again to close it
grim -g "0,0 600x50" /tmp/bar.png   # look at it: copper frame, beaker, pills
```

Ask the user to click the beaker (left: menu, right: terminal) and a workspace pill, and to open one bar popup.

**Settings to tune later** (run `omarchy restart shell` after changing any):

| Setting | File | Value |
|---|---|---|
| `hudOutlineAlpha` | `Bar.qml` | `0.55`: outline opacity (1 = solid copper) |
| `hudFillAlpha` | `Bar.qml` | `0.75`: background opacity inside the frame |
| `hudNotch` | `Bar.qml` | `0`: square corners; above 0 cuts the corners at 45° by that many pixels |
| `hudCornerAccents` | `Bar.qml` | `false`: `true` adds bright copper brackets on each corner |
| `hudEdgeGap` / `hudSideGap` | `Bar.qml` | `Style.gapsOut` / `Style.gapsOut * 2`: 5 px and 10 px with Hyprland `gaps_out = 10` |
| `pillFocused` | `Workspaces.qml` | `Color.accent`: follows the theme accent |
| `pillOccupiedBorder` / `pillEmptyBorder` | `Workspaces.qml` | `#9fa39f` / `#5c6170` |

**Known limits:**
- **Notifications:** notification cards are placed at the bar's content height plus half a gap and don't know about the frame's edge gap, so they sit right against the frame's bottom edge. Fixing that would need a copy of `omarchy.notifications`.
- **Side bars:** if the bar is moved to the left or right edge, the frame turns off and the bar looks stock.

**To undo:** `omarchy bar use omarchy.bar`; in `shell.json` change `beaker-menu` back to `{"id":"omarchy.menu"}` and `<username>.workspaces` back to `omarchy.workspaces`; then `omarchy restart shell`.

### 5j. Top bar: mortality counter

A widget at the start of the right-hand group (before the tray) showing the user's age in years as a decimal that keeps ticking up: `MORTALITY 31.4159265`. It's a hollow copper pill (theme accent) like the workspace pills, with a copper `MORTALITY` label in small letter-spaced capitals and the number in the bar text colour, using tabular digits so it doesn't jitter. Hovering shows the birth date and the number of days alive.

How it counts:
- The whole number goes up exactly on each birthday, at the birth time; the fraction is how far the user is from the last birthday to the next one, so leap years are handled.
- It counts real elapsed time, so across a daylight-saving change it differs by an hour from a naive wall-clock calculation. That's expected.
- With 7 decimals the last digit changes about every 3 seconds (8 decimals: every 0.3 seconds). The timer runs every 100 ms only while the widget is visible.

Create `~/.config/omarchy/bar/modules/mortality.qml`:

```qml
import QtQuick
import qs.Commons
import qs.Commons as Commons

// Mortality counter: your age in years as a decimal that keeps ticking up,
// e.g. "MORTALITY 34.49817235", inside a hollow copper pill.
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

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "MORTALITY"
        color: root.copper
        font.family: bar ? bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.letterSpacing: 1.5
        renderType: Text.NativeRendering
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: root.ageText
        color: root.textColor
        font.family: bar ? bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
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
```

**Use `Commons.Color`, not `Color`:** in a custom module loaded from `~/.config/omarchy/bar/modules/`, a bare `Color.accent` from `import qs.Commons` resolves to `undefined` (the journal shows `Unable to assign [undefined] to QColor` and the pill draws black). The file above imports `qs.Commons as Commons` and uses `Commons.Color.accent`, which works.

Add it to the start of the right-hand section, with the birth date from section 1 (replace `<BIRTH-DATE>`, e.g. `1990-01-31` or `1990-01-31T06:30`):

```bash
cd ~/.config/omarchy
cp shell.json shell.json.bak.$(date +%s)
jq '.bar.layout.right |= ([{"id":"mortality","type":"qml","birth":"<BIRTH-DATE>","decimals":7}] + map(select(.id != "mortality")))' shell.json > shell.json.tmp && mv shell.json.tmp shell.json
jq -c '.bar.layout.right[0]' shell.json   # {"id":"mortality","type":"qml","birth":"...","decimals":7}
```

Settings changes in `shell.json` (birth date, `decimals`) apply straight away. Changes to `mortality.qml` itself need `omarchy restart shell` (cached code, as in 5i). Without a valid `birth` the pill shows `set birth date`.

Check:
- **Screenshot:** `grim -g "1860,0 700x50" /tmp/mortality.png` (adjust the x offset to the screen's logical width minus 700). The pill and label should be copper, not black.
- **Value:** compare with `python3 -c "from datetime import datetime as D; b=D(1990,1,31); n=D.now(); y=n.year-b.year-((n.month,n.day)<(b.month,b.day)); l=b.replace(year=b.year+y); x=b.replace(year=b.year+y+1); print(y+(n-l)/(x-l))"` (put in the real date). It should match to about 4 decimals, or within 0.000114 if a daylight-saving change happened since the last birthday.
- **Log:** `qs log --pid $(pgrep -f 'quickshell -n -p /usr/share/omarchy/shell' | head -1) | grep -i mortality` shows no errors.

To remove it: delete the `mortality` entry from `bar.layout.right` in `shell.json`.

## 6. Hyprland: border, glow, corners

Back up `~/.config/hypr/looknfeel.lua`, then **append** this block at the end. Leave the commented examples above it alone.

```lua
-- Cyberdeck look (pairs with the "cyberdeck" Omarchy theme; border colours come from the theme).
hl.config({
  decoration = {
    -- Sharp, square window corners.
    rounding = 0,

    -- Soft copper glow behind the focused window; none behind the others.
    shadow = {
      enabled = true,
      range = 8,
      render_power = 3,
      color = "rgba(d08a5210)",
      color_inactive = "rgba(00000000)",
    },
  },
})

-- Slowly rotate the active border's copper -> teal gradient.
-- This redraws the focused window border continuously; delete this line to keep it static.
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" })
```

The border colours themselves come from the theme (`hyprland_active_border` in `colors.toml`). Apply and check:

```bash
hyprctl reload && sleep 1 && hyprctl configerrors     # must print nothing
hyprctl getoption decoration:rounding                 # int: 0
hyprctl getoption decoration:shadow:color             # gradient data: 10d08a52 ...
```

**Before appending, check the config format:**
- This block uses Omarchy's **Lua** Hyprland config (`hl.config`, `hl.animation`). If the new install still uses `hyprland.conf` / `looknfeel.conf` instead, translate it to hyprlang (`decoration { rounding = 0; shadow { ... } }`, `animation = borderangle, 1, 100, linear, loop`).
- Look at `/usr/share/omarchy/default/hypr/looknfeel.lua` for the current syntax.

**Laptop battery:** the `borderangle` loop redraws continuously. If the user wants to save battery, delete that line; the gradient stays, it just doesn't rotate.

## 7. Starship prompt

Back up `~/.config/starship.toml`, then write:

```toml
# Cyberdeck two-line prompt: pills matching the tmux bar and Omarchy "cyberdeck" theme.
#   ╭─ user@host ( ~/dir ) ( branch ) status ⟨ 2.3s ⟩
#   ╰─❯
add_newline = true
command_timeout = 200
format = '[╭─](#5c6170) $username$hostname$directory$git_branch$git_status$cmd_duration$line_break$character'

[username]
show_always = true
format = '[$user](#8f939f)'

[hostname]
ssh_only = false
format = '[@$hostname](#8f939f) '

[directory]
truncation_length = 3
truncation_symbol = "…/"
format = '[](fg:#d08a52)[ $path$read_only ](fg:#d08a52 bold)[](fg:#d08a52) '
read_only = " 󰌾"

[git_branch]
symbol = " "
format = '[](fg:#23263d)[$symbol$branch](fg:#9fb565 bg:#23263d)[](fg:#23263d) '

[cmd_duration]
min_time = 2000
format = '[⟨ $duration ⟩](#d8c07a) '

[character]
success_symbol = "[╰─❯](bold #d08a52)"
error_symbol = "[╰─✗](bold #d9705a)"

[git_status]
format     = '[$all_status]($style)'
style      = "#d8c07a"
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
```

Check it, without running `starship config`:

```bash
STARSHIP_SHELL= starship prompt --status 0 </dev/null | sed 's/\x1b\[[0-9;]*m//g'
# expect:  ╭─ user@host  ~/dir
#          ╰─❯
STARSHIP_SHELL= starship prompt --status 1 --cmd-duration 4300 </dev/null | sed 's/\x1b\[[0-9;]*m//g'
# expect a "⟨ 4s ⟩" timer and a "╰─✗" second line
```

The prompt shows the folder in a hollow copper outline pill, the git branch in a dark pill with moss text, git status in amber, a timer for commands over 2 seconds, and the arrow turns ember red on errors.

## 8. Palette reference

The colours come from the main wallpaper: night indigo and warm near-black for the base, copper from the light trails, teal from their fringe, moss and golden olive from the hillside, and the pale flower white for text.

| Role | Hex |
|---|---|
| Background / darker | `#0e0d12` / `#08070a` |
| Lighter background / selection (night indigo) | `#1c1d2e` / `#26294a` |
| Text (flower white) | `#dde2da` |
| Dim text (steel) | `#5c6170` |
| Inactive pills, git-branch pill | `#23263d` |
| Copper (accent: session pill, outline pills, prompt, menus, messages, glow, top-bar frame, active workspace pill) | `#d08a52` |
| Teal (focused tab, CPU, HOST, border gradient end) | `#6fb3b8` |
| Golden olive (MEM, command deck title, KERNEL, git status, timer, last-window marker) | `#d8c07a` |
| Moss (clock, UPTIME, prefix-active session pill, git branch) | `#9fb565` |
| Ember red (active pane line, errors) | `#d9705a` |
| Indigo / violet (theme blue / magenta) | `#8c97d6` / `#a99bd8` |

## 9. What the user should see

- **tmux top row:**
  - on the left, a copper session pill that turns moss with a keyboard icon while the prefix (C-j) is held, followed by window tabs as pills (teal for the focused window, dark indigo for the rest)
  - on the right, pills for CPU (teal), MEM (golden olive) and the clock (moss)
- **tmux second row:** `HOST · KERNEL · UPTIME`, centred inside thin copper rounded brackets.
- **tmux panes:**
  - a heavy border on each pane with a top label such as `▷ AI AGENT :: claude`, `▷ EDITOR :: nvim` or `▷ TERMINAL :: bash`; the active pane is ember red
  - transparent backgrounds that show the blurred wallpaper through Ghostty
- **tmux keys:**
  - `C-j Space` opens the "◢ COMMAND DECK ◣" menu
  - `C-j |` and `C-j -` split the window
  - `C-j h/j/k/l` move between panes
  - `C-j r` reloads the config
- **Desktop:**
  - square window corners
  - a slowly rotating copper-to-teal border and a barely visible copper glow on the focused window
  - the Perplexity night-hillside photo as the wallpaper (`omarchy theme bg next` cycles to Nightfield and Grid)
  - a top bar floating as a HUD frame with an even copper outline and square corners, a science-beaker menu button at the top left, workspaces as numbered pills (the active one filled copper, the others hollow), a hollow copper `MORTALITY 31.4159265` pill on the right whose last digit ticks every few seconds, and larger icons
  - a lock screen with the sharp, unblurred wallpaper behind the password box, a large HUD clock with date and week above it, and a `SYSTEM LOCKED // HOST ▮` status line below it; while plugged in, the screen stays on the whole time it is locked

## 10. Final check: Nerd Font glyphs survived

```bash
python3 -I - <<'EOF'
import pathlib
want = {
  "~/.config/tmux/tmux.conf": [0xE0B6, 0xE0B4, 0xE0B7, 0xE0B5, 0xF11C, 0xEBCA, 0xF120, 0xF006F],
  "~/.config/starship.toml":  [0xE0B6, 0xE0B4, 0xE0B7, 0xE0B5, 0xF033E],
}
for f, cps in want.items():
    s = pathlib.Path(f).expanduser().read_text()
    missing = [f"U+{c:04X}" for c in cps if chr(c) not in s]
    print(f, "OK" if not missing else f"MISSING {missing}")
EOF
```

Where each glyph goes, if any are missing:
- **`tmux.conf`:**
  - `status-left`: E0B6 … F11C … E0B4
  - `status-right`: E0B6 / E0B4 around each pill
  - `window-status-current-format`: E0B6, EBCA, E0B4
  - `window-status-format`: E0B6, F120, F006F, E0B4
  - `status-format[1]`: E0B7 … E0B5
- **`starship.toml`:**
  - `[directory] format`: E0B7 … E0B5
  - `read_only`: F033E
  - `[git_branch] format`: E0B6 … E0B4

## 11. Laptop: ThinkPad T14s Gen 3 adjustments

The source mini PC has an AMD Ryzen 7 PRO 5850U (8 cores, 16 threads), Radeon Vega 8 graphics, 32 GB RAM, a 1 TB NVMe and a 3840×2160 monitor at 1.5× scale. The setup uses about 5.5 GB of RAM and 43 GB of disk there, with a load average around 1.3.

| | Mini PC | T14s Gen 3 | Effect |
|---|---|---|---|
| CPU | Ryzen 7 PRO 5850U, 8C/16T | Core i5-1245U, 2 performance + 8 efficiency cores, 12T | About even: faster single-thread (apps, shell), slower sustained all-core work; runs warm and throttles under long loads |
| Graphics | Radeon Vega 8 | Intel Iris Xe (80 EU) | Slightly faster; well supported by Hyprland |
| Screen | 3840×2160 @ 1.5× | 14" 1920×1080 or 1920×1200 | About a quarter of the pixels, so blur, transparency and animations cost far less |
| RAM | 32 GB | 16 GB, soldered | Enough for this setup; tight only with VMs, Docker or very many browser tabs |
| Storage | 1 TB | 512 GB | Plenty |

Everything in this guide runs well on it. The adjustments below are about screen size and battery.

### 11a. Check the hardware first

The laptop was bought refurbished from a listing with copy-paste errors (it called it an "Elitebook" and said 1080p), so confirm what it is before tuning anything:

```bash
cat /sys/class/dmi/id/product_version     # ThinkPad T14s Gen 3
lscpu | grep 'Model name'                 # 12th Gen Intel(R) Core(TM) i5-1245U
free -h | head -2                         # ~15 GiB total
hyprctl monitors -j | jq -r '.[] | "\(.name) \(.width)x\(.height)@\(.refreshRate) scale \(.scale)"'   # eDP-1, resolution, scale
lspci | grep -i -E 'ipu|imaging'          # any output: the webcam is a MIPI camera (see below)
ls /dev/video* 2>/dev/null; command -v fprintd-list && lsusb | grep -i -E 'synaptics|fingerprint'
```

Tell the user the results, especially:
- **Screen:** resolution, refresh rate and the scale Hyprland picked (`~/.config/hypr/monitors.lua` uses `scale = "auto"`). Section 11b depends on these.
- **Webcam:** some Intel ThinkPads of this generation use an Intel IPU6 MIPI camera, which has limited Linux support. If `lspci` shows an IPU/imaging device, warn the user the camera may not work in video calls without extra drivers; a USB-style camera shows up as `/dev/video*` and just works.
- **Fingerprint reader:** if present, offer 11e.

### 11b. Top bar and icon size

Section 5e's sizes were tuned on the mini PC's 4K monitor at 1.5×. Everything in the shell is in logical pixels, so on the laptop the same numbers take a bigger share of the screen width (it's 1920 or 1536 logical pixels wide instead of 2560), while their physical size depends on the scale Hyprland picked. Apply 5e as written first, take a screenshot (`grim -g "0,0 600x50" /tmp/bar.png`) and ask the user whether the icons and text look right.

To change only the **icon size**, change `base-size` to `N` and `[spacing] scale` to `14 / N` (keeps menus and panels at the same size). The pinned text tokens stay as they are. For example `N = 16` with `scale = 0.875`, or `N = 14` with `scale = 1.0` (icons back to about 15 px). The bar height follows automatically (`size-horizontal 24 × N / 12`).

To change the **text size** to `T` px instead of 14, re-pin every token to `round(T × multiplier)` and set `scale` to `T / N`:

| Token | Multiplier | At T = 14 | At T = 13 | At T = 15 |
|---|---|---|---|---|
| `caption` | 0.833 | 12 | 11 | 12 |
| `body-small` | 0.917 | 13 | 12 | 14 |
| `body` | 1.0 | 14 | 13 | 15 |
| `subtitle` | 1.083 | 15 | 14 | 16 |
| `title` | 1.167 | 16 | 15 | 18 |
| `heading` | 1.333 | 19 | 17 | 20 |
| `display` | 2.0 | 28 | 26 | 30 |
| `display-large` | 2.333 | 33 | 30 | 35 |
| `icon-large` | 1.5 | 21 | 20 | 23 |

The bar reloads `shell.toml` by itself. The top-bar frame (5i) follows Hyprland's `gaps_out`, so it lines up with the windows on any screen.

### 11c. Rotating border

The `borderangle` loop from section 6 redraws the focused window border all the time, which stops the graphics chip from idling and is the biggest battery cost in the setup. Recommend the user removes that line on the laptop (the copper→teal gradient stays, it just doesn't rotate). Omarchy has no hook that runs on plugging in or unplugging, so switching it automatically by power state isn't covered here.

### 11d. Lock screen and battery

Nothing to change: the 5h edit already keeps the screen on while locked only on AC, and lets it turn off after 5 seconds on battery. Test both: lock while plugged in (stays on), then unplug while locked (turns off after 5 seconds).

### 11e. Fingerprint unlock

If the laptop has a fingerprint reader, offer `omarchy setup security fingerprint` (sudo, polkit and the lock screen). The cloned lock from 5f keeps the built-in fingerprint support, so it works on the HUD lock screen too. It changes PAM configuration and needs sudo, so the user runs it in their own terminal.

### 11f. Power profiles and other battery savers

- **Power profiles:** `omarchy powerprofiles list` shows what's available; `omarchy powerprofiles set battery power-saver` and `omarchy powerprofiles set ac balanced` make it switch automatically. Ask the user before changing these.
- **tmux:** `status-interval 1` re-runs the CPU and memory scripts every second (needed for the seconds in the clock). Its battery cost is small; if the user wants to trim it, `status-interval 5` with `%H:%M` in `status-right` is the trade-off.
- **Ghostty blur:** `background-blur` is cheap on a 1080p-class screen; leave it.

### 11g. What the user should notice

- Apps, tmux, Ghostty and the shell feel the same or slightly snappier than on the mini PC.
- Long builds or other sustained heavy work are a bit slower, and the fan spins up.
- With the rotating border off and the lock screen blanking on battery, idle battery drain is close to stock Omarchy.

