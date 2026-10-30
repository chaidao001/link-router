#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
app='build/Link Router.app'
destination="$HOME/Applications/Link Router.app"
legacy="$HOME/Applications/Slack Link Router.app"
identifier='local.linkrouter.app'
upgrade_identifier=''
codesign --verify --strict "$app"
for existing in "$destination" "$legacy"; do
    if [ -e "$existing" ]; then
        installed_id=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$existing/Contents/Info.plist")
        installed_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$existing/Contents/Info.plist")
        installed_executable=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$existing/Contents/Info.plist")
        case "$installed_name:$installed_executable" in
            'Link Router:LinkRouter'|'Link Router:SlackLinkRouter'|'Slack Link Router:SlackLinkRouter') ;;
            *) printf '%s\n' "Unexpected application at $existing; install cancelled."; exit 1 ;;
        esac
        case "$installed_id" in
            "$identifier"|*.slack-link-router) ;;
            *) printf '%s\n' "Unexpected application identifier at $existing; install cancelled."; exit 1 ;;
        esac
        if [ -n "$upgrade_identifier" ] && [ "$installed_id" != "$upgrade_identifier" ]; then
            printf '%s\n' 'The existing installations have different identifiers; install cancelled.'
            exit 1
        fi
        if ! codesign --verify --strict "$existing"; then
            printf '%s\n' "Unexpected application at $existing; install cancelled."
            exit 1
        fi
        upgrade_identifier="$installed_id"
    fi
done
mkdir -p "$HOME/Applications"
staging_dir=$(mktemp -d "$HOME/Applications/.link-router-staging.XXXXXX")
ditto "$app" "$staging_dir/Link Router.app"
# Preserve the existing installation's macOS preferences without putting its
# identifier in the source tree or the public build artifact.
if [ -n "$upgrade_identifier" ] && [ "$upgrade_identifier" != "$identifier" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $upgrade_identifier" "$staging_dir/Link Router.app/Contents/Info.plist"
    codesign --force --sign - "$staging_dir/Link Router.app"
fi
codesign --verify --strict "$staging_dir/Link Router.app"
build/app-control --stop
backup_dir=$(mktemp -d /private/tmp/link-router-backup.XXXXXX)
lsregister='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
for existing in "$destination" "$legacy"; do
    if [ -e "$existing" ]; then
        mv "$existing" "$backup_dir/"
    fi
done
mv "$staging_dir/Link Router.app" "$destination"
rmdir "$staging_dir"
codesign --verify --strict "$destination"
"$lsregister" -f "$destination"
log_path=$(mktemp /private/tmp/link-router-startup.XXXXXX)
open --stdout "$log_path" --stderr "$log_path" "$destination" --args --enable-login
printf '%s\n' "Installed: $destination" "Startup status: $log_path" "Previous app backup: $backup_dir"
