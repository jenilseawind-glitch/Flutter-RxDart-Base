#!/usr/bin/env bash
# Quality gate. See verify.dart for options (--fast, --no-snapshot).
set -e
cd "$(dirname "$0")/../.."
exec dart run scripts/agent/verify.dart "$@"
