# STI Mantenimiento

A PowerShell toolkit for auditing and maintaining fleets of Windows machines during on-site or remote visits. It runs locally on the target machine, no internet connection or credentials required, and produces a maintenance checklist, a hardware/software inventory, and consolidated HTML/JSON reports.

Built for support technicians and MSPs who manage parks of Windows terminals and servers and need a repeatable, auditable maintenance routine instead of an ad hoc checklist on paper.

Two ways to use it: a WPF graphical interface (the primary mode) and a CLI for unattended runs or scripting.

## What it does

**1. Equipment maintenance.** Runs a checklist over security, system, hardware, network and tooling categories, each check resolving to a traffic-light status (Ok / Warning / Error / Critical). Automated checks (firewall, antivirus, updates, disk space, SMART, connectivity, backups, etc.) run without user input; a handful of checks that need a human eye (physical hardware condition, peripherals, UPS) are asked interactively at the end. Output:

- A TSV block copied to the clipboard, ready to paste into a spreadsheet.
- An HTML report of the machine's maintenance pass.
- A JSON with the status and detail of every check, meant to be consumed by a downstream process (the consolidated report, or a CRM/back-office integration).

**2. Equipment inventory.** A precise inventory of the machine: CPU, RAM and DIMM layout, disks with type (HDD/SSD/NVMe), OS version, installed software (filtered, no updates or redistributables noise), and hardware identifiers. It also pulls data useful for an audit:

- Obsolescence: OS end-of-support date, TPM presence, Secure Boot, Windows 11 readiness, BIOS version and age.
- Security: BitLocker encryption, local admin accounts, UAC, SMBv1, outdated TLS, Defender tamper protection.
- Context: network configuration, GPU, monitors, printers, last update installed, presence of management agents.
- Health: blue screens, unexpected shutdowns, stopped automatic services, startup programs, battery wear.

Generates its own HTML and JSON.

**3. Consolidated report.** Merges every inventory JSON in a folder and builds three HTML reports (full, terminals-only, servers-only) with a fleet-wide summary: health score, machines needing attention, and a full check matrix.

## Graphical interface

`sti-gui.ps1` is a WPF window with five tabs covering the full visit:

- **Main:** identify the machine (client, tag, type) and trigger the audit run.
- **Inventory:** hardware shown as cards (CPU, RAM, disks, OS, GPU, identifiers).
- **Maintenance:** the checklist with per-check status, notes, and the manual checks that need a human answer. Generates the machine's JSON.
- **Utilities:** a winutil-style toolbox (cleanup, repairs, tweaks, debloating, services). These actions actually change the machine and are logged.
- **Generate:** merges all collected JSON files into the spreadsheet block and the HTML report.

### Running it

Remotely, on any Windows machine, from PowerShell:

```powershell
irm https://raw.githubusercontent.com/callofthev0id/sti-mant/main/get.ps1 | iex
```

This downloads the latest published release and opens the GUI, self-elevating (one UAC prompt) so the Utilities tab and the checks that read system state work correctly.

Downloading and running an unsigned script can trigger SmartScreen or antivirus warnings on some machines; that is inherent to the `irm | iex` pattern, not something specific to this script. The code is open and lives in this repo. If you'd rather avoid it, use the downloadable release instead (`STI-GUI.bat`).

## Requirements

- Windows 10 / 11 or Windows Server (tested from 2016 onward).
- PowerShell 5.1 or newer (ships with Windows).
- The GUI needs WPF, which ships with the .NET Framework already present on Windows 10/11 and Server. Nothing extra to install.
- Running as administrator is recommended so the checks that read system state don't fall back to N/A, and so the Utilities tab can act. The GUI self-elevates (via `irm | iex` or the `.bat` launcher).

No network access or credentials required beyond the initial download.

## Usage

### Graphical interface

The primary mode. Remote: see the command above. Offline: double-click `STI-GUI.bat` from a downloaded release.

### Menu or command line

Simplest path without the GUI: unpack a release on the machine and double-click `STI-Mantenimiento.bat`. The menu auto-detects whether the machine is a terminal or a server and writes everything to `C:\zback`.

From the command line directly:

```powershell
# Maintenance run (auto-detects terminal/server from the OS)
PowerShell -ExecutionPolicy Bypass -File sti-mant.ps1 -Tag <name> [-Tipo terminales|servidores] [-Cliente "Name"] [-Usuario "user"] [-Nota "note"]

# Inventory
PowerShell -ExecutionPolicy Bypass -File sti-mant.ps1 -Inventario [-Cliente "Name"]

# Consolidated report from a folder of JSON files (defaults to C:\zback)
PowerShell -ExecutionPolicy Bypass -File sti-informe.ps1 [-Carpeta <path>] [-Cliente "Name"] [-Periodo 2026-06]
```

Options:

- `-Tipo`: if omitted, auto-detected from the OS (Windows Server maps to `servidores`, everything else to `terminales`). Pass it to force the type.
- `-Inventario`: runs the inventory pass. Can be combined with `-Tag` to run both.
- `-InstallOCS`: if an `OcsPackage-x64.exe` installer is placed next to the script, installs it. By default the script only checks whether an agent is already present; the installer itself is not bundled.

The admin-accounts check (which local accounts are expected on a managed machine) reads its expected list from the `STI_CUENTAS_ADMIN` environment variable (comma or semicolon separated), or from an optional local file `lib/sti-cuentas.local` (one account per line, `#` for comments, not versioned). If neither is set, the check degrades instead of failing and never hardcodes usernames.

## Output

