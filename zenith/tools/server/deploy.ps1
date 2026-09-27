# Exports the duel server and installs it on the box in one go. Run from anywhere:
#   powershell -File zenith\tools\server\deploy.ps1            (export + upload + restart)
#   powershell -File zenith\tools\server\deploy.ps1 -SkipExport (upload the last export)
# Needs key-based SSH to root@<host> (see docs/duel_server.md) and the GDScript-only editor.
# -DataDir is where the box keeps match records, their signing key and the DTLS key and
# certificate; install.sh owns its modes. -HostName goes into the certificate the server makes on
# its first start and defaults to the address in -Server, which is what clients dial and check.
# The last step copies the box's certificate to data/net/duel_server.crt, the file clients pin.
param(
    [string]$Server = "root@198.44.38.215",
    [int]$Port = 7777,
    [string]$DataDir = "/var/lib/eidolarch",
    [string]$HostName = "",
    [string]$Godot = "G:\Godot\Godot_v4.6.2-stable_win64_GDSCRIPTONLY.exe",
    [switch]$SkipExport
)
$ErrorActionPreference = "Stop"
$zenith = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$binary = Join-Path $zenith "build\server\eidolarch_server.x86_64"
$install = Join-Path $PSScriptRoot "install.sh"
$cert = Join-Path $zenith "data\net\duel_server.crt"
if (-not $HostName) { $HostName = $Server.Split("@")[-1] }

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
Write-Host "installing and restarting eidolarch.service on port $Port for host name $HostName"
& ssh -o BatchMode=yes $Server "bash install.sh $Port $DataDir $HostName"
if ($LASTEXITCODE -ne 0) { throw "install failed with code $LASTEXITCODE" }
& ssh -o BatchMode=yes $Server "journalctl -u eidolarch -n 4 --no-pager -o cat"

$before = if (Test-Path $cert) { (Get-FileHash $cert).Hash } else { "" }
New-Item -ItemType Directory -Force (Split-Path $cert) | Out-Null
& scp -o BatchMode=yes -q "${Server}:${DataDir}/dtls.crt" $cert
if ($LASTEXITCODE -ne 0) { throw "could not copy ${DataDir}/dtls.crt from the box (code $LASTEXITCODE)" }
if ((Get-FileHash $cert).Hash -eq $before) {
    Write-Host "the server's certificate is unchanged in $cert"
} else {
    Write-Host "the server's certificate is now in $cert; export the Windows client again so it trusts this server"
}
