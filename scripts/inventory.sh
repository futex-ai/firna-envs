#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '--- operating system'
cat /etc/os-release
printf 'architecture: '
uname -m
printf 'user: %s\n' "$(whoami)"
printf 'home: %s\n' "$HOME"
printf 'cpu_count: '
nproc
awk '/^MemTotal:/ {printf "memory_mb: %d\n", $2 / 1024}' /proc/meminfo

printf '%s\n' '--- packages'
dpkg-query --show --showformat='${binary:Package} ${Version}\n' | sort

printf '%s\n' '--- tools'
for command_name in git curl wget jq python3 pip3 node npm rg cargo rustc go java docker; do
  if command -v "$command_name" >/dev/null 2>&1; then
    version="$({ "$command_name" --version || true; } 2>&1 | head -n 1)"
    printf 'HAVE %s: %s\n' "$command_name" "$version"
  fi
done

printf '%s\n' '--- environment variable names'
env | sed 's/=.*//' | sort
