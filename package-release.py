#!/usr/bin/env python3
"""Empaqueta la release del tecnico: dist single-file (CLI + GUI) + bats + LEEME -> zip.

El instalador de OCS (OcsPackage-x64.exe) es interno de STI y NO se distribuye en el zip publico.
El script lo usa solo si esta presente localmente junto al .ps1, pero el paquete no lo incluye.

Prerequisito: correr antes `build.ps1 -Version <ver>` (genera dist/sti-*-v<ver>.ps1, incluido sti-gui).
Uso:  python3 package-release.py <version> [salida_dir]
Salida: <salida_dir>/sti-mantenimiento-v<ver>/  +  sti-mantenimiento-v<ver>.zip
"""
import sys, shutil, zipfile
from pathlib import Path

# Launcher de la GUI: lo genera el empaquetador (no hay .bat de GUI en el repo). UTF-8 sin BOM, CRLF.
# Lanzador de la GUI sin ventana de consola visible y con auto-elevacion (UAC): las Utilidades
# mutan el equipo y varios checks necesitan admin. Si la sesion no esta elevada, relanza la GUI
# como administrador; si ya lo esta, la abre directo. -WindowStyle Hidden oculta la consola de
# PowerShell (la ventana WPF de la GUI es la unica visible).
GUI_BAT = (
    "@echo off\r\n"
    "net session >nul 2>&1\r\n"
    "if %errorlevel% neq 0 (\r\n"
    '  powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList \'-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"\"%~dp0sti-gui.ps1\"\"\' -Verb RunAs"\r\n'
    ") else (\r\n"
    '  start "" powershell -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0sti-gui.ps1"\r\n'
    ")\r\n"
    "exit /b\r\n"
)

def norm_bat(srcp: Path, dstp: Path):
    """bat -> UTF-8 sin BOM, CRLF (cmd con chcp 65001)."""
    data = srcp.read_bytes()
    if data[:3] == b"\xef\xbb\xbf":
        data = data[3:]
    text = data.decode("utf-8").replace("\r\n", "\n").replace("\n", "\r\n")
    dstp.write_bytes(text.encode("utf-8"))

def norm_txt(srcp: Path, dstp: Path):
    """txt -> CRLF (ASCII)."""
    text = srcp.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\n", "\r\n")
    dstp.write_bytes(text.encode("utf-8"))

def main():
    if len(sys.argv) < 2:
        sys.exit("uso: package-release.py <version> [salida_dir]")
    ver = sys.argv[1]
    root = Path(__file__).resolve().parent
    out_dir = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else (root / "release" / "dist")
    bundle = out_dir / f"sti-mantenimiento-v{ver}"

    mant = root / f"dist/sti-mant-v{ver}.ps1"
    informe = root / f"dist/sti-informe-v{ver}.ps1"
    gui = root / f"dist/sti-gui-v{ver}.ps1"
    for p in (mant, informe, gui):
        if not p.exists():
            sys.exit(f"falta {p} (corriste build.ps1 -Version {ver}?)")

    if bundle.exists():
        shutil.rmtree(bundle)
    bundle.mkdir(parents=True)

    # ps1 single-file -> nombres bare (los bats referencian sti-mant.ps1 / sti-informe.ps1 / sti-gui.ps1)
    shutil.copyfile(mant, bundle / "sti-mant.ps1")
    shutil.copyfile(informe, bundle / "sti-informe.ps1")
    shutil.copyfile(gui, bundle / "sti-gui.ps1")
    # NOTA: OcsPackage-x64.exe (instalador OCS interno de STI) NO se empaqueta en el release publico.
    norm_bat(root / "release/STI-Mantenimiento.bat", bundle / "STI-Mantenimiento.bat")
    norm_bat(root / "sti-mant.bat", bundle / "sti-mant.bat")
    norm_bat(root / "sti-informe.bat", bundle / "sti-informe.bat")
    (bundle / "STI-GUI.bat").write_bytes(GUI_BAT.encode("utf-8"))
    norm_txt(root / "release/LEEME.txt", bundle / "LEEME.txt")

    zip_path = out_dir / f"sti-mantenimiento-v{ver}.zip"
    if zip_path.exists():
        zip_path.unlink()
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(bundle.rglob("*")):
            z.write(f, f.relative_to(out_dir))

    print(f"OK -> {zip_path} ({zip_path.stat().st_size:,} B)")
    for f in sorted(bundle.iterdir()):
        print(f"   {f.name:28} {f.stat().st_size:>9,} B")

if __name__ == "__main__":
    main()
