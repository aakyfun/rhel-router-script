# rhel-router-script
Simple shell script to provision a NAT router with DNS and DHCP on RHEL. Intended for virtual machine labs.

## Details
The router ip address is set to '10.0.0.1'.  
The local domain name is called 'labnet'  

You must have only two NetworkManager connections:  
One for Internet (or another NAT connected to internet) and one connected to the LAN.
