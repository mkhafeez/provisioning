# Get the temporary folder environment variable
$temp = [system.environment]::getenvironmentvariable('TEMP')
$setup = "$temp\setup"
if ( (Test-Path "$temp") -and !(Test-Path $setup) ) { 
  New-Item -type directory "$setup"
} 

# Get the system drive environment variable
$systemdrive = [System.Environment]::GetEnvironmentVariable('SYSTEMDRIVE')

# Get program files environment variable
$programfiles = [System.Environment]::GetEnvironmentVariable('PROGRAMFILES')

# Set the PATH environment variable for Chocolatey & VMware Tools
[System.Environment]::SetEnvironmentVariable("PATH", $Env:Path + ";$programfiles\VMware\VMware Tools;$systemdrive\chocolatey\bin", "Machine")

# Get the URI to the latest Windows x64 VMtools release
$latest = (Invoke-WebRequest -UseBasicParsing -Uri http://packages.vmware.com/tools/esx/5.5/windows/x64/index.html).Links | 
Where-Object {$_.href.EndsWith('exe')} | Select -Expand href

# Download VMware Tools
Import-Module BitsTransfer
Start-BitsTransfer -Source "http://packages.vmware.com/tools/esx/5.5/windows/x64/$latest" -Destination "$setup\vmtools.exe"

# If the download was successful, install VMware Tools
if ( Test-Path "$setup\vmtools.exe" ) { 
  Invoke-Expression "$setup\vmtools.exe /S /v '/qn REBOOT=R ADDLOCAL=ALL'"
}

# Capture OVF runtime environment metadata
if ( Test-Path "$programfiles\VMware\VMware Tools\vmtoolsd.exe" ) {
  Set-Location "$programfiles\VMware\VMware Tools"
  Invoke-Command { & cmd /C 'vmtoolsd.exe --cmd "info-get guestinfo.ovfEnv"' } | Add-Content "$setup\ovf-env.xml"
}

# Install Chocolatey
Invoke-Expression (New-Object System.Net.Webclient).DownloadString('http://chocolatey.org/install.ps1')

# Install Puppet with Chocolatey
Invoke-Expression "cmd /C $systemdrive\chocolatey\bin\cinst puppet"

# Do the XSL transform
if ( (Test-Path "$systemdrive\ProgramData\PuppetLabs\Facter\facts.d") -and (Test-Path "$setup\ovf-env.xml") ) {
  $xsl = New-Object System.Xml.Xsl.XslCompiledTransform
  $xsl.Load([xml](New-Object System.Net.WebClient).DownloadString("https://raw.github.com/superfantasticawesome/provisioning/master/xml-to-yaml.xsl"))
  $xsl.Transform("$setup\ovf-env.xml", "$systemdrive\ProgramData\PuppetLabs\Facter\facts.d\facts.yaml")
}

# Rename the computer
# Note that the "keys" array maps directly to my OVF custom properties. 
# Adjust for your environment as required.
$keys = 'app_project', 'app_environment', 'app_role', 'app_id'
$xml = New-Object -TypeName XML
$xml.Load( "$setup\ovf-env.xml" )
$hostname = $xml.Environment.PropertySection.Property | 
  % -Begin { $h = @{} } -Process { $h[$_.key] = $_.value } -End `
    { ( $keys | %{ $h.$_ }) -join '-' } 
Rename-Computer -NewName $hostname -Force

# Cleanup
Remove-Item -Recurse -Force "$setup\*"

# Install WuInstall
Invoke-Expression "cmd /C $systemdrive\chocolatey\bin\cinst wuinstall"

# Run WuInstall 
Invoke-Expression "cmd /C $systemdrive\chocolatey\bin\cinst wuinstall.run"
