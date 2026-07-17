@echo off
REM Lanzador de testing - menu interactivo del relevamiento de mantenimiento.
REM Uso:  fleet-mant.bat            (pide el TAG)
REM       fleet-mant.bat -Tag <nombrecorto> -Cliente "<Cliente>"
chcp 65001 >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fleet-mant.ps1" -Menu %*
pause
