Abstract
---------
This is a proof of concept for automatically provisioning Windows servers and bootstrapping them to a Puppet master in a vSphere/ESXi environment. To accomplish this, I configure OVF runtime environment metadata with VMware's OVFtool and capture and convert the metadata into Facter facts inside the guest OS. My lab environment includes the vSphere 5.5 trial; the MSDN version of Windows Server 2012 R2; the Windows Assessment and Deployment Kit 8.1;  Puppet 3.4.2... running inside VMware Workstation 10.  What follows is an overview of the steps.

Steps
---------

▪ Create an autounattend.xml answer file with the Windows Assessment and Deployment Kit and slipstream the answer file into the Windows Server 2012 R2 iso. Upload the iso to the ESXi datastore via the vCenter client.

▪ Create a new virtual machine in the vCenter client and attach the Windows Server iso to the cdrom/dvd drive and ensure it's connected at power on.

▪ After the VM is created -- and before it's powered on -- edit its settings and enable the vApp configuration (on the options tab). After enabling vApp options configure the transport method for delivering the OVF metadata... for our use case, choose the "VMware Tools" option.  

▪ Export the ovf package and save it in an accessible, yet secure location.

▪ Deployment consists of command line execution of the very awesome ovftool which allows for configuration of OVF custom properties on the fly... that is, during deployment of the OVF package.

▪ During the final sysprep pass, oobeSystem, Chocolatey is installed, which in turn installs Puppet. Additionally, we capture the OVF metadata and do an XSL transform on it to convert it to YAML for Facter to consume.


Conclusion
---------

The end result is a new Windows Server 2012 R2 virtual machine which is "tagged" as a specific node type (role; e.g. "web", "app", "db", etc) in a specific environment (e.g., staging, production, etc). With these coordinates, the Puppet master can apply the appropriate profile/s and configurations for a given node; that is, no-click provisioning and self-configuration without ever having logged into the newly provisioned guest OS.

Addendum
---------
For more information, please see: https://gist.github.com/superfantasticawesome/9257848
