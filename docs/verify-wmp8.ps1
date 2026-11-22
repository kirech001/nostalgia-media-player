# Local, dependency-free verification helpers. Dot-source from PowerShell.
# CDP is exposed only by the explicitly opted-in local verification process.
$ErrorActionPreference = 'Stop'
$script:CdpId = 0
$script:CdpEvents = [System.Collections.Generic.List[object]]::new()

function Connect-Player {
    $targets = Invoke-RestMethod 'http://127.0.0.1:9222/json'
    $target = $targets | Where-Object { $_.url -eq 'http://wmp.localhost/' } | Select-Object -First 1
    if (!$target) { throw 'No player target at the opted-in local CDP endpoint.' }
    $script:Cdp = [System.Net.WebSockets.ClientWebSocket]::new()
    $null = $script:Cdp.ConnectAsync([Uri]$target.webSocketDebuggerUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    $null = Send-Cdp 'Runtime.enable' @{}
    $null = Send-Cdp 'Log.enable' @{}
    $null = Send-Cdp 'Page.enable' @{}
}

function Disconnect-Player {
    if ($script:Cdp) { $script:Cdp.Dispose(); $script:Cdp = $null }
}

function Send-Cdp([string]$Method, [hashtable]$Params = @{}) {
    $script:CdpId++
    $id = $script:CdpId
    $json = @{ id = $id; method = $Method; params = $Params } | ConvertTo-Json -Compress -Depth 30
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $cts = [Threading.CancellationTokenSource]::new(20000)
    try {
        $null = $script:Cdp.SendAsync([ArraySegment[byte]]::new($bytes), [Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).GetAwaiter().GetResult()
        while ($true) {
            $stream = [IO.MemoryStream]::new()
            try {
                do {
                    $buffer = New-Object byte[] 65536
                    $part = $script:Cdp.ReceiveAsync([ArraySegment[byte]]::new($buffer), $cts.Token).GetAwaiter().GetResult()
                    $stream.Write($buffer, 0, $part.Count)
                } while (!$part.EndOfMessage)
                $message = [Text.Encoding]::UTF8.GetString($stream.ToArray()) | ConvertFrom-Json
            } finally { $stream.Dispose() }
            if ($message.id -eq $id) {
                if ($message.error) { throw ($message.error | ConvertTo-Json -Compress) }
                return $message.result
            }
            if ($message.method) { $script:CdpEvents.Add($message) }
        }
    } finally { $cts.Dispose() }
}

function Eval-Player([string]$Expression) {
    $result = Send-Cdp 'Runtime.evaluate' @{ expression = $Expression; returnByValue = $true; awaitPromise = $true; userGesture = $true }
    if ($result.exceptionDetails) { throw ($result.exceptionDetails | ConvertTo-Json -Depth 15 -Compress) }
    return $result.result.value
}

function Wait-Player([string]$Condition) {
    # Wait on animation frames and a bounded deadline, not arbitrary sleeps.
    $expr = "new Promise((resolve,reject)=>{const end=performance.now()+12000;function check(){if($Condition)resolve(true);else if(performance.now()>end)reject(new Error('Condition timed out'));else requestAnimationFrame(check)}check()})"
    $null = Eval-Player $expr
}

function Shot-Player([string]$Path) {
    $null = Send-Cdp 'Page.bringToFront' @{}
    $null = Eval-Player 'new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))'
    $image = Send-Cdp 'Page.captureScreenshot' @{ format = 'png'; fromSurface = $true; captureBeyondViewport = $false }
    [IO.File]::WriteAllBytes([IO.Path]::GetFullPath($Path), [Convert]::FromBase64String($image.data))
    return [IO.Path]::GetFullPath($Path)
}

function Click-Player([string]$Selector, [string]$Button = 'left') {
    $s = $Selector | ConvertTo-Json -Compress
    $point = Eval-Player "(()=>{const e=document.querySelector($s);if(!e)throw new Error('Missing click target');const r=e.getBoundingClientRect();return {x:r.x+r.width/2,y:r.y+r.height/2}})()"
    $null = Send-Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseMoved'; x = $point.x; y = $point.y }
    $null = Send-Cdp 'Input.dispatchMouseEvent' @{ type = 'mousePressed'; x = $point.x; y = $point.y; button = $Button; clickCount = 1 }
    $null = Send-Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseReleased'; x = $point.x; y = $point.y; button = $Button; clickCount = 1 }
    if ($Selector -notin '#btn-min', '#btn-close' -and $Selector -notmatch 'data-action.*exit') {
        $null = Eval-Player 'new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))'
    }
}

function Key-Player([string]$Key, [string]$Code, [int]$VirtualKey, [int]$Modifiers = 0) {
    $null = Send-Cdp 'Input.dispatchKeyEvent' @{ type = 'keyDown'; key = $Key; code = $Code; windowsVirtualKeyCode = $VirtualKey; modifiers = $Modifiers }
    $null = Send-Cdp 'Input.dispatchKeyEvent' @{ type = 'keyUp'; key = $Key; code = $Code; windowsVirtualKeyCode = $VirtualKey; modifiers = $Modifiers }
    $null = Eval-Player 'new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))'
}

function Files-Player([string]$Selector, [string[]]$Files) {
    $root = Send-Cdp 'DOM.getDocument' @{}
    $node = Send-Cdp 'DOM.querySelector' @{ nodeId = $root.root.nodeId; selector = $Selector }
    if (!$node.nodeId) { throw "Missing file input: $Selector" }
    $paths = @($Files | ForEach-Object { [IO.Path]::GetFullPath($_) })
    $null = Send-Cdp 'DOM.setFileInputFiles' @{ nodeId = $node.nodeId; files = $paths }
}

function Drag-Player([string]$Selector, [double]$From, [double]$To) {
    $s = $Selector | ConvertTo-Json -Compress
    $rect = Eval-Player "(()=>{const r=document.querySelector($s).getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height}})()"
    $y = $rect.y + $rect.height/2
    $null = Send-Cdp 'Input.dispatchMouseEvent' @{ type = 'mousePressed'; x = $rect.x + $rect.width*$From; y = $y; button = 'left'; clickCount = 1 }
    for ($i=1; $i -le 8; $i++) {
        $x = $rect.x + $rect.width*($From + ($To-$From)*$i/8)
        $null = Send-Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseMoved'; x = $x; y = $y; buttons = 1; button = 'left' }
    }
    $null = Send-Cdp 'Input.dispatchMouseEvent' @{ type = 'mouseReleased'; x = $rect.x + $rect.width*$To; y = $y; button = 'left'; clickCount = 1 }
    $null = Eval-Player 'new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))'
}

function Layout-Player {
    Eval-Player @'
(() => {
  const r = s => { const x=document.querySelector(s).getBoundingClientRect();return {x:x.x,y:x.y,w:x.width,h:x.height}; };
  return {
    viewport: `${innerWidth}x${innerHeight}`, overflow: document.documentElement.scrollWidth > innerWidth,
    shell: r('.shell'), pane:r('.playlist-pane'), stage:r('.stage'), console:r('.console'), status:r('.statusbar'),
    listOverflow: document.getElementById('pl-list').scrollWidth > document.getElementById('pl-list').clientWidth,
    rows:[...document.querySelectorAll('.pl-item')].map(e => ({text:e.textContent,columns:getComputedStyle(e).gridTemplateColumns,width:e.getBoundingClientRect().width})),
    headerColumns:getComputedStyle(document.querySelector('.pl-cols')).gridTemplateColumns,
    media:{width:document.getElementById('media').videoWidth,height:document.getElementById('media').videoHeight,fit:getComputedStyle(document.getElementById('media')).objectFit},
    openMenu:document.querySelector('.menu.open')?.dataset.menu || null,
    about:!document.getElementById('about').classList.contains('hidden'),focus:document.activeElement.className,
  };
})()
'@
}

if (!('PlayerWindow' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class PlayerWindow {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left,Top,Right,Bottom; }
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int w, int ht, uint flags);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsZoomed(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);
    [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(System.Drawing.Point p);
    [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
'@ -ReferencedAssemblies System.Drawing
}

function Get-PlayerWindow {
    $p = Get-Process 'kirech-media-player' | Where-Object MainWindowHandle | Select-Object -First 1
    if (!$p) { throw 'Player is not running.' }
    return $p.MainWindowHandle
}

function Resize-Player([int]$Width, [int]$Height) {
    $h = Get-PlayerWindow
    $null = [PlayerWindow]::ShowWindow($h, 9)
    $outer = New-Object PlayerWindow+RECT
    $inner = New-Object PlayerWindow+RECT
    $null = [PlayerWindow]::GetWindowRect($h, [ref]$outer)
    $null = [PlayerWindow]::GetClientRect($h, [ref]$inner)
    $null = [PlayerWindow]::SetWindowPos($h, [IntPtr]::Zero, 20, 20, $Width + ($outer.Right-$outer.Left)-$inner.Right, $Height + ($outer.Bottom-$outer.Top)-$inner.Bottom, 0x0040)
}

function Native-ShotPlayer([string]$Path) {
    Add-Type -AssemblyName System.Drawing
    $h = Get-PlayerWindow
    $null = [PlayerWindow]::ShowWindow($h, 9)
    $r = New-Object PlayerWindow+RECT
    $null = [PlayerWindow]::GetWindowRect($h, [ref]$r)
    $null = [PlayerWindow]::SetWindowPos($h, [IntPtr](-1), $r.Left, $r.Top, $r.Right-$r.Left, $r.Bottom-$r.Top, 0x0040)
    $null = [PlayerWindow]::SetForegroundWindow($h)
    $null = Eval-Player 'new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))'
    $bmp = New-Object Drawing.Bitmap ($r.Right-$r.Left), ($r.Bottom-$r.Top)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $dc = $g.GetHdc()
    try {
        if (![PlayerWindow]::PrintWindow($h, $dc, 2)) { throw 'PrintWindow failed.' }
    } finally { $g.ReleaseHdc($dc) }
    try { $bmp.Save([IO.Path]::GetFullPath($Path), [Drawing.Imaging.ImageFormat]::Png) }
    finally { $g.Dispose(); $bmp.Dispose() }
    $null = [PlayerWindow]::SetWindowPos($h, [IntPtr](-2), 0, 0, 0, 0, 0x0013)
}
