<#
.SYNOPSIS
    Read-only network diagnostic that follows the troubleshooting ladder.
.DESCRIPTION
    Checks adapter and address, default gateway, internet reachability by IP, DNS resolution
    and TCP connectivity to chosen targets, and prints a PASS/WARN/FAIL line per rung.
    Sends only a few ICMP, DNS and TCP connection attempts. It does not scan ports, change
    settings, flush caches or renew leases.
.PARAMETER InternetTarget
    IP address used for the internet reachability test. Default 1.1.1.1.
.PARAMETER DnsName
    Name used for the DNS test. Default example.com.
.PARAMETER TcpTargets
    Host:port pairs for TCP tests. Default example.com:443. Test only systems you manage
    or are authorized to test.
.EXAMPLE
    .\Test-NetworkHealth.ps1
.EXAMPLE
    .\Test-NetworkHealth.ps1 -TcpTargets 'intranet.contoso.local:443','fileserver:445'
#>
[CmdletBinding()]
param(
    [string]$InternetTarget = '1.1.1.1',
    [string]$DnsName = 'example.com',
    [string[]]$TcpTargets = @('example.com:443')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param([string]$Step, [ValidateSet('PASS', 'WARN', 'FAIL')][string]$Status, [string]$Detail)
    $results.Add([pscustomobject]@{ Step = $Step; Status = $Status; Detail = $Detail })
}

# 1-2: adapter and address
$configs = @()
try {
    $configs = @(Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.NetAdapter.Status -eq 'Up' })
} catch {
    Add-Result 'Adapter' 'FAIL' "Could not read network configuration: $($_.Exception.Message)"
}

if ($configs.Count -eq 0) {
    Add-Result 'Adapter' 'FAIL' 'No connected network adapter found. Check cable, Wi-Fi and Airplane mode.'
} else {
    foreach ($c in $configs) {
        $ip = @($c.IPv4Address | ForEach-Object { $_.IPAddress }) -join ', '
        if (-not $ip) {
            Add-Result "Adapter $($c.InterfaceAlias)" 'WARN' 'Connected but no IPv4 address.'
        } elseif ($ip -like '169.254.*') {
            Add-Result "Adapter $($c.InterfaceAlias)" 'FAIL' "APIPA address $ip. No DHCP lease received."
        } else {
            Add-Result "Adapter $($c.InterfaceAlias)" 'PASS' "IPv4 $ip"
        }
    }
}

# 4: gateway
$gateways = @()
foreach ($c in $configs) {
    if ($c.IPv4DefaultGateway) { $gateways += $c.IPv4DefaultGateway.NextHop }
}
if ($gateways.Count -eq 0) {
    Add-Result 'Gateway' 'FAIL' 'No default gateway configured.'
} else {
    foreach ($g in ($gateways | Select-Object -Unique)) {
        $ok = Test-Connection -ComputerName $g -Count 2 -Quiet -ErrorAction SilentlyContinue
        if ($ok) {
            Add-Result "Gateway $g" 'PASS' 'Replied to ping.'
        } else {
            Add-Result "Gateway $g" 'WARN' 'No ping reply (some routers block ICMP).'
        }
    }
}

# 5: internet by IP
$net = Test-Connection -ComputerName $InternetTarget -Count 2 -Quiet -ErrorAction SilentlyContinue
if ($net) {
    Add-Result "Internet by IP ($InternetTarget)" 'PASS' 'Replied to ping.'
} else {
    Add-Result "Internet by IP ($InternetTarget)" 'FAIL' 'No reply. ICMP may be blocked, so also check the TCP tests.'
}

# 6: DNS
$dnsServers = @()
foreach ($c in $configs) {
    if ($c.DnsServer) { $dnsServers += $c.DnsServer.ServerAddresses }
}
if ($dnsServers.Count -gt 0) {
    Add-Result 'DNS servers' 'PASS' (($dnsServers | Select-Object -Unique) -join ', ')
} else {
    Add-Result 'DNS servers' 'WARN' 'No DNS servers configured on connected adapters.'
}
try {
    $answer = Resolve-DnsName -Name $DnsName -Type A -ErrorAction Stop -DnsOnly |
        Where-Object { $_.Type -eq 'A' } | Select-Object -First 1
    if ($answer) {
        Add-Result "DNS lookup $DnsName" 'PASS' "Resolved to $($answer.IPAddress)"
    } else {
        Add-Result "DNS lookup $DnsName" 'WARN' 'Query succeeded but returned no A record.'
    }
} catch {
    Add-Result "DNS lookup $DnsName" 'FAIL' $_.Exception.Message
}

# 7: TCP
foreach ($t in $TcpTargets) {
    $parts = $t -split ':'
    if ($parts.Count -ne 2 -or -not ($parts[1] -as [int])) {
        Add-Result "TCP $t" 'WARN' "Skipped. Use host:port format."
        continue
    }
    try {
        $r = Test-NetConnection -ComputerName $parts[0] -Port ([int]$parts[1]) -WarningAction SilentlyContinue -ErrorAction Stop
        if ($r.TcpTestSucceeded) {
            Add-Result "TCP $t" 'PASS' 'Connection succeeded.'
        } else {
            Add-Result "TCP $t" 'FAIL' 'Connection failed (firewall, service down or wrong address).'
        }
    } catch {
        Add-Result "TCP $t" 'FAIL' $_.Exception.Message
    }
}

$results | Format-Table -AutoSize -Wrap
$failures = @($results | Where-Object { $_.Status -eq 'FAIL' })
if ($failures.Count -gt 0) {
    Write-Output "First failing rung: $($failures[0].Step). Fix this layer before testing higher layers."
} else {
    Write-Output 'No failing rung found.'
}
