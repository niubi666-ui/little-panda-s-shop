param(
    [double]$At = -1,
    [int]$Frames = 150,
    [ValidateSet('zh_CN','en')][string]$Locale = 'zh_CN',
    [switch]$ShowControls,
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
$taskProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..'))
$taskEngine = 'E:\GoDot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe'
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $taskProjectRoot 'source_assets\vfx\lightning_verdict_v001\previews\final'
}
$taskCaptureRoot = [IO.Path]::GetFullPath($OutputDirectory)
$taskEngineArgs = @('--path',(Join-Path $taskProjectRoot 'game'),'--resolution','1280x720','--position','-4000,-4000','--fixed-fps','30','res://presentation/combat/lightning_showcase/showcase.tscn','--','--capture-lightning',"--capture-root=$taskCaptureRoot","--capture-frames=$Frames","--showcase-locale=$Locale")
if ($At -ge 0) { $taskEngineArgs += "--capture-at=$At" }
if ($ShowControls) { $taskEngineArgs += '--capture-controls' }
& $taskEngine @taskEngineArgs
if ($LASTEXITCODE -ne 0) { throw "Lightning capture failed: $LASTEXITCODE" }
