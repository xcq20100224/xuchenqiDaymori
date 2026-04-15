@echo off
cd /d "%~dp0"
start "Daymori Local Server" powershell -ExecutionPolicy Bypass -NoLogo -File "%~dp0serve-daymori.ps1"