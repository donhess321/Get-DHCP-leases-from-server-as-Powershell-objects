# Get-DHCP-leases-from-server-as-Powershell-objects

Queries the specified server via netsh.  Gets either the specified scope or all scopes for the server.  Then queries each scope for client DHCP leases.  All information is returned in a structured PS object that matches the relation in DHCP.

Usage: Get-DHCPLeasesFromServer.ps1 server.name.here

    Scope Object:
    Address        : 10.10.8.0
    SubnetMask     : 255.255.255.0
    State          : Active
    Name           : Workstations
    Comment        :
    ClientLeases   : {See example object below}
    ReservedLeases :
    Options        :

    ClientLeases Object
    IP           : 10.10.8.100
    SubnetMask   : 255.255.255.0
    MAC          : f4-c0-2f-fa-17-c7
    LeaseExpires : 10/13/2015 10:25:03 PM
    Type         : DHCP
    Name         : workstation104.domain1.com
 
This is a reposting from my Microsoft Technet Gallery.
