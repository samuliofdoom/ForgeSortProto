$ErrorActionPreference = "SilentlyContinue"
$projPath = "G:\AI_STUFF\Games\ForgeSortProto"
$godExe = "$projPath\GodotEngine\Godot_v4.6.2-stable_win64_console.exe"
$errFile = "$projPath\editor_errors.txt"

$proc = Start-Process -FilePath $godExe -ArgumentList "--path","$projPath","--editor","--quit-after","15" -PassThru -RedirectStandardError $errFile
Start-Sleep -Seconds 18
if (!$proc.HasExited) { Stop-Process -Id $proc.Id -Force }
Write-Host "=== EDITOR STDERR ==="
if (Test-Path $errFile) {
    Get-Content $errFile | Select-Object -First 80
} else {
    Write-Host "(no error file)"
}
Write-Host "=== DONE ==="
