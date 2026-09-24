# Restart local runner workers so each re-launches through launch.ps1 (and so
# picks up a newer release). Workers default to those with a start-worker<N>.bat.
param([int[]]$Workers = @())
$root = Join-Path $HOME 'Desktop\walker-runner'
if ($Workers.Count -eq 0) {
    $Workers = Get-ChildItem $root -Filter 'start-worker*.bat' | ForEach-Object { [int]($_.BaseName -replace '\D', '') } | Sort-Object
}
$pattern = ($Workers | ForEach-Object { "config\.worker$_\.json|state[\\/]worker$_\b|127\.0\.0\.1:90{0:D2}" -f $_ }) -join '|'
Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -match $pattern } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep 3
foreach ($n in $Workers) { Start-Process (Join-Path $root "start-worker$n.bat"); Start-Sleep 20 }
"restarted: $($Workers -join ', ')"
