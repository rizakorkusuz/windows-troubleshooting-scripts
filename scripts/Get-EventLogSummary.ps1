<#
.SYNOPSIS
    Read-only summary of recent errors and warnings from the System and Application logs.
.DESCRIPTION
    Groups Critical, Error and (optionally) Warning events from the last N hours by log,
    provider and event ID, and highlights common crash indicators such as Kernel-Power 41,
    BugCheck 1001 and unexpected shutdown 6008. Reads logs only.
.PARAMETER Hours
    How far back to look. Default 24.
.PARAMETER IncludeWarnings
    Also include warning-level events.
.PARAMETER Top
    Number of grouped rows to show per log. Default 15.
.EXAMPLE
    .\Get-EventLogSummary.ps1 -Hours 48
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 720)]
    [int]$Hours = 24,
    [switch]$IncludeWarnings,
    [ValidateRange(1, 100)]
    [int]$Top = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$levels = @(1, 2)
if ($IncludeWarnings) { $levels += 3 }
$start = (Get-Date).AddHours(-$Hours)

foreach ($log in 'System', 'Application') {
    Write-Output "== $log log, last $Hours h =="
    try {
        $events = @(Get-WinEvent -FilterHashtable @{ LogName = $log; Level = $levels; StartTime = $start } -ErrorAction Stop)
    } catch [System.Exception] {
        if ($_.FullyQualifiedErrorId -like '*NoMatchingEventsFound*') {
            Write-Output 'No matching events.'
        } else {
            Write-Warning "Could not read $log log: $($_.Exception.Message)"
        }
        continue
    }
    $events | Group-Object ProviderName, Id |
        Sort-Object Count -Descending |
        Select-Object -First $Top |
        ForEach-Object {
            $first = $_.Group | Select-Object -First 1
            [pscustomobject]@{
                Count    = $_.Count
                Provider = $first.ProviderName
                EventId  = $first.Id
                Level    = $first.LevelDisplayName
                Latest   = ($_.Group | Measure-Object TimeCreated -Maximum).Maximum.ToString('s')
                Sample   = (($first.Message -split "`r?`n")[0])
            }
        } | Format-Table -AutoSize -Wrap
}

Write-Output '== Crash and shutdown indicators =='
$indicators = @(
    @{ Log = 'System'; Id = 41;   Note = 'Kernel-Power: system rebooted without clean shutdown' },
    @{ Log = 'System'; Id = 1001; Note = 'BugCheck: blue screen recorded' },
    @{ Log = 'System'; Id = 6008; Note = 'Unexpected shutdown' },
    @{ Log = 'Application'; Id = 1000; Note = 'Application crash' }
)
foreach ($i in $indicators) {
    try {
        $hits = @(Get-WinEvent -FilterHashtable @{ LogName = $i.Log; Id = $i.Id; StartTime = $start } -ErrorAction Stop)
        Write-Output ("{0} event {1}: {2} in window. {3}" -f $i.Log, $i.Id, $hits.Count, $i.Note)
    } catch {
        Write-Output ("{0} event {1}: 0 in window. {2}" -f $i.Log, $i.Id, $i.Note)
    }
}
