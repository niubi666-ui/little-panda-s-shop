@echo off
chcp 65001 >nul
setlocal
set "CHARGED_ARROW_ENGINE=E:\GoDot\Godot_v4.7.2-stable_win64\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%~dp0godot_demo\assets\elf.glb" (
  "C:\Users\陈旭辉\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe" "%~dp0build_demo.py"
  if errorlevel 1 exit /b 1
)
if not exist "%~dp0godot_demo\.godot\imported" (
  "%CHARGED_ARROW_ENGINE%" --headless --editor --path "%~dp0godot_demo" --quit
  if errorlevel 1 exit /b 1
)
"%CHARGED_ARROW_ENGINE%" --path "%~dp0godot_demo"
