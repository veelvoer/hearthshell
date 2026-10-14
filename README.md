# hearthshell

A warm, animated desktop shell for [Hyprland](https://hypr.land), built on
[Quickshell](https://quickshell.org). Press **Super + ,** and a settings panel opens where you
change almost everything: themes, wallpapers, the bar, the windows, even your terminal and app launcher.

- **13 themes** (Everforest, Catppuccin, Tokyo Night, Rosé Pine, Dracula, Kanagawa, Gruvbox, Nord and more),
  a **theme maker** for your own, your own wallpapers, accent colour, fonts
- **Bar presets** (classic, pill, islands, flat, minimal), top or bottom, and a **module picker**:
  workspaces, clock, volume, brightness, network, Bluetooth, battery
- **Wi-Fi and Bluetooth menus** that grow out of the bar button: networks, passwords, devices
- **Frosted glass**, quick looks (one-click bundles), animation speed
- **One theme for the whole desktop**: kitty, rofi, fish, GTK apps, hyprlock and Hyprland's own borders follow it
- A **lock screen** with the clock that morphs into the bar clock
- An **installer that asks first and an uninstaller that undoes exactly what it did**

## Install

```sh
git clone https://github.com/veelvoer/hearthshell
cd hearthshell
./install.sh --dry-run     # see everything it would do, change nothing
./install.sh               # the real thing; asks before every choice
```

Prefer one line? `curl -fsSL https://raw.githubusercontent.com/veelvoer/hearthshell/main/get.sh | sh`
(read [get.sh](get.sh) first, it is short).

Then press **Super + ,**. The step-by-step guide, the list of what changes on your system, a fully
manual install and troubleshooting are in **[docs/INSTALL.md](docs/INSTALL.md)**.

## Uninstall

```sh
hearthshell uninstall            # or: ~/.local/share/hearthshell/uninstall.sh
```

It reverses everything the installer recorded: files it created, the few lines it added to your
configs (only those lines), files it replaced (restored from backup) and your fish colours.
`--keep-data` keeps your settings and wallpapers, `--remove-packages` also removes packages the
installer added. `--dry-run` shows the plan first.

## Using it

| | |
|---|---|
| `Super + ,` | open / close settings |
| `Super + N` | lock the screen |
| `hearthshell theme nord` | switch theme from a terminal |
| `hearthshell look glass` | apply a quick look |
| `hearthshell doctor` | check dependencies and setup |

More in [docs/CUSTOMIZE.md](docs/CUSTOMIZE.md).

## Does it work on my distro?

It targets **Hyprland**, so it needs a Hyprland session and Quickshell (0.3 or newer). Beyond that the
installer is plain POSIX `sh` and knows the package managers of Arch, Debian/Ubuntu, Fedora, openSUSE,
Alpine, Void, Gentoo and Solus; on NixOS it tells you what to add to your configuration; anywhere else
the [manual install](docs/INSTALL.md#manual-install-step-by-step) lists every step.

Honest status: it was **developed and tested on Fedora** with a Hyprland build that uses the Lua
config (`hyprland.lua`) and Quickshell 0.3.1. Older Hyprland with `hyprland.conf` is supported on a
best-effort basis, and the other package managers are untested. Some distros do not package
Quickshell; the guide links the build instructions. If something does not work for you, `hearthshell doctor`
and [docs/INSTALL.md#troubleshooting](docs/INSTALL.md#troubleshooting) come first, then open an issue.

## Credits

- Wallpapers are **not** included. The installer downloads them from their original sources
  ([dharmx/walls](https://github.com/dharmx/walls) and one image from
  [saneaspect/dotfiles](https://github.com/saneaspect/dotfiles), whose Hyprland setup inspired part of the look)
  and recolours them on your machine. See [shell/wallpapers.json](shell/wallpapers.json); check those
  repositories for the images' licences.
- The settings panel's look and motion follow the [Hearth](https://github.com/veelvoer/hearth) app.
- Colour schemes are inspired by their original projects (Everforest, Catppuccin, Tokyo Night,
  Rosé Pine, Dracula, Kanagawa, Gruvbox, Nord); the palettes here are approximations.

## License

[MIT](LICENSE)
