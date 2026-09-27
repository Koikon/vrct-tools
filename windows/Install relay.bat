@echo off
rem Double-click to install (or update) vrct-relay. Bypass only affects this one script run.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-relay.ps1" %*
pause
