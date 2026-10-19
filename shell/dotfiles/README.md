# The author's dotfiles

These are the configs the shell was built together with, kept here so the whole setup lives in one
repository. They mirror `~/.config`:

| File here | Installs to | What it is |
|---|---|---|
| `hypr/hyprland.lua` | `~/.config/hypr/hyprland.lua` | Hyprland (Lua config): monitors, input, animations, binds, window rules |
| `hypr/hyprlock.conf` | `~/.config/hypr/hyprlock.conf` | hyprlock screen; colours come from hearthshell |
| `kitty/kitty.conf` | `~/.config/kitty/kitty.conf` | kitty: font, cursor trail, padding; colours come from hearthshell |
| `rofi/config.rasi` | `~/.config/rofi/config.rasi` | rofi: behaviour; the look is the hearthshell theme |
| `fish/config.fish` | `~/.config/fish/config.fish` | fish: PATH, abbreviations, the pill prompt (coloured by hearthshell) |
| `cava/config`, `cava/shaders/` | `~/.config/cava/` | audio visualizer |
| `quickshell/settings.json` | `~/.config/quickshell/hearthshell/settings.json` | the shell settings: theme, bar layout, modules, fonts |

The shell itself (everything under `shell/`) is the Quickshell part of the setup.

## Use them

```sh
./install.sh --dotfiles      # install the shell and these configs
```

This **replaces** the files above. Each existing file is copied to `~/.local/state/hearthshell/backups/`
first and `hearthshell uninstall` puts it back. Without `--dotfiles` the installer only asks when it is
run in a terminal (default no), and `--yes` never answers that question, so these are never installed by accident.
`--dry-run` lists exactly which files would be replaced.

They are made for one machine, so read them before you use them:

- `hyprland.lua` has a monitor entry for `DP-3` at 1920x1080@180 and a Belgian keyboard layout (`be`);
  change the MONITORS and INPUT sections.
- It binds `SUPER + Q` to kitty, `SUPER + E` to `kitty -e yazi`, `ALT + Space` to rofi, and so on.
- The rofi config uses the icon theme `Tela-circle-black-dark`; the fish config has a few abbreviations
  that call a `rofi/dashboard.sh` that is not part of the repository.

You can also just copy the parts you like by hand.

## What was changed before it went into the repository

- **Quickshell hooks removed from `hyprland.lua`.** The old autostart through a systemd service, the
  `qs -p ...` key binds (Super + N, Super + ,) and the layer rules for the Quickshell windows are
  now added by hearthshell's installer (`hearthshell.lua`), so they are not there twice. The lid-close
  lock bind calls `hearthshell lock`.
- **Colour lines removed** from kitty and the rofi look moved into the hearthshell theme, so they follow your theme choice.
- `/home/<user>` paths in fish became `$HOME`.

## What is deliberately not here

- `fish/functions/vpsw.fish` (an SSH shortcut to a private server) and `fish_variables` (generated state).
- `fish/conf.d/uv.env.fish` and `micro/buffers/history` (generated / private history).
- GTK and KDE files (`gtk-3.0`, `gtk-4.0`, `kdeglobals`, ...): Plasma regenerates them, and hearthshell adds its colours on top.
- Anything with credentials. Nothing in this folder contains a password, token or key.
