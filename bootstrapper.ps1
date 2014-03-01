# Get the temporary folder environment variable
$temp = [system.environment]::getenvironmentvariable('TEMP')
$setup = "$temp\setup"
if ( (Test-Path "$temp") -and !(Test-Path $setup) ) { 
  New-Item -type directory "$setup"
} 

# Get the system drive environment variable
$systemdrive = [System.Environment]::GetEnvironmentVariable('SYSTEMDRIVE')

# Get program files environment variable
$programfiles = [System.Environment]::GetEnvironmentVariable('PROGRAMFILES');

# Set the PATH environment variable for Chocolatey & VMware Tools
[System.Environment]::SetEnvironmentVariable("PATH", $Env:Path + ";$programfiles\VMware\VMware Tools;$systemdrive\chocolatey\bin", "Machine")

# Get the URI to the latest Windows x64 VMtools release
$latest = (Invoke-WebRequest -UseBasicParsing -Uri http://packages.vmware.com/tools/esx/latest/windows/x64/index.html).Links | 
Where-Object {$_.href.EndsWith('exe')} | select -expand href

# Download VMware Tools
Import-Module BitsTransfer
Start-BitsTransfer -Source "http://packages.vmware.com/tools/esx/latest/windows/x64/$latest" -Destination "$setup\vmtools.exe"

# If the download was successful, install VMware Tools
if ( Test-Path "$setup\vmtools.exe" ) { 
  $vmtoolsd = "$setup\vmtools.exe /S /v '/qn REBOOT=R ADDLOCAL=ALL'"
  Invoke-Expression $vmtoolsd
}

# Capture OVF runtime environment metadata
$vmtoolsdexe = "$systemdrive\Program Files\VMware\VMware Tools\vmtoolsd.exe"
if ( Test-Path "$vmtoolsdexe" ) {
  Set-Location "$systemdrive\Program Files\VMware\VMware Tools"
  Invoke-Command { & cmd /C "vmtoolsd.exe --cmd 'info-get guestinfo.ovfEnv'" } | Add-Content "$setup\ovf-env.xml"
}

# Install Chocolatey
$chocolatey = New-Object System.Net.Webclient
Invoke-Expression $chocolatey.DownloadString('http://chocolatey.org/install.ps1')

# Install WuInstall
$wuinstall = "cmd /C $systemdrive\chocolatey\bin\cinst wuinstall"
Invoke-Expression $wuinstall

# Run WuInstall
$wuinstallrun = "cmd /C $systemdrive\chocolatey\bin\cinst wuinstall.run"
Invoke-Expression $wuinstallrun

# Install Puppet with Chocolatey
$puppet = "cmd /C $systemdrive\chocolatey\bin\cinst puppet"
Invoke-Expression $puppet

# Do the XSL transform
if ( (Test-Path "$systemdrive\ProgramData\PuppetLabs\Facter\facts.d") -and (Test-Path "$setup\ovf-env.xml") ) {
  $xslt = New-Object System.Xml.Xsl.XslCompiledTransform
  $xslt.Load([xml](New-Object System.Net.WebClient).DownloadString("https://raw.github.com/superfantasticawesome/provisioning/master/xml-to-yaml.xsl"))
  $xslt.Transform("$setup\ovf-env.xml", "$systemdrive\ProgramData\PuppetLabs\Facter\facts.d\facts.yaml")
}

# Cleanup
Remove-Item -Recurse -Force "$setup\*"
