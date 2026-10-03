@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_godot.ps1" -Scene "res://presentation/combat/sword_wave_showcase/showcase.tscn" -Resolution "1280x720"
if errorlevel 1 pause
