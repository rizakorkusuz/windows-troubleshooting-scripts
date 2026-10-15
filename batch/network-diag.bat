@echo off
REM network-diag.bat - read-only network diagnostics for Windows.
REM Writes output to a text file on the Desktop. Changes no settings.
REM Usage: network-diag.bat [target-host]   (default target: example.com)

setlocal
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=example.com"
set "OUT=%USERPROFILE%\Desktop\network-diag-%COMPUTERNAME%.txt"

echo Network diagnostics for %COMPUTERNAME% on %DATE% %TIME% > "%OUT%"
echo Target: %TARGET% >> "%OUT%"

echo. >> "%OUT%"
echo ===== ipconfig /all ===== >> "%OUT%"
ipconfig /all >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo ===== route print -4 ===== >> "%OUT%"
route print -4 >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo ===== ping 1.1.1.1 ===== >> "%OUT%"
ping -n 4 1.1.1.1 >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo ===== nslookup %TARGET% ===== >> "%OUT%"
nslookup %TARGET% >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo ===== ping %TARGET% ===== >> "%OUT%"
ping -n 4 %TARGET% >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo ===== tracert %TARGET% ===== >> "%OUT%"
tracert -d -h 15 %TARGET% >> "%OUT%" 2>&1

echo. >> "%OUT%"
echo ===== netsh wlan show interfaces ===== >> "%OUT%"
netsh wlan show interfaces >> "%OUT%" 2>&1

echo Done. Report saved to "%OUT%"
endlocal
