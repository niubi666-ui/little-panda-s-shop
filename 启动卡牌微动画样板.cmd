@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch_godot.ps1" -Scene "res://ui_lab/card_art_motion/card_art_motion_lab.tscn" -Resolution "1280x800"
if errorlevel 1 pause
