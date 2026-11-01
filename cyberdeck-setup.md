# Cyberdeck setup guide: tmux, Ghostty and Omarchy

**For:** a Claude Code agent setting up a fresh Omarchy install (target: Lenovo ThinkPad T14s) to match the source machine, a desktop mini PC with Omarchy 4.0.6, tmux 3.8, Ghostty 1.4.0, Starship 1.27.0 and Hyprland 0.56.2.

The look is a "modern hacker but professional" cyberdeck style:
- **Colours:** taken from the main wallpaper: copper, teal, golden olive and moss on a night-indigo, near-black background.
- **tmux:** a pill-shaped status bar, panes labelled by role, transparent panes, a command menu and session codenames.
- **Ghostty:** a see-through background with blur.
- **Omarchy theme "cyberdeck":** a custom colour theme. The main wallpaper is a long-exposure night photo of a flowering hillside, downloaded from the user's GitHub repo, with two generated backup wallpapers.
- **Hyprland:** a rotating copper-to-teal border on the focused window, a faint glow and square corners.
- **Prompt:** a two-line Starship prompt.
- **Top bar:** a larger bar font.

Every file below is the exact content from the source machine.

---

## 0. Ground rules for the agent

- **Load the `omarchy` skill** before editing anything in `~/.config/hypr/`, `~/.config/omarchy/` or `~/.config/ghostty/`. Never edit `/usr/share/omarchy/`; reading it is fine.
- **Back up before overwriting:** `cp file file.bak.$(date +%s)`. A fresh Omarchy install may already ship some of these files, so look at each target before you replace it.
- **Nerd Font characters:** many files below contain Private Use Area glyphs, such as the rounded pill caps U+E0B6 and U+E0B4. They're invisible or look like boxes in many viewers. Copy the code blocks byte for byte, and don't retype or "clean up" lines that look like they have stray spaces. Section 10 has a check that confirms every glyph survived. If you can't copy them reliably, write those lines with Python using `\uXXXX` escapes.
- **Never run `starship config`:** with no arguments it opens an editor and hangs the shell. Use `starship print-config` or `starship prompt` to test.
- **Commands needing `sudo`:** they can't prompt for a password from Claude Code's `!` shell. Ask the user to run them in a real terminal, or use the polkit route (for example `hostnamectl` without `sudo`).
- **Check each step** with the commands given before moving on, and tell the user what changed.

## 1. Questions to ask the user first

1. **Hostname:** what should the machine be called? The source machine is `mini-beast`. The name shows in the tmux status row and the prompt. Have the user run `hostnamectl set-hostname <name>` in their terminal; it goes through polkit.
2. **Rotating border:** on a laptop this redraws continuously and costs a little battery. Ask whether to keep it (section 6).
3. **Wallpaper repo URL:** section 5c downloads the main wallpaper (`dr-hero-bg.webp`) from the user's GitHub repo. If `<REPO-RAW-URL>` in section 5c is still a placeholder, ask the user for the link to the image in their repo. If the repo is private, ask them to run `gh auth login` first (section 5c explains how to download it).

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

### 5e. Top bar size

`~/.config/omarchy/shell.toml` is the user override, merged over the theme's `shell.toml`. Use:

```toml
[font]
# Root size for the shell: bar text uses this size, and bar icons, icon spacing and
# bar height all scale with it (base-size / 12). It also scales menus and notifications.
base-size = 14

[bar]
# Bar height at base-size 12; scaled with base-size (28 -> ~33px at base-size 14).
size-horizontal = 28

# These were ignored by the shell (it only reads size-horizontal / size-vertical
# under [bar]); icon sizes now come from base-size above.
# icon-size = 18
# icon-canvas = 20
# icon-slot = 32
```

On Omarchy 4.0.6, `/usr/share/omarchy/shell/Commons/Style.qml` reads only `[font] base-size` and per-token font keys, plus `[bar] size-horizontal`, `size-vertical` and `scale-with-font`. Bar icon sizes scale with `base-size`, and keys like `icon-size` are ignored. The bar reloads this file automatically; otherwise run `omarchy restart shell`. Recheck `Style.qml` on the new install in case the keys have changed.

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
| Copper (accent: session pill, outline pills, prompt, menus, messages, glow) | `#d08a52` |
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
  - a larger top bar (font size 14)
  - a lock screen with the sharp, unblurred wallpaper behind the password box, a large HUD clock with date and week above it, and a `SYSTEM LOCKED // HOST ▮` status line below it

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
