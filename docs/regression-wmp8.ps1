. "$PSScriptRoot\verify-wmp8.ps1"
$script:Results = [System.Collections.Generic.List[object]]::new()
function Record([string]$Name, [bool]$Pass, $Evidence) {
    $result = [pscustomobject]@{name=$Name;pass=$Pass;evidence=$Evidence}
    $script:Results.Add($result)
    $result | ConvertTo-Json -Depth 10 -Compress | Write-Output
}
function Check([string]$Name, [string]$Expression) {
    $value = Eval-Player $Expression
    Record $Name ([bool]$value.pass) $value
}
function Clear-Player {
    Click-Player '[data-menu="file"] .menu-label'
    Click-Player '#menu-file [data-action="clear"]'
    Wait-Player 'document.querySelectorAll(".pl-item").length===0'
}
function Pause-Player {
    if (!(Eval-Player 'document.getElementById("media").paused')) { Click-Player '#btn-play' }
    Wait-Player 'document.getElementById("media").paused && document.getElementById("status-text").textContent==="Paused"'
}
function Chooser-Player([string]$Name, [string]$Trigger, [string]$Selector, [string[]]$Paths, [int]$Expected) {
    $null = Send-Cdp 'Page.setInterceptFileChooserDialog' @{enabled=$true}
    $script:CdpEvents.Clear()
    Click-Player $Trigger
    $null = Eval-Player 'true'
    $chooser = @($script:CdpEvents | Where-Object method -eq 'Page.fileChooserOpened')
    Record "$Name opens file chooser" ($chooser.Count -eq 1) @($chooser | ForEach-Object params)
    Files-Player $Selector $Paths
    Wait-Player "document.querySelectorAll('.pl-item').length===$Expected && document.getElementById('media').readyState>=2"
    Record "$Name imports playable media" $true (Eval-Player '({count:document.querySelectorAll(".pl-item").length,src:document.getElementById("media").currentSrc,ready:document.getElementById("media").readyState})')
    $null = Send-Cdp 'Page.setInterceptFileChooserDialog' @{enabled=$false}
}

