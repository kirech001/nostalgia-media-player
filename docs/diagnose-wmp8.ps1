. "$PSScriptRoot\verify-wmp8.ps1"
Connect-Player
try {
    Eval-Player '({width:innerWidth,height:innerHeight,app:document.getElementById("app").className,media:{paused:document.getElementById("media").paused,src:document.getElementById("media").currentSrc,attr:document.getElementById("media").getAttribute("src"),ready:document.getElementById("media").readyState,time:document.getElementById("media").currentTime,error:document.getElementById("media").error?.message},status:document.getElementById("status-text").textContent,rows:document.querySelectorAll(".pl-item").length,focus:document.activeElement.outerHTML})' | ConvertTo-Json -Depth 6
    Resize-Player 1000 690
    Wait-Player 'innerWidth===1000 && innerHeight===690'
    $null = Eval-Player 'window.__pointerTrace=[];["pointerdown","pointermove","pointerup","gotpointercapture","lostpointercapture"].forEach(type=>document.getElementById("seekbar").addEventListener(type,e=>__pointerTrace.push({type:e.type,x:e.clientX,buttons:e.buttons,capture:e.target.hasPointerCapture(e.pointerId),time:document.getElementById("media").currentTime}),true))'
    Click-Player '.pl-item[data-index="1"]'
    Wait-Player '!document.getElementById("media").paused && document.getElementById("media").readyState===4'
    Click-Player '#btn-play'
    Wait-Player 'document.getElementById("media").paused && document.getElementById("status-text").textContent==="Paused"'
    Drag-Player '#seekbar' .2 .7
    Wait-Player '!document.getElementById("media").seeking'
    Eval-Player '({trace:__pointerTrace,paused:document.getElementById("media").paused,time:document.getElementById("media").currentTime,label:document.getElementById("time-cur").textContent,rect:JSON.stringify(document.getElementById("seekbar").getBoundingClientRect())})' | ConvertTo-Json -Depth 10
    $null = Shot-Player "$PSScriptRoot\shots\E-diagnostic-seek.png"
    Click-Player '#btn-stop'
    Wait-Player 'document.getElementById("media").currentSrc==="" && document.getElementById("media").paused'
    Eval-Player '({src:document.getElementById("media").currentSrc,status:document.getElementById("status-text").textContent,focus:document.activeElement.id})' | ConvertTo-Json
    Click-Player '#btn-play'
    Wait-Player '!document.getElementById("media").paused && document.getElementById("media").readyState>=2'
    Eval-Player '({src:document.getElementById("media").currentSrc,status:document.getElementById("status-text").textContent,paused:document.getElementById("media").paused})' | ConvertTo-Json
} finally { Disconnect-Player }
