# windows-troubleshooting-scripts

Safe, **read-only** PowerShell and batch diagnostics for first-line Windows support. Each script collects the evidence a help desk or desktop support technician asks for in a ticket: system facts, network ladder results, disk health, recent error events and printer state. None of them repairs, deletes or reconfigures anything.

**Roles this supports:** Help Desk Specialist, Desktop Support Technician, Service Desk Analyst, IT Support Specialist and Engineer, Technical Support Specialist and Engineer, Deskside Support Technician, Field Service Technician.

## Safety first

- Scripts only **read** information. They do not change settings, clear caches, restart services, renew leases, or delete files.
- Read the code before you run it on any computer. Run only on devices you own or are authorized to support.
- Output can include computer names, user names, IP addresses and event text. Review it before attaching it to a ticket or sharing it outside your organization.
- `Test-NetworkHealth.ps1` makes a few ICMP, DNS and TCP connection attempts to the targets you choose. It is not a port scanner. Do not point it at systems you are not authorized to test.
- No credentials, tokens or company data are in this repository, and none are collected.
- Provided as-is under the MIT license, without warranty.

## Scripts

| Script | What it reports | Needs admin? |
| --- | --- | --- |
| `scripts/Get-SystemSummary.ps1` | Model, serial, OS build, uptime, memory, pending reboot, join state, BitLocker and TPM | No (BitLocker and TPM fields need it) |
| `scripts/Test-NetworkHealth.ps1` | Adapter and IP, gateway, internet by IP, DNS servers and lookup, TCP checks, PASS/WARN/FAIL per rung | No |
| `scripts/Get-DiskHealth.ps1` | Free space with low-space flag, physical disk health, dirty bit | Physical disk details may need it |
| `scripts/Get-EventLogSummary.ps1` | Grouped critical and error events from System and Application logs, crash indicators (Kernel-Power 41, BugCheck 1001, 6008) | System log is readable by standard users in most setups |
| `scripts/Get-PrinterStatus.ps1` | Printers, drivers, ports, IP, queued jobs, spooler state, optional port 9100 test | No |
| `scripts/Invoke-SupportSnapshot.ps1` | Runs all of the above and saves one timestamped text report | Same as above |
| `batch/network-diag.bat` | `ipconfig /all`, routes, ping, nslookup, tracert and Wi-Fi details written to a Desktop text file | No |

## Usage

Windows PowerShell 5.1 and PowerShell 7 on Windows 10 and 11 are supported.

```powershell
# Allow scripts for this session only, without changing the system policy
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

.\scripts\Get-SystemSummary.ps1
.\scripts\Test-NetworkHealth.ps1 -TcpTargets 'intranet.example.com:443'
.\scripts\Get-DiskHealth.ps1 -LowSpacePercent 15
.\scripts\Get-EventLogSummary.ps1 -Hours 48 -IncludeWarnings
.\scripts\Get-PrinterStatus.ps1 -TestPorts
.\scripts\Invoke-SupportSnapshot.ps1 -OutputFolder C:\Temp
```

If your organization restricts script execution, follow its policy and ask your administrator to approve or sign the scripts rather than working around the restriction.

Use `Get-Help .\scripts\Test-NetworkHealth.ps1 -Full` for parameters and examples.

## How the output maps to the troubleshooting workflow

1. `Get-SystemSummary` answers the triage questions: what is this device, how long since reboot, is a restart pending, is it managed.
2. `Test-NetworkHealth` walks the ladder (adapter, gateway, internet, DNS, TCP) and names the first failing rung.
3. `Get-DiskHealth` rules storage in or out for slow-device and update tickets.
4. `Get-EventLogSummary` shows what failed around the time the user noticed the problem.
5. `Get-PrinterStatus` separates printer, port, driver and queue problems.

The matching runbooks are in the companion repository `it-support-playbooks`.

## Quality checks

- All scripts parse cleanly and pass PSScriptAnalyzer (Warning and Error severity) with the default rules. See `.github/workflows/lint.yml`.
- The scripts were written for Windows. They were syntax-checked and analyzed on PowerShell 7 on Linux, where Windows-only cmdlets are unavailable, and the scripts degrade to "Unavailable" messages instead of failing. Test on a non-production Windows device before relying on them.

Run the checks locally:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning,Error
Invoke-Pester ./tests   # requires Pester 5
```

## Roadmap ideas

Windows Update history summary, Wi-Fi profile report, installed software export, JSON output for every script.

## License

MIT. See [LICENSE](LICENSE).
