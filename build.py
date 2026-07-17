#!/usr/bin/env python3
"""build.py - mirror Linux de build.ps1 (no hay pwsh en el host de dev).

Fusiona lib + modules + cada entry-point en dist/<entry>-v<ver>.ps1 (UTF-8 BOM, CRLF).
Misma lógica que build.ps1: reemplaza el bloque de dot-source por el contenido inline.
Mantener en sync con build.ps1.

Uso:  python3 build.py [version]   (default 0.1)
"""
import re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LIB_ORDER = ["lib/common.ps1", "lib/thresholds.ps1", "lib/runspace.ps1", "lib/output.ps1",
             "lib/manual.ps1", "lib/cobian.ps1", "lib/inv-obsolescencia.ps1", "lib/inv-seguridad.ps1",
             "lib/inv-contexto.ps1", "lib/inv-salud.ps1", "lib/inventario.ps1", "lib/core.ps1",
             "lib/audit.ps1", "lib/score.ps1", "lib/informe-model.ps1", "lib/informe-html.ps1"]

GUI_LIBS = ["gui/lib/gui-logic.ps1", "gui/lib/gui-theme.ps1", "gui/lib/gui-branding.ps1",
            "gui/lib/gui-tab-inventario.ps1", "gui/lib/gui-tab-utilidades.ps1",
            "gui/lib/gui-tab-generar.ps1", "gui/lib/gui-tab-mantenimiento.ps1",
            "gui/lib/gui-xaml.ps1", "gui/lib/gui-runspace.ps1"]

def get_body(path: Path) -> str:
    t = path.read_text(encoding="utf-8")
    return t.lstrip("﻿")

def build_inline(include_gui: bool = False) -> str:
    parts = ["# ====== lib + modules (inline, generado por build.py) ======"]
    for rel in LIB_ORDER:
        parts.append(get_body(ROOT / rel))
    for mod in sorted((ROOT / "modules").glob("*.ps1"), key=lambda p: p.name):
        parts.append(get_body(mod))
    if include_gui:
        for g in GUI_LIBS:
            parts.append(get_body(ROOT / g))
    return "\r\n".join(parts)

DOTSRC = re.compile(r'^\s*\.\s+"\$(scriptDir|coreDir)')
MODGLOB = re.compile(r"Get-ChildItem.*modules.*ForEach")

def build_entry(entry_file: str, out_name: str, inline: str):
    body = get_body(ROOT / entry_file)
    out_lines, injected = [], False
    for line in re.split(r"\r?\n", body):
        if DOTSRC.match(line) or MODGLOB.search(line):
            if not injected:
                out_lines.append(inline)
                injected = True
            continue
        out_lines.append(line)
    content = "\r\n".join(out_lines)
    dist_dir = ROOT / "dist"
    dist_dir.mkdir(parents=True, exist_ok=True)
    dist = dist_dir / out_name
    dist.write_bytes(b"\xef\xbb\xbf" + content.encode("utf-8"))
    print(f"Build OK: {dist} ({len(content)} chars)")

def main():
    ver = sys.argv[1] if len(sys.argv) > 1 else "0.1"
    inline = build_inline()
    build_entry("fleet-mant.ps1", f"fleet-mant-v{ver}.ps1", inline)
    build_entry("fleet-informe.ps1", f"fleet-informe-v{ver}.ps1", inline)
    build_entry("gui/fleet-gui.ps1", f"fleet-gui-v{ver}.ps1", build_inline(include_gui=True))

if __name__ == "__main__":
    main()
