# Installing hearthshell

This guide explains everything: what you need, how to install (quickly or fully by hand), exactly
what changes on your system, and how to remove it again. You stay in control at every step.

- [What you need](#what-you-need)
- [Quick install](#quick-install)
- [What the installer changes](#what-the-installer-changes)
- [Distro notes](#distro-notes)
- [Manual install, step by step](#manual-install-step-by-step)
- [First run](#first-run)
- [Updating](#updating)
- [Uninstalling](#uninstalling)
- [Troubleshooting](#troubleshooting)

## What you need

hearthshell is a Quickshell configuration for a **Hyprland** session. It does not replace your
compositor and it does not need a display manager change.

| Needed | Why | Required? |
|---|---|---|
| Hyprland | workspaces, window borders, key binds, IPC (`hyprctl`) | yes |
| Quickshell 0.3+ (`qs` / `quickshell`) | the shell itself, built with the Hyprland, PAM, PipeWire, UPower, Network and Bluetooth modules | yes |
| Python 3 | applies themes to your other apps, builds custom themes | yes |
| ImageMagick (`magick`, or `convert` on IM6) | wallpaper recolouring, colour extraction | yes |
| grim | screenshot behind the lock screen | for the lock screen |
| A Nerd Font | the icons in the bar (`JetBrainsMono Nerd Font` is what the installer offers) | recommended |
| NetworkManager | the Wi-Fi / ethernet module and menu | optional |
| BlueZ | the Bluetooth module and menu | optional |
| brightnessctl | the brightness module (it hides itself without it) | optional |
| kdialog or zenity | the file picker for "Add your own wallpaper" | optional |
| kitty, rofi, fish, hyprlock, GTK apps | themed along with the shell when present | optional |

Check what you already have at any time with `hearthshell doctor`.

## Quick install

```sh
git clone https://github.com/veelvoer/hearthshell
cd hearthshell
./install.sh --dry-run      # prints every step, changes nothing
./install.sh                # asks before each choice
```

The installer is plain POSIX `sh` (no bash needed) and refuses to run as root. It uses `sudo` or
`doas` only to install packages, and only after you say yes.

One-liner (downloads the repository to a temporary folder and runs the same installer; read
[get.sh](../get.sh) before you pipe anything to a shell):

```sh
curl -fsSL https://raw.githubusercontent.com/veelvoer/hearthshell/main/get.sh | sh
curl -fsSL https://raw.githubusercontent.com/veelvoer/hearthshell/main/get.sh | sh -s -- --dry-run
```

### Options

| Option | Effect |
|---|---|
| `-n`, `--dry-run` | print what would be done, change nothing |
| `-y`, `--yes` | answer yes to every question (for scripts) |
| `--no-deps` | never install packages |
| `--no-fonts` | do not download the Nerd Font |
| `--no-wallpapers` | do not download and recolour wallpapers |
| `--no-integrate` | install only the shell; touch none of your other configs |
| `--no-binds` | do not add Super + , and Super + N |
| `--no-kitty`, `--no-rofi`, `--no-gtk` | leave that app alone |
| `--autostart hyprland` | (default) start with Hyprland, via one line in its config |
| `--autostart systemd` | start through a systemd user service that restarts on a crash |
| `--autostart none` | do not start automatically; run `hearthshell` yourself |
| `--dotfiles` | also install the author's own configs from `dotfiles/` (replaces yours, backed up; see [dotfiles/README.md](../dotfiles/README.md)) |
| `--no-dotfiles` | never offer the dotfiles |
| `--fish-prompt` | also install the hearthshell fish prompt (yours is backed up) |
| `--start` | start the shell when finished |

## What the installer changes

Everything it does is recorded in `~/.local/state/hearthshell/manifest`. Nothing outside this table is touched.
(Paths use the XDG defaults; `XDG_CONFIG_HOME` and friends are honoured.)

| Path | What | When |
|---|---|---|
| `~/.config/quickshell/hearthshell/` | the shell (QML, scripts, themes), your settings, custom themes and wallpapers | always |
| `~/.local/bin/hearthshell` | the launcher / remote control | always |
| `~/.local/share/hearthshell/` | a copy of the uninstaller, so it works even if you delete the clone | always |
| `~/.local/state/hearthshell/` | the manifest and backups of files before the first change | always |
| `~/.config/hypr/hearthshell.lua` (or `.conf`) | layer rules, Super + , / Super + N binds, autostart | unless `--no-integrate` |
| `~/.config/hypr/hyprland.lua` (or `.conf`) | **one block of 3 lines** that loads the file above, between `hearthshell` markers | unless `--no-integrate` |
| `~/.config/hypr/hearthshell-theme.lua` (or `.conf`) | generated: gaps, borders, rounding, shadows, blur, input settings | written by the shell |
| `~/.config/hypr/hyprlock-hearthshell.conf`, `hearthshell-hyprlock.conf` | a hyprlock template and its generated colours (your `hyprlock.conf` is never touched) | when `~/.config/hypr` exists |
| `~/.config/kitty/kitty.conf` + `hearthshell-theme.conf` | one `include` line (marked block) + the generated colours | when kitty is installed |
| `~/.config/rofi/themes/hearthshell.rasi` + `hearthshell-colors.rasi` | the launcher theme; made default only if you had no `config.rasi` | when rofi is installed |
| `~/.config/gtk-3.0/gtk.css`, `gtk-4.0/gtk.css` + `hearthshell.css` | one `@import` line (marked block) + generated colours | asks first |
| fish universal variables (`qs_*`, `fish_color_*`, `fish_pager_color_*`) | prompt and syntax colours. **Your originals are saved and restored on uninstall.** | when fish is installed |
| `~/.config/fish/functions/fish_prompt.fish` | the hearthshell prompt (original backed up) | only with `--fish-prompt` |
| `~/.config/systemd/user/hearthshell.service` | autostart service | only with `--autostart systemd` |
| `~/.local/share/fonts/hearthshell/` | JetBrainsMono Nerd Font | only if you have no icon font and say yes |
| `hypr/hyprland.lua`, `hyprlock.conf`, `kitty/kitty.conf`, `rofi/config.rasi`, `fish/config.fish`, `cava/`, shell `settings.json` | the author's dotfiles. **Replaces your files, each backed up first and restored on uninstall** | only with `--dotfiles` (never answered by `--yes`) |
| packages | whatever your package manager installs for missing tools | only if you say yes |

"Marked block" means the lines are wrapped like this, and uninstalling removes exactly that and nothing else:

```
# >>> hearthshell:hearthshell >>>
include hearthshell-theme.conf
# <<< hearthshell:hearthshell <<<
```

Nothing is downloaded except (a) the wallpaper images, from the sources listed in
[shell/wallpapers.json](../shell/wallpapers.json), (b) the font, from the Nerd Fonts release page,
(c) packages from your distribution.

## Distro notes

The installer picks the package manager it finds and installs missing tools one package at a time, so
one unknown package name never blocks the rest.

| Distro family | Manager | Quickshell package | Notes |
|---|---|---|---|
| Arch, Manjaro, EndeavourOS | pacman | `quickshell` | Hyprland and hyprlock are in the repos too |
| Fedora | dnf | `quickshell` | tested here |
| openSUSE | zypper | `quickshell` (Tumbleweed) | untested |
| Debian, Ubuntu, Mint | apt | **none in the main archive** | build Quickshell from source, see below; the installer still installs everything else |
| Alpine | apk | `quickshell` (edge) | untested |
| Void | xbps | check `xbps-query -Rs quickshell` | untested |
| Gentoo | emerge | `gui-apps/quickshell` (GURU overlay) | untested |
| Solus | eopkg | none known | untested |
| NixOS | nix | `quickshell` in nixpkgs | declarative: add the packages to your configuration, then `./install.sh --no-deps` |

If your distribution has no Quickshell package, build it from source following the official guide
(<https://quickshell.org/docs/guide/install-setup/>), make sure `qs` ends up in your `PATH`, then run
`./install.sh --no-deps`.

NixOS example (adjust to your setup):

```nix
environment.systemPackages = with pkgs; [
  quickshell python3 imagemagick grim brightnessctl zenity
  nerd-fonts.jetbrains-mono
];
```

## Manual install, step by step

This is the same thing the installer does, written out so you can do it yourself.
`$CONF` means `~/.config` (or your `XDG_CONFIG_HOME`).

**1. Install the dependencies** from the table at the top with your package manager.

**2. Copy the shell.**

```sh
mkdir -p $CONF/quickshell/hearthshell
cp -R shell/. $CONF/quickshell/hearthshell/
chmod +x $CONF/quickshell/hearthshell/scripts/*.py $CONF/quickshell/hearthshell/scripts/*.sh
echo '{}' > $CONF/quickshell/hearthshell/custom-themes.json
```

**3. Tell the lock screen which PAM service to use** (`hyprlock` if `/etc/pam.d/hyprlock` exists, else `login`):

```sh
echo hyprlock > $CONF/quickshell/hearthshell/pam-service
```

**4. Install the launcher.**

```sh
install -Dm755 shell/bin/hearthshell ~/.local/bin/hearthshell     # make sure ~/.local/bin is in PATH
```

**5. Icon font (if you have none).** Any Nerd Font works; for example download
`JetBrainsMono.tar.xz` from <https://github.com/ryanoasis/nerd-fonts/releases/latest>, unpack it
into `~/.local/share/fonts/` and run `fc-cache -f`.

**6. Wallpapers (optional).**

```sh
python3 $CONF/quickshell/hearthshell/scripts/fetch-wallpapers.py          # all themes, a few minutes
python3 $CONF/quickshell/hearthshell/scripts/fetch-wallpapers.py nord     # or just one
```

Skip it and every theme uses a plain gradient; you can add your own images in Settings.

**7. Hyprland.** Use the section that matches your config file.

*Lua config (`hyprland.lua`).* Create `$CONF/hypr/hearthshell.lua`:

```lua
hl.layer_rule({ match = { namespace = "^quickshell-settings$" }, blur = true, ignore_alpha = 0.1, no_anim = true })
hl.layer_rule({ match = { namespace = "^quickshell-popup$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^quickshell-wallpaper$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^quickshell-bar$" }, no_anim = true })
hl.bind("SUPER + comma", hl.dsp.exec_cmd("hearthshell settings"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("hearthshell lock"))
hl.on("hyprland.start", function() hl.exec_cmd("hearthshell") end)
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/hearthshell-theme.lua")
```

and add one line to the end of `hyprland.lua`:

```lua
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/hearthshell.lua")
```

(Use full paths such as `/home/you/.local/bin/hearthshell` if `~/.local/bin` is not in Hyprland's `PATH`.)

*hyprlang config (`hyprland.conf`).* Create `$CONF/hypr/hearthshell.conf`
(the `layerrule` lines use the classic syntax; newer Hyprland versions changed it, check the wiki if a line is rejected):

```
layerrule = noanim, quickshell-settings
layerrule = noanim, quickshell-popup
layerrule = noanim, quickshell-wallpaper
layerrule = noanim, quickshell-bar
layerrule = blur, quickshell-settings
layerrule = ignorealpha 0.1, quickshell-settings
layerrule = blur, quickshell-bar
layerrule = ignorealpha 0.05, quickshell-bar
layerrule = blur, quickshell-popup
layerrule = ignorealpha 0.1, quickshell-popup
bind = SUPER, comma, exec, hearthshell settings
bind = SUPER, N, exec, hearthshell lock
exec-once = hearthshell
source = ~/.config/hypr/hearthshell-theme.conf
```

and add `source = ~/.config/hypr/hearthshell.conf` to `hyprland.conf`.
Do not bind Super + , or Super + N if you already use them; pick other keys.

**8. Other apps (all optional).**

- kitty: add `include hearthshell-theme.conf` as the **last** line of `kitty.conf`.
- rofi: copy `integration/rofi-hearthshell.rasi` to `$CONF/rofi/themes/hearthshell.rasi`, replacing `@CONF@` by your config directory; use it with `rofi -show drun -theme hearthshell`.
- GTK: add `@import 'hearthshell.css';` at the end of `gtk-3.0/gtk.css` and `gtk-4.0/gtk.css`.
- hyprlock: copy `integration/hyprlock-hearthshell.conf` (replace `@CONF@`) and run `hyprlock -c` with it, or copy the colour lines into your own config; the variables are `$qs_fg`, `$qs_inner`, `$qs_outer`, `$qs_accent`.
- fish prompt: copy `integration/fish_prompt.fish` to `$CONF/fish/functions/fish_prompt.fish`.
- systemd instead of the Hyprland autostart line: create `~/.config/systemd/user/hearthshell.service` with `ExecStart=%h/.local/bin/hearthshell run`, `Restart=on-failure`, `WantedBy=default.target`, then `systemctl --user enable --now hearthshell`.

**9. Write the first theme and start.**

```sh
hearthshell apply
hyprctl reload
hearthshell
```

## First run

1. Run `hearthshell doctor`: everything required should say `[ok]`.
2. Press **Super + ,**. The settings panel opens; pages: Appearance, Creator, Bar, Modules, Windows, Input, Glass, System, About.
3. If the bar shows boxes instead of icons you have no Nerd Font (see step 5).

## Updating

```sh
cd hearthshell && git pull && ./install.sh
```

Re-running the installer is safe: it updates the code and keeps your settings, custom themes and
wallpapers. Your own edits inside the installed folder (`~/.config/quickshell/hearthshell`) would be
overwritten, so keep personal changes in a branch of the repository instead.

## Uninstalling

```sh
hearthshell uninstall                    # or ~/.local/share/hearthshell/uninstall.sh
hearthshell uninstall --dry-run          # look first
hearthshell uninstall --keep-data        # keep settings, custom themes, wallpapers in ~/hearthshell-kept-<date>/
hearthshell uninstall --remove-packages  # also remove packages the installer installed
```

It stops the shell, disables the systemd service, removes the generated files, strips only the
marked blocks from your configs, restores files it replaced (and your fish variables) from the
backups taken before the first change, removes the folders it created (if empty), deletes the
install directory, reloads Hyprland and finally deletes its own state and backups. Packages are
kept unless you pass `--remove-packages`, because other programs may rely on them; it lists them
so you can decide. Paths containing spaces are not supported by the manifest.

**Undo by hand** (if the uninstaller is gone): delete `~/.config/quickshell/hearthshell`,
`~/.local/bin/hearthshell`, `~/.local/share/hearthshell`, `~/.local/state/hearthshell`,
the `hearthshell*` files in `~/.config/hypr`, `~/.config/kitty`, `~/.config/rofi` (and `themes/hearthshell.rasi`),
`~/.config/gtk-3.0` and `gtk-4.0`; remove the marked blocks from `hyprland.lua`/`.conf`, `kitty.conf`,
`gtk.css` (the lines between `>>> hearthshell` and `<<< hearthshell`); delete the systemd unit if you made one;
and run `hyprctl reload`. To reset fish colours: `set -e -U qs_pill qs_git qs_fg qs_aqua qs_green qs_amber qs_red`
and set the `fish_color_*` variables you prefer (or `fish_config` -> Colors).

## Troubleshooting

**Nothing appears after installing.** Run `hearthshell doctor`, then start it in a terminal to see
its messages: `hearthshell`. Typical causes: Quickshell missing from `PATH`, not inside a Hyprland session
(set `HEARTHSHELL_FORCE=1` to override), or a Quickshell built without a module the shell uses.

**"module ... is not installed" in the log** (for example `Quickshell.Networking`, `Quickshell.Bluetooth`,
`Quickshell.Services.Pam`). Your Quickshell build lacks that feature. Use a newer or full build.

**Workspaces are empty / "HYPRLAND_INSTANCE_SIGNATURE is unset".** The shell was started outside the
session (for example by a service). `hearthshell` rebuilds that variable itself; make sure autostart
runs `hearthshell`, not `qs` directly.

**Icons are boxes.** Install a Nerd Font (step 5) and restart the shell.

**Super + , does nothing.** Reload Hyprland (`hyprctl reload`). Check `hyprctl configerrors`. If your
config already used that key combination the installer left it out; bind it yourself, see step 7.

**The lock screen rejects the right password.** The PAM service is wrong. Read
`~/.config/quickshell/hearthshell/pam-service`; try `login` or `system-auth` (a file name from `/etc/pam.d/`).

**Wi-Fi / Bluetooth menus are empty.** NetworkManager and BlueZ must be running (`systemctl status NetworkManager bluetooth`).
Pairing a device that needs a PIN confirmation may fail because there is no pairing agent.

**Themes have no wallpaper.** Run `python3 ~/.config/quickshell/hearthshell/scripts/fetch-wallpapers.py`
(needs network and ImageMagick), or add your own in Settings -> Appearance -> Wallpaper.

**kitty / rofi / GTK did not change.** Open Settings -> System and check the switches. kitty needs the
`include` line to be the last in `kitty.conf`; rofi needs `-theme hearthshell` (or `@theme "hearthshell"` in
`config.rasi`); running GTK apps pick up colours when restarted.

**Hyprland settings do not change on older Hyprland (`hyprland.conf`).** The shell then writes
`hearthshell-theme.conf` and sends values with `hyprctl keyword`. Key names differ between Hyprland
versions; check `hyprctl configerrors`. The "glass bar" switch has no effect there (the bar always asks
for blur).

Still stuck? Open an issue and paste the output of `hearthshell doctor` and the first error lines from `hearthshell`.
