@echo off
rem Double-click for the VRCT tune menu. Bypass only affects this one script run.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0vrct-tune.ps1" %*
