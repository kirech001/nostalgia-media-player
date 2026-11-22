param(
    [string]$Name = 'A-baseline',
    [int]$Width = 1000,
    [int]$Height = 690,
    [string]$Script,
    [switch]$Native
)
. "$PSScriptRoot\verify-wmp8.ps1"
Connect-Player
try {
    Resize-Player $Width $Height
    Wait-Player "window.innerWidth === $Width && window.innerHeight === $Height"
    if ($Script) { Eval-Player ([IO.File]::ReadAllText([IO.Path]::GetFullPath($Script))) | ConvertTo-Json -Depth 20 }
    Eval-Player '({width:innerWidth,height:innerHeight,prevDisabled:document.getElementById("btn-prev").disabled,nextDisabled:document.getElementById("btn-next").disabled})' | ConvertTo-Json
    Shot-Player "$PSScriptRoot\shots\$Name.png"
    if ($Native) { Native-ShotPlayer "$PSScriptRoot\shots\$Name-native.png" }
} finally { Disconnect-Player }
