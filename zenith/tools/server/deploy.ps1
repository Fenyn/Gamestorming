# Exports the duel server and installs it on the box in one go. Run from anywhere:
#   powershell -File zenith\tools\server\deploy.ps1            (export + upload + restart)
#   powershell -File zenith\tools\server\deploy.ps1 -SkipExport (upload the last export)
# Needs key-based SSH to root@<host> (see docs/duel_server.md) and the GDScript-only editor.
param(
    [string]$Server = "root@198.44.38.215",
    [int]$Port = 7777,
    [string]$Godot = "G:\Godot\Godot_v4.6.2-stable_win64_GDSCRIPTONLY.exe",
    [switch]$SkipExport
)
$ErrorActionPreference = "Stop"
$zenith = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$binary = Join-Path $zenith "build\server\eidolarch_server.x86_64"
$install = Join-Path $PSScriptRoot "install.sh"

if (-not $SkipExport) {
    Write-Host "exporting the server with $Godot"
    & $Godot --headless --path $zenith --export-release "Linux server" "build/server/eidolarch_server.x86_64" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "export failed with code $LASTEXITCODE" }
}
if (-not (Test-Path $binary)) { throw "no export at $binary" }
$size = [math]::Round((Get-Item $binary).Length / 1MB, 1)
Write-Host "uploading $size MB to $Server"
& scp -o BatchMode=yes -q $binary $install "${Server}:"
if ($LASTEXITCODE -ne 0) { throw "scp failed with code $LASTEXITCODE" }
Write-Host "installing and restarting eidolarch.service on port $Port"
& ssh -o BatchMode=yes $Server "bash install.sh $Port"
if ($LASTEXITCODE -ne 0) { throw "install failed with code $LASTEXITCODE" }
& ssh -o BatchMode=yes $Server "journalctl -u eidolarch -n 3 --no-pager -o cat"
