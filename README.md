# hearthshell

A warm, animated desktop shell for [Hyprland](https://hypr.land), built on
[Quickshell](https://quickshell.org). Press **Super + ,** and a settings panel opens where you
change almost everything: themes, wallpapers, the bar, the windows, even your terminal and app launcher.

- **13 themes** (Everforest, Catppuccin, Tokyo Night, Rosé Pine, Dracula, Kanagawa, Gruvbox, Nord and more),
  a **theme maker** for your own, your own wallpapers, accent colour, fonts
- **Bar styles** (classic, pill, islands, flat, minimal and an Apple-style **dynamic island**: a small clock pill that morphs into the bar on hover, into Wi-Fi/Bluetooth/quick-settings menus on click, and into volume, brightness, workspace, charging and now-playing moments), top or bottom, and a **module picker** (with an option to show module text only on hover):
  workspaces, clock, volume, brightness, network, Bluetooth, quick settings, battery
- **Wi-Fi and Bluetooth menus** that grow out of the bar button: networks, passwords, devices
- **Frosted glass**, quick looks (one-click bundles), **your own saved presets**, animation speed
- **One theme for the whole desktop**: kitty, rofi, fish, GTK apps, hyprlock and Hyprland's own borders follow it
- A **lock screen** with the clock that morphs into the bar clock
- An **installer that asks first and an uninstaller that undoes exactly what it did**

## Install

```sh
git clone https://github.com/veelvoer/hearthshell
cd hearthshell
./install.sh
```

That is all. The wizard looks at your system and does the rest:

1. detects your distribution and package manager and shows what it found
2. installs what is missing (packages through your package manager; it asks for your password only for that)
3. **builds Quickshell from source** if your distribution has no package for it (into `~/.local`, no root needed for the build)
4. downloads an icon font and the wallpapers, and recolours the wallpapers for each theme
5. connects Hyprland (key binds, autostart), kitty, rofi and GTK with a few clearly marked lines
6. starts the shell and runs a health check

You pick one of three setups at the start: **Everything** (recommended), **Let me choose each part**, or **Only the shell**.
`./install.sh --yes` skips every question, `./install.sh --dry-run` prints the full plan and every command without changing anything.

One line instead of cloning: `curl -fsSL https://raw.githubusercontent.com/veelvoer/hearthshell/main/get.sh | sh`
(read [get.sh](get.sh) first, it is short).

Then press **Super + ,**. Details, every option, a fully manual install and troubleshooting are in
**[docs/INSTALL.md](docs/INSTALL.md)**.

## The author's own configs

`dotfiles/` holds the configs this was built with (Hyprland, hyprlock, kitty, rofi, fish, cava and the
shell settings). `./install.sh --dotfiles` installs them (replacing yours, with backups that
`hearthshell uninstall` restores). They are made for one laptop, see [dotfiles/README.md](dotfiles/README.md).

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

It targets **Hyprland**, so you need a Hyprland session. The wizard handles the rest: it knows the package
managers of Arch, Debian/Ubuntu, Fedora, openSUSE, Alpine, Void, Gentoo and Solus, and when your distribution
has no Quickshell package it compiles Quickshell for you.

I ran the whole wizard (packages, Quickshell build, install, uninstall) in clean containers on **Arch, Fedora,
Ubuntu 26.04, Debian 13, openSUSE Tumbleweed and Alpine edge**, and it worked on all six; the exact results and
the few caveats (Hyprland itself is not packaged on Debian and Fedora) are in
[docs/INSTALL.md](docs/INSTALL.md#distro-notes). Not run: Void, Gentoo, Solus, NixOS. Containers have no
display, so I only used the finished shell day to day on **Fedora** with a Hyprland that uses the Lua config
(`hyprland.lua`); older `hyprland.conf` setups are supported on a best-effort basis.

If something does not work for you, `hearthshell doctor` and
[docs/INSTALL.md#troubleshooting](docs/INSTALL.md#troubleshooting) come first, then open an issue.

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
