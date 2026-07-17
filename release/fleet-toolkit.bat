@echo off
chcp 65001 >nul
title Fleet Maintenance Toolkit
setlocal enabledelayedexpansion

:menu
cls
echo ============================================================
echo              Fleet Maintenance Toolkit
echo ============================================================
echo.
echo   En este equipo:
echo     1) Relevar este equipo  (detecta terminal/servidor por el SO)
echo     2) Forzar relevamiento SERVIDOR  (releva todo de una)
echo.
echo   Con los relevamientos ya hechos:
echo     3) Generar INFORME consolidado (HTML)
echo.
echo     0) Salir
echo.
set "op="
set /p "op=Opcion: "

if "%op%"=="1" goto term
if "%op%"=="2" goto srv
if "%op%"=="3" goto informe
if "%op%"=="0" goto fin
echo   Opcion invalida.
timeout /t 1 >nul
goto menu

:term
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sti-mant.ps1" -Menu
goto menu

:srv
echo.
set "tag="
set /p "tag=TAG del cliente (nombre corto, = TAG de OCS): "
if "%tag%"=="" ( echo   Sin TAG, vuelvo al menu. & timeout /t 1 >nul & goto menu )
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sti-mant.ps1" -Tag "%tag%" -Tipo servidores
echo.
pause
goto menu

:informe
echo.
echo   Lee los relevamientos de C:\zback (se crea sola si no existe).
echo   (Para otra carpeta, usa sti-informe.bat con -Carpeta)
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sti-informe.ps1"
echo.
pause
goto menu

:fin
endlocal
exit /b 0
