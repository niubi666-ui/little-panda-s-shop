@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_godot.ps1" -Scene "res://presentation/environment_wind_v001/breeze_preview.tscn" -Resolution "1280x800"
if errorlevel 1 pause
