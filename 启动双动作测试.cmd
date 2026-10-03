@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_godot.ps1" -Scene "res://app/action_build_slice.tscn"
if errorlevel 1 pause
