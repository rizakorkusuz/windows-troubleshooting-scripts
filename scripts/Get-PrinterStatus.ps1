<#
.SYNOPSIS
    Read-only report of printers, ports, drivers and queued jobs.
.DESCRIPTION
    Shows installed printers with status, driver and port, the IP address of TCP/IP ports,
    queued job counts and the Print Spooler service state. Does not clear queues, restart
    services or change printers.
.PARAMETER TestPorts
    Also test TCP port 9100 reachability for printers on TCP/IP ports.
.EXAMPLE
    .\Get-PrinterStatus.ps1 -TestPorts
#>
[CmdletBinding()]
param(
    [switch]$TestPorts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

Write-Output '== Print Spooler service =='
try {
    Get-Service -Name Spooler -ErrorAction Stop | Select-Object Name, Status, StartType | Format-Table -AutoSize
} catch {
    Write-Warning "Could not read Spooler service: $($_.Exception.Message)"
}

Write-Output '== Printers =='
try {
    $ports = @{}
    Get-PrinterPort -ErrorAction SilentlyContinue | ForEach-Object { $ports[$_.Name] = $_ }
    $rows = Get-Printer -ErrorAction Stop | ForEach-Object {
        $p = $ports[$_.PortName]
        $addr = if ($p -and $p.PrinterHostAddress) { $p.PrinterHostAddress } else { '' }
        $jobs = @(Get-PrintJob -PrinterName $_.Name -ErrorAction SilentlyContinue).Count
        $reach = ''
        if ($TestPorts -and $addr) {
            $reach = if (Test-NetConnection -ComputerName $addr -Port 9100 -InformationLevel Quiet -WarningAction SilentlyContinue) { 'Open' } else { 'Closed or filtered' }
        }
        [pscustomobject]@{
            Name       = $_.Name
            Driver     = $_.DriverName
            Port       = $_.PortName
            Address    = $addr
            Status     = $_.PrinterStatus
            QueuedJobs = $jobs
            Port9100   = $reach
        }
    }
    $rows | Format-Table -AutoSize -Wrap
} catch {
    Write-Warning "Could not read printers: $($_.Exception.Message)"
}

Write-Output 'Note: this script is read-only. To clear a stuck queue follow your runbook and get approval for any service restart.'
