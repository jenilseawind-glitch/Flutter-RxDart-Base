# Quality gate. See verify.dart for options (--fast, --no-snapshot).
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\..")
dart run scripts/agent/verify.dart @args
exit $LASTEXITCODE
