#!/bin/bash
set -eu

# Older versions of the package load this helper from the incoming release.
name=""
mount=""
parent=""
while [[ $# -ge 2 ]]; do
    case "$1" in
        -n|--name) name="$2" ;;
        -m|--mount) mount="$2" ;;
        -a|--app) parent="$2" ;;
        -d|--dmg) ;;
        *) exit 1 ;;
    esac
    shift 2
done
[[ $# -eq 0 && -n "$name" && "$name" != */* && "$parent" == /* && "$mount" == "/tmp/$name" ]]

app="${parent%/}/$name.app"
source="$mount/$name.app"
[[ -d "$app" && ! -L "$app" && -d "$source" && ! -L "$source" ]]
staging="$(/usr/bin/mktemp -d "${parent%/}/.Updater.XXXXXXXX")"
backup="$staging/previous.app"
finish() {
    if [[ -e "$backup" ]]; then
        if [[ ! -e "$app" ]]; then /bin/mv "$backup" "$app"; fi
        if [[ -e "$backup" ]]; then
            echo "Previous application retained at $backup" >&2
            return
        fi
    fi
    /bin/rm -rf "$staging"
}
trap finish EXIT

/usr/bin/ditto "$source" "$staging/update.app"
requirement="$(/usr/bin/codesign -d -r- "$app" 2>&1 | /usr/bin/sed -n 's/^designated => //p')"
[[ -n "$requirement" ]]
/usr/bin/codesign --verify --strict --deep --all-architectures -R="$requirement" "$staging/update.app"
/usr/bin/hdiutil detach "$mount"
/bin/rmdir "$mount" || true

/bin/mv "$app" "$backup"
/bin/mv "$staging/update.app" "$app"
if ! /usr/bin/open -n "$app"; then
    /bin/mv "$app" "$staging/failed.app"
    exit 1
fi
/bin/rm -rf "$backup"
