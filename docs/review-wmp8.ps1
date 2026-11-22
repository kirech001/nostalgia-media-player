. "$PSScriptRoot\verify-wmp8.ps1"
Connect-Player
try {
    $null = Send-Cdp 'Runtime.evaluate' @{ expression = 'window.__reviewErrors=[];addEventListener("error",e=>__reviewErrors.push(e.message));addEventListener("unhandledrejection",e=>__reviewErrors.push(String(e.reason)))' }
    $video = Eval-Player ([IO.File]::ReadAllText("$PSScriptRoot\make-testvideo.js"))
    [IO.File]::WriteAllBytes("$PSScriptRoot\testmedia\16x9-local-test.webm", [Convert]::FromBase64String($video))
    Resize-Player 1000 690
    Wait-Player 'innerWidth===1000 && innerHeight===690'
    $null = Shot-Player "$PSScriptRoot\shots\D1-empty-1000x690.png"
    Click-Player '[data-menu="file"] .menu-label'
    $null = Shot-Player "$PSScriptRoot\shots\D3-file-menu.png"
    Key-Player 'Escape' 'Escape' 27
    Click-Player '[data-menu="help"] .menu-label'
    $null = Shot-Player "$PSScriptRoot\shots\D3-help-menu.png"
    Click-Player '[data-action="about"]'
    Wait-Player '!document.getElementById("about").classList.contains("hidden")'
    $null = Shot-Player "$PSScriptRoot\shots\C6-about.png"
    $null = Shot-Player "$PSScriptRoot\shots\D4-about.png"
    Key-Player 'Escape' 'Escape' 27
    $tracks = @(Get-ChildItem "$PSScriptRoot\testmedia\0*.wav" | ForEach-Object FullName)
    Files-Player '#file-input' $tracks
    Wait-Player 'document.querySelectorAll(".pl-item").length===4 && document.getElementById("total-time").textContent==="2:48" && document.getElementById("media").readyState>=2'
    Click-Player '#btn-play'
    Wait-Player 'document.getElementById("media").paused'
    Click-Player '.pl-item[data-index="1"]'
    Wait-Player '!document.getElementById("media").paused && document.getElementById("media").readyState>=2'
    Click-Player '#btn-play'
    $null = Shot-Player "$PSScriptRoot\shots\D2-playlist-active.png"
    $layouts = [System.Collections.Generic.List[object]]::new()
    $layouts.Add((Layout-Player))
    Resize-Player 880 600
    Wait-Player 'innerWidth===880 && innerHeight===600'
    $null = Shot-Player "$PSScriptRoot\shots\D5-narrow-880x600.png"
    $layouts.Add((Layout-Player))
    Key-Player 'F11' 'F11' 122
    Wait-Player 'document.getElementById("app").classList.contains("theater") && innerWidth>=1000'
    $null = Shot-Player "$PSScriptRoot\shots\D6-theater.png"
    $layouts.Add((Layout-Player))
    Key-Player 'Escape' 'Escape' 27
    Wait-Player '!document.getElementById("app").classList.contains("theater")'
    Resize-Player 1000 690
    Wait-Player 'innerWidth===1000 && innerHeight===690'
    Files-Player '#file-input' @("$PSScriptRoot\testmedia\16x9-local-test.webm")
    $null = Eval-Player 'document.getElementById("media").loop=true'
    Wait-Player 'document.getElementById("media").videoWidth===320 && !document.getElementById("media").paused && document.getElementById("stage").classList.contains("has-video")'
    # Move off the video so hover metadata does not hide the test frame.
    $null = Send-Cdp 'Input.dispatchMouseEvent' @{type='mouseMoved';x=500;y=650}
    $null = Shot-Player "$PSScriptRoot\shots\D7-video-letterbox.png"
    $layouts.Add((Layout-Player))
    $null = Eval-Player 'document.getElementById("media").loop=false'
    $layouts | ConvertTo-Json -Depth 20 | Set-Content "$PSScriptRoot\shots\D-layout-evidence.json"
    Eval-Player '__reviewErrors' | ConvertTo-Json | Set-Content "$PSScriptRoot\shots\D-js-errors.json"
    $script:CdpEvents | Where-Object { $_.method -in 'Runtime.exceptionThrown','Log.entryAdded' } | ConvertTo-Json -Depth 20 | Set-Content "$PSScriptRoot\shots\D-runtime-log.json"
    Get-ChildItem "$PSScriptRoot\shots\D*.png" | Select-Object Name,Length
} finally { Disconnect-Player }
