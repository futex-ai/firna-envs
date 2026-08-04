#!/usr/bin/env bash
set -euo pipefail

readonly expected_gcsfuse_version='3.11.2'

if [[ "$(whoami)" != "user" ]]; then
  printf 'expected default user "user", got "%s"\n' "$(whoami)" >&2
  exit 1
fi
if [[ "$HOME" != "/home/user" ]]; then
  printf 'expected home "/home/user", got "%s"\n' "$HOME" >&2
  exit 1
fi

for command_name in git curl wget jq python3 pip3 node npm rg unzip zip cc make pkg-config gcsfuse fusermount3 mountpoint; do
  command_path="$(command -v "$command_name")"
  printf 'OK %s: %s\n' "$command_name" "$command_path"
done

git --version
curl --version | head -n 1
wget --version | head -n 1
jq --version
python3 --version
pip3 --version
node --version
npm --version
rg --version | head -n 1
unzip -v | head -n 1
zip -v | head -n 2 | tail -n 1
cc --version | head -n 1
make --version | head -n 1
pkg-config --version
gcsfuse_version="$(gcsfuse --version)"
[[ "$gcsfuse_version" == "gcsfuse version ${expected_gcsfuse_version} "* ]]
[[ -c /dev/fuse ]]
printf '%s\n' "$gcsfuse_version"
printf 'FUSE device %s\n' /dev/fuse
