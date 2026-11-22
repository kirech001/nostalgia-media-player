param([Parameter(Mandatory=$true)][string]$Step)
. "$PSScriptRoot\verify-wmp8.ps1"
$players = @(Get-Process 'kirech-media-player' -ErrorAction SilentlyContinue)
if ($players.Count) {
    Connect-Player
    try { Click-Player '#btn-close' }
    catch { Write-Output "Close ended the CDP connection: $($_.Exception.Message)" }
    finally { Disconnect-Player }
    foreach ($player in $players) {
        if (!$player.HasExited) { $null = $player.CloseMainWindow() }
        $player.WaitForExit(10000) | Out-Null
    }
    if (Get-Process 'kirech-media-player' -ErrorAction SilentlyContinue) { throw 'Player did not close; will not overwrite a live executable.' }
}
$ErrorActionPreference = 'Continue'
$output = & cargo build --release 2>&1
$output | ForEach-Object { $_.ToString() } | Tee-Object -FilePath "$PSScriptRoot\shots\$Step-build.txt"
$ErrorActionPreference = 'Stop'
if (($output | Out-String) -notmatch 'Finished.*release.*profile') { throw 'Release build did not report Finished release profile.' }
