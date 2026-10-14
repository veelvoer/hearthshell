#!/bin/sh
# Ask the user for an image file and print its path. Exit code 2 = no file chooser installed.
start="${HOME}/Pictures"
[ -d "$start" ] || start="$HOME"
if command -v kdialog >/dev/null 2>&1; then
    exec kdialog --title "Choose a wallpaper" --getopenfilename "$start" "Images (*.png *.jpg *.jpeg *.webp *.bmp)"
elif command -v zenity >/dev/null 2>&1; then
    exec zenity --file-selection --title="Choose a wallpaper" --filename="$start/" \
        --file-filter="Images | *.png *.jpg *.jpeg *.webp *.bmp"
elif command -v yad >/dev/null 2>&1; then
    exec yad --file --title="Choose a wallpaper" --filename="$start/"
fi
exit 2