Connect-Player
try {
    $null = Send-Cdp 'Profiler.enable' @{}
    $null = Send-Cdp 'Profiler.startPreciseCoverage' @{callCount=$true;detailed=$true;allowTriggeredUpdates=$false}
    Resize-Player 1000 690
    Wait-Player 'innerWidth===1000 && innerHeight===690'
    $null = Eval-Player 'window.__regressionErrors=[];addEventListener("error",e=>__regressionErrors.push(e.message));addEventListener("unhandledrejection",e=>__regressionErrors.push(String(e.reason)))'
    # Begin on an empty, real app; no private functions/state are exported or called.
    Clear-Player
    $null = Eval-Player 'document.getElementById("media").loop=false'
    Check 'Empty UI + transport' '({pass:!document.getElementById("pl-empty").classList.contains("hidden") && document.getElementById("total-time").textContent==="0:00" && document.getElementById("btn-prev").disabled && document.getElementById("btn-next").disabled,status:document.getElementById("status-text").textContent})'

    $tracks = @(Get-ChildItem "$PSScriptRoot\testmedia\0*.wav" | ForEach-Object FullName)
    Click-Player '[data-menu="file"] .menu-label'
    Chooser-Player 'File > Add Files' '#menu-file [data-action="add-files"]' '#file-input' $tracks 4
    Wait-Player 'document.getElementById("total-time").textContent==="2:48"'
    Check 'Metadata totals and extension' '({pass:document.getElementById("total-time").textContent==="2:48" && document.getElementById("status-ext").textContent==="WAV" && !document.getElementById("btn-next").disabled,total:document.getElementById("total-time").textContent})'
    Pause-Player
    Clear-Player
    Chooser-Player 'Playlist +' '#btn-pl-add' '#file-input' @($tracks[0]) 1
    Pause-Player
    Clear-Player

    Click-Player '[data-menu="file"] .menu-label'
    Chooser-Player 'File > Add Folder' '#menu-file [data-action="add-folder"]' '#dir-input' @("$PSScriptRoot\testmedia") 6
    Pause-Player
    Check 'Folder import includes child filenames' '({pass:document.querySelectorAll(".pl-item").length===6,count:document.querySelectorAll(".pl-item").length,total:document.getElementById("total-time").textContent})'
    Clear-Player

    $script:CdpEvents.Clear()
    $drop = @{items=@();files=$tracks;dragOperationsMask=1}
    $null = Send-Cdp 'Input.dispatchDragEvent' @{type='dragEnter';x=600;y=250;data=$drop}
    Check 'Drag hover feedback' '({pass:document.getElementById("stage").classList.contains("dragging")})'
    $null = Send-Cdp 'Input.dispatchDragEvent' @{type='dragOver';x=600;y=250;data=$drop}
    $null = Send-Cdp 'Input.dispatchDragEvent' @{type='drop';x=600;y=250;data=$drop}
    Wait-Player 'document.querySelectorAll(".pl-item").length===4 && document.getElementById("media").readyState>=2'
    Check 'Drop imports and clears hint' '({pass:document.querySelectorAll(".pl-item").length===4 && !document.getElementById("stage").classList.contains("dragging")})'
    Pause-Player

    Click-Player '.pl-item[data-index="2"]'
    Wait-Player 'document.querySelector(".pl-item.active").dataset.index==="2" && !document.getElementById("media").paused && document.getElementById("status-text").textContent==="Playing"'
    Check 'Row plays + active playmark' '({pass:document.querySelector(".pl-item.active").dataset.index==="2" && document.querySelectorAll(".pl-playmark").length===1 && document.getElementById("status-text").textContent==="Playing",title:document.getElementById("track-title").textContent})'
    Pause-Player
    Check 'Play button pauses' '({pass:document.getElementById("media").paused && document.getElementById("status-text").textContent==="Paused"})'
    Key-Player ' ' 'Space' 32
    Wait-Player '!document.getElementById("media").paused'
    Key-Player ' ' 'Space' 32
    Wait-Player 'document.getElementById("media").paused && document.getElementById("status-text").textContent==="Paused"'
    Record 'Space toggles play/pause once each' $true (Eval-Player 'document.getElementById("status-text").textContent')

    Click-Player '#btn-next'
    Wait-Player 'document.querySelector(".pl-item.active").dataset.index==="3"'
    Click-Player '#btn-prev'
    Wait-Player 'document.querySelector(".pl-item.active").dataset.index==="2"'
    Key-Player 'n' 'KeyN' 78
    Wait-Player 'document.querySelector(".pl-item.active").dataset.index==="3"'
    Key-Player 'p' 'KeyP' 80
    Wait-Player 'document.querySelector(".pl-item.active").dataset.index==="2"'
    Record 'Next/previous buttons and N/P' $true (Eval-Player 'document.querySelector(".pl-item.active").dataset.index')
    Pause-Player
    Drag-Player '#seekbar' .20 .70
    Wait-Player '!document.getElementById("media").seeking && Math.abs(document.getElementById("media").currentTime-30.8)<1'
    Check 'Seek drag forward' '({pass:Math.abs(document.getElementById("media").currentTime-30.8)<1,time:document.getElementById("media").currentTime,label:document.getElementById("time-cur").textContent})'
    Drag-Player '#seekbar' .70 .25
    Wait-Player '!document.getElementById("media").seeking && Math.abs(document.getElementById("media").currentTime-11)<1'
    Check 'Seek drag backward + labels' '({pass:Math.abs(document.getElementById("media").currentTime-11)<1 && document.getElementById("time-cur").textContent==="0:11",time:document.getElementById("media").currentTime,label:document.getElementById("time-cur").textContent})'
    Click-Player '#seekbar'
    Check 'Seek click midpoint' '({pass:Math.abs(document.getElementById("media").currentTime-22)<1,time:document.getElementById("media").currentTime})'
    Key-Player 'ArrowRight' 'ArrowRight' 39
    Check 'Right key +5 seconds' '({pass:Math.abs(document.getElementById("media").currentTime-27)<1,time:document.getElementById("media").currentTime})'
    Key-Player 'ArrowLeft' 'ArrowLeft' 37
    Check 'Left key -5 seconds' '({pass:Math.abs(document.getElementById("media").currentTime-22)<1,time:document.getElementById("media").currentTime})'
    Click-Player '#btn-prev'
    Wait-Player 'document.getElementById("media").currentTime<1'
    Check 'Previous restarts after 3 seconds' '({pass:document.querySelector(".pl-item.active").dataset.index==="2" && document.getElementById("media").currentTime<1})'

    Drag-Player '#volbar' .8 .3
    Check 'Volume drag' '({pass:Math.abs(document.getElementById("media").volume-.3)<.01,volume:document.getElementById("media").volume})'
    Click-Player '#btn-mute'
    Check 'Mute button' '({pass:document.getElementById("media").muted && !document.querySelector(".spk-x").classList.contains("hidden")})'
    Click-Player '#btn-mute'
    $null = Send-Cdp 'Input.dispatchMouseEvent' @{type='mouseWheel';x=600;y=300;deltaX=0;deltaY=-100}
    Wait-Player 'document.getElementById("media").volume>.34'
    Check 'Wheel volume and unmute' '({pass:Math.abs(document.getElementById("media").volume-.35)<.01 && !document.getElementById("media").muted,volume:document.getElementById("media").volume})'
    Key-Player 'ArrowUp' 'ArrowUp' 38
    Key-Player 'ArrowDown' 'ArrowDown' 40
    Check 'Up/down volume keys' '({pass:Math.abs(document.getElementById("media").volume-.35)<.01,volume:document.getElementById("media").volume})'
    Check 'Wall clock matches local time' '(()=>{const d=new Date();const expected=String(d.getHours()).padStart(2,"0")+":"+String(d.getMinutes()).padStart(2,"0");return {pass:document.getElementById("clock").textContent===expected,expected,actual:document.getElementById("clock").textContent}})()'

    Click-Player '[data-menu="view"] .menu-label'
    Click-Player '[data-action="viz-bars"]'
    Click-Player '#viz-next'
    Check 'Viz chip Waves' '({pass:document.getElementById("viz-name").textContent==="Waves"})'
    $null = Shot-Player "$PSScriptRoot\shots\E-viz-waves.png"
    Click-Player '#viz-next'
    Check 'Viz chip Ambience' '({pass:document.getElementById("viz-name").textContent==="Ambience"})'
    $null = Shot-Player "$PSScriptRoot\shots\E-viz-ambience.png"
    Click-Player '#viz-prev'
    Check 'Viz chip previous' '({pass:document.getElementById("viz-name").textContent==="Waves"})'
    foreach ($mode in @('bars','waves','ambience')) {
        Click-Player '[data-menu="view"] .menu-label'
        Click-Player "[data-action='viz-$mode']"
        Check "View visualization $mode" "({pass:document.getElementById('viz-name').textContent.toLowerCase()==='$mode'})"
    }
    Click-Player '[data-menu="view"] .menu-label'
    Click-Player '[data-action="theater"]'
    Wait-Player 'document.getElementById("app").classList.contains("theater") && innerWidth===screen.width && innerHeight===screen.height'
    Check 'View Full Screen hides menu/list' '({pass:getComputedStyle(document.getElementById("menubar")).display==="none" && getComputedStyle(document.getElementById("playlist-pane")).display==="none",width:innerWidth,height:innerHeight})'
    Key-Player 'F11' 'F11' 122
    Wait-Player '!document.getElementById("app").classList.contains("theater") && innerWidth===1000 && innerHeight===690'
    Key-Player 'F11' 'F11' 122
    Wait-Player 'document.getElementById("app").classList.contains("theater") && innerWidth===screen.width && innerHeight===screen.height'
    Key-Player 'Escape' 'Escape' 27
    Wait-Player '!document.getElementById("app").classList.contains("theater") && innerWidth===1000 && innerHeight===690'
    Record 'F11 toggle and Escape exit' $true (Eval-Player '({width:innerWidth,height:innerHeight})')

    Click-Player '[data-menu="help"] .menu-label'
    Click-Player '[data-action="about"]'
    Check 'About focuses OK and makes background inert' '({pass:document.activeElement.matches(".xp-button") && document.getElementById("shell").inert})'
    Key-Player 'Tab' 'Tab' 9
    Check 'About Tab wraps to close' '({pass:document.activeElement.matches(".dialog-x")})'
    Key-Player 'Tab' 'Tab' 9 8
    Check 'About Shift+Tab wraps to OK' '({pass:document.activeElement.matches(".xp-button")})'
    Key-Player 'Escape' 'Escape' 27
    Check 'About Escape returns Help focus' '({pass:document.getElementById("about").classList.contains("hidden") && !document.getElementById("shell").inert && document.activeElement.closest(".menu").dataset.menu==="help"})'
    Key-Player 'Enter' 'Enter' 13
    Check 'Keyboard opens Help + focuses item' '({pass:document.querySelector(".menu.open").dataset.menu==="help" && document.activeElement.matches("#menu-help button")})'
    Key-Player 'ArrowLeft' 'ArrowLeft' 37
    Check 'Keyboard traverses menus' '({pass:document.querySelector(".menu.open").dataset.menu==="tools"})'
    Key-Player 'Escape' 'Escape' 27
    Check 'Menu Escape closes + restores label focus' '({pass:!document.querySelector(".menu.open") && document.activeElement.matches("[data-menu=tools] .menu-label")})'
    Click-Player '[data-menu="file"] .menu-label'
    Click-Player '.track-title'
    Check 'Outside mousedown closes menu' '({pass:!document.querySelector(".menu.open")})'
    Click-Player '[data-menu="help"] .menu-label'
    Click-Player '[data-action="about"]'
    Click-Player '#about .xp-button'
    Check 'About OK closes' '({pass:document.getElementById("about").classList.contains("hidden")})'

    Click-Player '#btn-stop'
    Wait-Player 'document.getElementById("media").paused && !document.getElementById("media").getAttribute("src")'
    Check 'Stop removes source' '({pass:document.getElementById("status-text").textContent==="Stopped" && document.getElementById("media").paused})'
    Click-Player '#btn-play'
    # A bounded observation, not a production-code repair. The original togglePlay()
    # checks currentSrc even after stopPlayback() removes src; WebView2 retains it.
    $restarted = Eval-Player 'new Promise(resolve=>{const end=performance.now()+2500;function check(){const m=document.getElementById("media");if(!m.paused&&m.readyState>=2)resolve(true);else if(performance.now()>end)resolve(false);else requestAnimationFrame(check)}check()})'
    Record 'Play restarts after Stop' ([bool]$restarted) (Eval-Player '({status:document.getElementById("status-text").textContent,srcAttribute:document.getElementById("media").getAttribute("src"),currentSrc:document.getElementById("media").currentSrc,readyState:document.getElementById("media").readyState,paused:document.getElementById("media").paused})')
    if (!$restarted) {
        $null = Shot-Player "$PSScriptRoot\shots\E-stop-replay-known-failure.png"
        Click-Player '.pl-item[data-index="2"]'
        Wait-Player '!document.getElementById("media").paused && document.getElementById("media").readyState>=2'
    }
    Pause-Player
    Click-Player '.pl-item[data-index="3"]' 'right'
    Wait-Player 'document.querySelectorAll(".pl-item").length===3'
    Check 'Right-click removal + totals' '({pass:document.getElementById("total-time").textContent==="2:00",total:document.getElementById("total-time").textContent})'
    Click-Player '#btn-pl-clear'
    Check 'Playlist clear button + empty state' '({pass:document.querySelectorAll(".pl-item").length===0 && document.getElementById("total-time").textContent==="0:00" && !document.getElementById("pl-empty").classList.contains("hidden") && document.getElementById("btn-next").disabled})'
    Files-Player '#file-input' @("$PSScriptRoot\testmedia\Invalid media.wav")
    Wait-Player 'document.getElementById("status-text").textContent==="Cannot play this file"'
    Check 'Invalid media error status' '({pass:document.getElementById("status-text").textContent==="Cannot play this file",status:document.getElementById("status-text").textContent})'
    $null = Shot-Player "$PSScriptRoot\shots\E-invalid-media.png"
    Clear-Player
    Check 'Recover from error with clear' '({pass:document.getElementById("status-text").textContent==="Ready" && document.querySelectorAll(".pl-item").length===0})'
    Check 'No JS errors during regression' '({pass:__regressionErrors.length===0,errors:__regressionErrors})'
    $coverage = Send-Cdp 'Profiler.takePreciseCoverage' @{}
    $coverage | ConvertTo-Json -Depth 40 | Set-Content "$PSScriptRoot\shots\E-v8-coverage.json"
    $null = Send-Cdp 'Profiler.stopPreciseCoverage' @{}
    $script:CdpEvents | Where-Object method -eq 'Runtime.exceptionThrown' | ConvertTo-Json -Depth 20 | Set-Content "$PSScriptRoot\shots\E-runtime-exceptions.json"
    $null = Shot-Player "$PSScriptRoot\shots\E-final-empty.png"
} catch {
    Record 'Harness exception' $false $_.Exception.Message
    throw
} finally {
    $script:Results | ConvertTo-Json -Depth 25 | Set-Content "$PSScriptRoot\shots\E-regression-results.json"
    Disconnect-Player
}
