# Exports the Web preset with the standard (non-.NET) editor and copies it to web-prebuilt/zenith,
# which the Pages workflow publishes as-is. The art packs are gitignored, so CI cannot export zenith itself.
param(
	[string]$Godot = "G:\Godot\Godot_v4.6.2-stable_win64_GDSCRIPTONLY.exe"
)
$ErrorActionPreference = "Stop"
$zenith = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$repo = Resolve-Path (Join-Path $zenith "..")
$build = Join-Path $zenith "build\web"
$publish = Join-Path $repo "web-prebuilt\zenith"

New-Item -ItemType Directory -Force $build | Out-Null
# The GDScript-only editor is a GUI-subsystem exe, so PowerShell would not wait for it with `&`.
$export = Start-Process -FilePath $Godot -ArgumentList @("--headless", "--path", "`"$zenith`"", "--export-release", "Web", "`"$(Join-Path $build 'index.html')`"") -Wait -NoNewWindow -PassThru
if ($export.ExitCode -ne 0) { throw "Web export failed with exit code $($export.ExitCode)" }

if (Test-Path $publish) { Remove-Item -Recurse -Force $publish }
New-Item -ItemType Directory -Force $publish | Out-Null
Get-ChildItem $build -File | Where-Object { $_.Name -ne ".gdignore" } | Copy-Item -Destination $publish
Get-ChildItem $publish | Select-Object Name, Length
