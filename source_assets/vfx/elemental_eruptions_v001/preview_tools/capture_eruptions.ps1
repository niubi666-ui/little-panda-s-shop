param(
    [ValidateSet('both', 'ice', 'rock')][string]$Skill = 'both',
    [double]$At = -1,
    [int]$Frames = 150,
    [switch]$ShowControls,
    [ValidateSet('zh_CN', 'en')][string]$Locale = 'zh_CN',
    [string]$Godot = 'E:\GoDot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe',
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) { throw "Godot executable missing: $Godot" }
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $projectRoot 'source_assets\vfx\elemental_eruptions_v001\previews'
}
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
$engineArgs = @('--path', (Join-Path $projectRoot 'game'), '--resolution', '1280x720', '--fixed-fps', '30', 'res://presentation/combat/eruption_showcase/showcase.tscn', '--', '--capture-eruptions', "--capture-root=$OutputDirectory", "--capture-frames=$Frames")
$engineArgs += "--showcase-locale=$Locale"
if ($ShowControls) { $engineArgs += '--capture-controls' }
if ($Skill -ne 'both') { $engineArgs += "--capture-skill=$Skill" }
if ($At -ge 0) { $engineArgs += "--capture-at=$At" }
& $Godot @engineArgs
if ($LASTEXITCODE -ne 0) { throw "Godot capture failed with exit code $LASTEXITCODE" }
Write-Output "Capture completed: $OutputDirectory"
