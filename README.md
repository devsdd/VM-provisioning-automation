# VM-provisioning-automation
Old, pre-IaaS era automation to provision virtual machines on demand.

### Warning
This is old, unmaintained, legacy code.

### About
The web interface was build using C and HTML templates. Back-end shell scripts along with a MySQL database (needed to be setup separately) take care of the creating the VM, assigning an IP, booting it up, recording its details in the DB and emailing the user who requested it with its access details.

The package also contains a kickstart file to automate installation of Xen dom0 nodes and helper scripts for the dom0 admin to do a bunch of regular maintenance tasks (start all VM's, stop VM's, delete VM's, kill idle VNC sessions etc).
### Dependencies
### Xen
#### libflate (C-Library for HTML Templating)
#### cgic (C-Library that implements the CGI protocol)