Everything lands in `C:\zback` (created automatically). File names are prefixed with the hostname:

- `<host>_STI_MANT_<type>_<date>.html` / `.json`: maintenance pass.
- `<host>_RELEVAMIENTO_<date>.html` / `.json`: inventory pass.
- `<host>_Informe_Mantenimiento_<client>_<period>_{FULL,TERMINALES,SERVIDORES}.html`: consolidated report.

The JSON is the machine-readable source of truth: status and reasoning for every check. Don't delete it, downstream reports are built from it.

## Cobian backups

If Cobian Reflector or Cobian Backup is installed on the machine, the backup check is filled in automatically: it reads the backup history (`history.db` via SQLite, falling back to the log files) and evaluates each job against its configured frequency (daily, weekly, monthly), flagging jobs that are current, late, or overdue. Without Cobian, the backup check stays manual.

## Architecture

```
sti-mant/
  sti-gui.ps1         entry point: WPF graphical interface
  sti-mant.ps1        entry point: maintenance + inventory + menu
  sti-informe.ps1     entry point: consolidated report
  gui/                GUI logic
    lib/
      gui-logic.ps1         tab orchestration and state
      gui-theme.ps1         visual theme
      gui-branding.ps1      branding
      gui-xaml.ps1          window XAML definition
      gui-runspace.ps1      runs the audit without freezing the UI
      gui-tab-inventario.ps1
      gui-tab-mantenimiento.ps1
      gui-tab-utilidades.ps1
      gui-tab-generar.ps1
  lib/                pure logic + WMI/registry collectors + HTML rendering
    core.ps1            reusable core: New-MantContext / Invoke-Relevamiento
    audit.ps1           audit trail for Utilities actions (Event Log + JSON-lines + text)
    common.ps1          pure helpers, check manifest, config
    thresholds.ps1       value -> traffic-light status evaluators
    runspace.ps1        runs check modules in parallel
    output.ps1          TSV, maintenance HTML, JSON
    manual.ps1          interactive collection of manual checks
    cobian.ps1          Cobian backup auto-detection
    inventario.ps1      inventory model + report
    inv-*.ps1           inventory sections (obsolescence, security, context, health)
    score.ps1           health score
    informe-model.ps1   JSON -> report model
    informe-html.ps1    consolidated report rendering
  modules/            one module per check category (security, system, hardware, network, tools, servers)
  tests/              Pester tests for the pure logic
  build.ps1           merges lib + modules + entry point into a single file
  package-release.py  builds the release zip
```

The code lives modularly under `lib/`, `modules/` and `gui/`. The GUI (`sti-gui.ps1`) builds on `core.ps1`, which exposes the audit as reusable functions (`New-MantContext`, `Invoke-Relevamiento`) shared with the CLI. For distribution, `build.ps1` merges everything into a single `.ps1` per entry point (no loose file dependencies). Check modules run in parallel via a runspace pool.

## Utilities audit trail

Actions in the Utilities tab that modify the machine are logged for traceability. `lib/audit.ps1` writes every action to:

- A dedicated Event Log source ("STI Mantenimiento"), visible in Event Viewer under Applications and Services Logs.
- Files under `C:\ProgramData\STI\audit\`: one JSON-lines record per action plus a plain-text log.

Queryable and exportable, so it's possible to reconstruct what was changed on a machine and when.

## Extending

**Add a check to an existing category:**

1. In the relevant module (`modules/mod-<category>.ps1`), emit the check with `New-CheckItem -Key '<key>' -Label '<label>' -Status <status> -Automated $true|$false -Detail '<detail>'`.
2. Add the key to `CHK_ORDER_TERM` or `CHK_ORDER_SRV` in `lib/common.ps1`, in the position it should appear in the TSV.

**Add an inventory section:**

1. Create `lib/inv-<name>.ps1` with a `Get-Inv<Name>` function returning a hashtable.
2. Call it from `New-InventarioModel` (in `lib/inventario.ps1`) and add the render for the section in `New-InventarioHtml`.
3. Add the file to the `libOrder` list in `build.ps1` (and `build.py`) and to the dot-source list in `sti-mant.ps1`.

**If a new function is called from a module** (which runs in a parallel runspace), add it to the `$helpers` list in `lib/runspace.ps1`, or it won't be available inside the runspace.

## Development

Code comments are in Spanish; the tool's intended technician audience is Spanish-speaking, same as the generated reports and `LEEME.txt`.

```powershell
.\build.ps1 -Version <ver>     # generates dist/sti-*-v<ver>.ps1 (single-file, UTF-8 with BOM)
Invoke-Pester tests            # Pester 5; tests the pure logic
```

Collectors (WMI, registry, SQLite) are validated on a real Windows machine, not in the test suite. `.ps1` files are saved as UTF-8 with BOM so PowerShell 5.1 renders accented characters correctly.

`build.py` mirrors `build.ps1` to generate the single-file build in environments without PowerShell.

## Release

```powershell
.\build.ps1 -Version <ver>
python3 package-release.py <ver>
```

Produces `release/dist/sti-mantenimiento-v<ver>.zip` with the single-file builds (`sti-gui.ps1`, `sti-mant.ps1`, `sti-informe.ps1`), the `.bat` launchers, and the technician-facing `LEEME.txt` (in Spanish, since the toolkit's intended audience is Spanish-speaking).

## Status

This is a portfolio/demo project derived from a real internal tool built for MSP field operations. It is functional and tested (Pester suite covering the pure logic), but published here to showcase the architecture and approach rather than as a maintained product: no CI, no issue tracker, no guarantee of ongoing releases.
