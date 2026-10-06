#!/usr/bin/env bash
# Verify that a workspace's installed agents framework matches this checkout.
#
#   scripts/verify.sh <workspace> [--harness <list>]
#
# Exit 0 = every managed file is byte-identical to what this checkout installs.
# Exit 1 = something is missing, modified, unexpected, or a symlink.
# Permission files that differ from the shipped baseline are WARN, not FAIL, since
# you may have merged them by hand; review the diff.
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install.sh" "$@" --check
