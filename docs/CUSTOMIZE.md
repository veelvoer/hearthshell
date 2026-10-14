# Customizing hearthshell

Almost everything is a switch in the settings panel (**Super + ,**). This page is for the rest:
the command line, the files, and how to add things.

## The settings panel

| Page | What is in it |
|---|---|
| Appearance | themes, quick looks, accent colour, UI font, animation speed, wallpapers (add your own, shuffle, dim, blur, fit, auto-change) |
| Creator | make your own theme from five colours (or extract them from a wallpaper) |
| Bar | layout presets (classic, pill, islands, flat, minimal), top or bottom, opacity, roundness, clock, and under "More bar options": height, gaps, text size, spacing, icon colours, workspace style and count |
| Modules | choose which modules appear and where (left / middle / right, order), and whether each shows text |
| Windows | gaps, border width, corner radius, focus dimming; "Shadows and borders" for shadow and gradient borders |
| Input | focus follows mouse, natural scrolling, tap to click, pointer speed, key repeat |
| Glass | frosted glass for the bar, the settings panel, the launcher and the terminal, glass amount, blur strength |
| System | which apps follow the theme; terminal opacity, font size, padding, cursor; launcher size; lock screen clock |

Rarely used options sit behind a **More ...** row that is collapsed by default. A **Reset** button on
the Modules and About pages restores defaults.

## From the command line

```sh
hearthshell settings              # open or close the panel
hearthshell theme tokyo           # any theme id (see below)
hearthshell look glass            # classic, cozy, glass, compact, islands, minimal, vivid
hearthshell set barStyle '"pill"' # change one setting; the value is JSON
hearthshell set gapsIn 4
hearthshell apply                 # rewrite the themed config files (kitty, rofi, hyprland ...)
hearthshell ipc show              # every function the shell exposes
hearthshell lock
```

Theme ids: `everforest pink yellow green blue teal gruvbox nord catppuccin tokyo rosepine dracula kanagawa`
(the names in the panel are Everforest, Sakura, Amber, Fern, Glacier, Lagoon, Gruvbox, Nord, Catppuccin,
Tokyo Night, Rosé Pine, Dracula, Kanagawa), plus `custom-...` ids for themes you make.

## Where things live

All inside `~/.config/quickshell/hearthshell/`:

| File | Purpose |
|---|---|
| `settings.json` | every setting, written by the panel. Safe to edit while the shell is stopped |
| `custom-themes.json` | themes made with the Creator |
| `themes.json` | the built-in themes: colours, border gradient, terminal palette |
| `wallpapers/<theme>/<n>.jpg` | the images of each theme |
| `wallpapers.json` | where the built-in wallpapers come from |
| `scripts/apply-theme.py` | writes the themed files for kitty, rofi, GTK, hyprlock, fish and Hyprland |
| `pam-service` | PAM service name the lock screen uses |

`settings.json` keys and their defaults are listed in `shell.qml` (the `defaults` block). A few
examples: `barStyle` (`classic|pill|islands|flat|minimal`), `barPos` (`top|bottom`), `modules`
(`{"left": [...], "center": [...], "right": [...]}`), `motion` (`off|relaxed|normal|snappy`),
`accent` (`""` or `"#rrggbb"`), `font`, `gapsIn`, `gapsOut`, `rounding`, `blurSize`, `glassAmount`.

## Add a theme by hand

Use the Creator in the panel if you can. To do it in JSON, add an entry to `custom-themes.json`
(it survives updates; built-in `themes.json` does not):

```json
{
  "custom-mytheme": {
    "name": "My theme", "blurb": "Custom theme", "custom": true, "walls": 0,
    "bg": "#1e1e2e", "text": "#cdd6f4", "wsa": "#cba6f7", "wso": "#45475a",
    "wsi": "#313244", "wst": "#1e1e2e", "wsti": "#bac2de", "icon": "#89b4fa",
    "border": "#cba6f77f", "grad": ["cba6f7", "89b4fa", "f5c2e7"],
    "term": { "red": "#f38ba8", "green": "#a6e3a1", "yellow": "#f9e2af",
              "blue": "#89b4fa", "magenta": "#f5c2e7", "cyan": "#94e2d5" }
  }
}
```

`bg`/`text` are the background and text colours, `wsa` is the accent, `icon` the second accent, `wso`/`wsi`/`wsti`
the workspace pill colours, `grad` the Hyprland border gradient, `term` the terminal palette.
Put wallpapers in `wallpapers/custom-mytheme/1.jpg`, `2.jpg`, ... and set `walls` to how many you have.

## Change the key binds

Super + , and Super + N live in `~/.config/hypr/hearthshell.lua` (or `.conf`). Edit them there, then
`hyprctl reload`. Uninstalling still works: that file is tracked, your edit is only lost with it.

## Change what gets themed

Settings -> System switches kitty, fish, rofi, GTK and hyprlock on or off. Switching one off stops
hearthshell writing to it; run `hearthshell uninstall` to remove the hooks entirely.

## Develop

The shell is plain QML. Edit files in `~/.config/quickshell/hearthshell`; Quickshell reloads on save.
Start it from a terminal with `hearthshell` to see warnings. Keep your changes in your clone of the
repository and re-run `./install.sh` to copy them over.
