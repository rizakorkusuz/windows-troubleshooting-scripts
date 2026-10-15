<#
.SYNOPSIS
    Runs the read-only diagnostics in this repository and saves one text report.
.DESCRIPTION
    Calls Get-SystemSummary, Test-NetworkHealth, Get-DiskHealth, Get-EventLogSummary and
    Get-PrinterStatus, and writes the combined output to a timestamped .txt file you can
    attach to a ticket. Nothing on the computer is changed. Review the report before sharing
    it, since it contains the computer name and user name.
.PARAMETER OutputFolder
    Folder for the report. Default is the current user's Documents folder.
.PARAMETER SkipPrinters
    Skip the printer section.
.EXAMPLE
    .\Invoke-SupportSnapshot.ps1 -OutputFolder C:\Temp
#>
[CmdletBinding()]
param(
    [string]$OutputFolder = [Environment]::GetFolderPath('MyDocuments'),
    [switch]$SkipPrinters
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

if (-not (Test-Path -LiteralPath $OutputFolder -PathType Container)) {
    throw "Output folder not found: $OutputFolder"
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$report = Join-Path $OutputFolder "SupportSnapshot-$env:COMPUTERNAME-$stamp.txt"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$sections = [ordered]@{
    'System summary'  = { & (Join-Path $here 'Get-SystemSummary.ps1') | Format-List | Out-String }
    'Network health'  = { & (Join-Path $here 'Test-NetworkHealth.ps1') | Out-String }
    'Disk health'     = { & (Join-Path $here 'Get-DiskHealth.ps1') | Out-String }
    'Event log summary' = { & (Join-Path $here 'Get-EventLogSummary.ps1') | Out-String }
}
if (-not $SkipPrinters) {
    $sections['Printers'] = { & (Join-Path $here 'Get-PrinterStatus.ps1') | Out-String }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("Support snapshot generated $(Get-Date -Format 's')")
[void]$sb.AppendLine('Read-only diagnostics. Review before sharing: includes computer and user names.')
foreach ($name in $sections.Keys) {
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine("##### $name #####")
    try {
        [void]$sb.AppendLine((& $sections[$name]))
    } catch {
        [void]$sb.AppendLine("Section failed: $($_.Exception.Message)")
    }
}
Set-Content -LiteralPath $report -Value $sb.ToString() -Encoding UTF8
Write-Output "Report saved to $report"
