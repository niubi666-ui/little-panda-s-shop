param(
    [string]$Scene = '',
    [string]$Resolution = '',
    [switch]$Editor,
    [switch]$ValidateOnly
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$gameRoot = Join-Path $projectRoot 'game'
$candidates = @()
if ($env:GODOT_BIN) { $candidates += $env:GODOT_BIN }
$localConfig = Join-Path $PSScriptRoot 'local_config.json'
if (Test-Path -LiteralPath $localConfig) {
    $config = Get-Content -LiteralPath $localConfig -Raw | ConvertFrom-Json
    if ($config.godot_executable) { $candidates += $config.godot_executable }
}
foreach ($name in @('godot', 'godot4')) {
    $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
    if ($command) { $candidates += $command.Source }
}
# Preserve the existing workstation without requiring its path on other machines.
$candidates += 'E:\GoDot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64.exe'
$engine = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $engine) {
    Write-Host 'Godot not found. Set GODOT_BIN or copy tools/local_config.example.json to tools/local_config.json and set godot_executable.'
    exit 1
}
if ($Scene -and (-not $Scene.StartsWith('res://') -or -not (Test-Path -LiteralPath (Join-Path $gameRoot $Scene.Substring(6))))) {
    throw "Scene not found: $Scene"
}
if ($ValidateOnly) {
    @{engine=$engine;project=$gameRoot;scene=$Scene;editor=[bool]$Editor} | ConvertTo-Json -Compress
    exit 0
}
$engineArguments = @('--path', $gameRoot)
if ($Editor) { $engineArguments += '--editor' }
if ($Resolution) { $engineArguments += @('--resolution', $Resolution) }
if ($Scene) { $engineArguments += $Scene }
& $engine @engineArguments
exit $LASTEXITCODE
