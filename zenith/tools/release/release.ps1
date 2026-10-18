# Ships a release in one go, so the duel server and the itch.io builds never drift apart: an old
# client is refused by a new server (protocol, catalog, certificate), and a new client by an old one.
#   powershell -File G:/Godot/Gamestorming/zenith/tools/release/release.ps1
# -Target names the itch page (user/game); it defaults to the game's page, cursehound/eidolarch.
# Order: run the suites, export both clients (nothing live is touched yet), deploy the server, export
# the clients again if the server's certificate changed (they pin it), then push both to itch with
# butler. The gap between the server restart and the itch push is only the upload.
# -SkipTests skips the suites; -SkipItch deploys and exports but pushes nothing (then push by hand).
# Commit and push web-prebuilt/zenith afterwards for the Pages copy of the web build.
param(
    [string]$Target = "cursehound/eidolarch",
    [switch]$SkipTests,
    [switch]$SkipItch,
    [string]$Godot = "G:\Godot\Godot_v4.6.2-stable_mono_win64\Godot_v4.6.2-stable_mono_win64_console.exe",
    [string]$GodotExport = "G:\Godot\Godot_v4.6.2-stable_win64_GDSCRIPTONLY.exe",
    [string]$Butler = "G:\Program Files (x86)\itchiobutler\butler.exe"
)
$ErrorActionPreference = "Stop"
$zenith = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$repo = Resolve-Path (Join-Path $zenith "..")
$windowsDir = Join-Path $zenith "build\windows"
$webDir = Join-Path $repo "web-prebuilt\zenith"
$cert = Join-Path $zenith "data\net\duel_server.crt"
$suites = @("run_tests", "tutorial_tests", "ui_cleanup_tests", "title_ui_tests", "combat_presentation_tests", "ui_redesign_smoke", "network_regression_tests")

if (-not $SkipItch) {
    if ($Target -notmatch "^[^/\s]+/[^/\s]+$") { throw "pass -Target <itch user>/<game>, for example -Target someone/eidolarch" }
    if (-not (Test-Path $Butler)) { throw "no butler at $Butler" }
    # A wrong page or a lapsed login is found here, before the server is touched.
    & $Butler status $Target 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "butler cannot reach $Target; check the page name, or run '$Butler login'" }
}
$version = (Select-String -Path (Join-Path $zenith "project.godot") -Pattern '^config/version="(.+)"').Matches[0].Groups[1].Value
Write-Host "releasing $version"

if (-not $SkipTests) {
    foreach ($suite in $suites) {
        $out = & $Godot --headless --path $zenith -s "tests/$suite.gd" 2>&1 | Out-String
        $summary = ($out -split "`n" | Select-String -Pattern "(\d+) failures?" | Select-Object -Last 1)
        if ($null -eq $summary -or $summary.Matches[0].Groups[1].Value -ne "0") {
            throw "$suite did not pass: $summary"
        }
        Write-Host "$suite passed"
    }
}

function Export-Clients {
    Write-Host "exporting the Windows client"
    $p = Start-Process -FilePath $GodotExport -ArgumentList @("--headless", "--path", "`"$zenith`"", "--export-release", "`"Windows Desktop`"", "`"$windowsDir\eidolarch.exe`"") -Wait -NoNewWindow -PassThru -RedirectStandardOutput (Join-Path $env:TEMP "eidolarch_windows_export.log")
    if ($p.ExitCode -ne 0) { throw "Windows export failed with code $($p.ExitCode)" }
    Write-Host "exporting the web build"
    & powershell -File (Join-Path $zenith "tools\web\export_web.ps1") -Godot $GodotExport | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "web export failed with code $LASTEXITCODE" }
}

Export-Clients
$certBefore = (Get-FileHash $cert).Hash
& powershell -File (Join-Path $zenith "tools\server\deploy.ps1") -FromRelease -Godot $GodotExport
if ($LASTEXITCODE -ne 0) { throw "the server deploy failed; the itch builds were not pushed" }
if ((Get-FileHash $cert).Hash -ne $certBefore) {
    Write-Host "the server has a new certificate, so the clients go out again pinned to it"
    Export-Clients
}

if ($SkipItch) {
    Write-Host "server deployed and clients exported; push to itch by hand before players update"
    exit 0
}
Write-Host "pushing to itch: $Target"
& $Butler push $windowsDir "${Target}:windows" --userversion $version --ignore "*.console.exe"
if ($LASTEXITCODE -ne 0) { throw "butler push of the Windows build failed; push it by hand now, the server is already updated" }
& $Butler push $webDir "${Target}:html5" --userversion $version
if ($LASTEXITCODE -ne 0) { throw "butler push of the web build failed; push it by hand now, the server is already updated" }
Write-Host "released ${version}: server, ${Target}:windows and ${Target}:html5. Commit and push web-prebuilt/zenith for the Pages copy."
