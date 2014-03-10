# Nap time!
Start-Sleep 20

# Flush the DNS cache
Clear-DnsClientCache | Out-Null 

# Renew the DNS client registration
Register-DnsClient | Out-Null 

# Clear the arpcache
Invoke-Expression 'cmd /C netsh interface ip delete arpcache' | Out-Null 

# Get some packets flowing...
Invoke-Expression 'cmd /C start /WAIT ping google.com' | Out-Null 

# Get the temp environment variable
$temp = [System.Environment]::GetEnvironmentVariable('TEMP')

# Get the system drive environment variable
$systemdrive = [System.Environment]::GetEnvironmentVariable('SYSTEMDRIVE')

# Get program files environment variable
$programfiles = [System.Environment]::GetEnvironmentVariable('PROGRAMFILES')

# Install Chocolatey
Invoke-Expression (New-Object System.Net.Webclient).DownloadString('http://www.chocolatey.org/install.ps1')

# Install Puppet with Chocolatey
Invoke-Expression "cmd /C $systemdrive\chocolatey\bin\cinst puppet"

if ( Test-Path "$systemdrive\Program Files (x86)\Puppet Labs\Puppet\bin\facter.bat" ) {
  Set-Location "$systemdrive\Program Files (x86)\Puppet Labs\Puppet\bin"
  $virtual = Invoke-Expression "cmd /C facter virtual"

  # VMware?
  if ( $virtual -eq "vmware" ) {
    # Create a working directory
    $setup = "$temp\setup"
    if ( (Test-Path "$temp") -And !(Test-Path $setup) ) { 
      New-Item -type directory "$setup"
    } 

    # Set the PATH environment variable for VMware Tools
    [System.Environment]::SetEnvironmentVariable("PATH", $Env:Path + ";$programfiles\VMware\VMware Tools", "User")

    # Get the URI to the latest Windows x64 VMtools release
    $latest = (Invoke-WebRequest -UseBasicParsing -Uri "http://packages.vmware.com/tools/esx/5.5p01/windows/x64/index.html").Links | 
    Where-Object {$_.href.EndsWith('exe')} | Select -Expand href

    # Download VMware Tools
    Import-Module BitsTransfer
    Start-BitsTransfer -Source "http://packages.vmware.com/tools/esx/5.5p01/windows/x64/$latest" -Destination "$setup\vmtools.exe"

    # If the download was successful, install VMware Tools
    if ( Test-Path "$setup\vmtools.exe" ) { 
      Invoke-Expression "cmd /C start /WAIT $setup\vmtools.exe /S /v '/qn REBOOT=R ADDLOCAL=ALL'"
    }

    # Capture OVF runtime environment metadata
    if ( Test-Path "$programfiles\VMware\VMware Tools\vmtoolsd.exe" ) {
      Set-Location "$programfiles\VMware\VMware Tools"
      Invoke-Command { & cmd /C 'vmtoolsd.exe --cmd "info-get guestinfo.ovfEnv"' } | Add-Content -Encoding UTF8 "$setup\ovf-env.xml"
    }

    # Do the XSL transform and remove BOM
    if ( (Test-Path "$systemdrive\ProgramData\PuppetLabs\Facter\facts.d") -and (Test-Path "$setup\ovf-env.xml") ) {
      $yaml = "$systemdrive\ProgramData\PuppetLabs\Facter\facts.d\facts.yaml"
      $xsl = New-Object System.Xml.Xsl.XslCompiledTransform
      $xsl.Load([xml](New-Object System.Net.WebClient).DownloadString("https://raw.github.com/superfantasticawesome/provisioning/master/xml-to-yaml.xsl"))
      $xsl.Transform("$setup\ovf-env.xml", $yaml)
      # Get the contents of the YAM file and re-write it with ASCII encoding to remove the BOM
      if ( Test-Path $yaml ) {
        (Get-Content $yaml) | Set-Content $yaml
      }
    }

    # Rename the computer
    # Note that the "keys" array maps directly to my OVF custom properties. 
    # Adjust for your environment as required.
    if ( Test-Path "$setup\ovf-env.xml" ) {
      $currhostname = Invoke-Expression "cmd /C hostname"
      $keys = 'app_project', 'app_environment', 'app_role', 'app_id'
      $xml = New-Object -TypeName XML
      $xml.Load( "$setup\ovf-env.xml" )
      $newhostname = $xml.Environment.PropertySection.Property | 
        % -Begin { $h = @{} } -Process { $h[$_.Key] = $_.Value } -End { ($keys | %{ $h.$_ }) -Join '-' } 
      if ( "$newhostname" -ne "$currhostname" ) {
        Rename-Computer -NewName $newhostname -Force
      }
    }

    # Cleanup
    Remove-Item -Recurse -Force "$setup\*"

    # Install WuInstall
    Invoke-Expression "cmd /C $systemdrive\chocolatey\bin\cinst wuinstall"

    # Run WuInstall 
    Invoke-Expression "cmd /C $systemdrive\chocolatey\bin\cinst wuinstall.run"

    # Reboot 
    if ( Test-Path "$systemdrive\ProgramData\PuppetLabs\Facter\facts.d\facts.yaml" ) {
      Restart-Computer
    }  
  }
}
