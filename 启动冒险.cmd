@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_godot.ps1" -Scene "res://app/forest_run.tscn"
if errorlevel 1 pause
