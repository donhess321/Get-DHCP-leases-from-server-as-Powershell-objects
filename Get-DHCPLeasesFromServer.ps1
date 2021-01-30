#==============================================================================================
# NAME: 	Get-DHCPLeasesFromServer.ps1
# AUTHOR:	Don Hess
# DATE: 	2015-10-12
# REV:		1.0
# PSVer:	2.0
# COMMENT: 	
# Get scope info and  client leases for the specified DHCP scopes.
# Returns an array of scope objects
#
# REVISION HISTORY:
# 1.0		Release
# 
# TODO: Reserved IPs, Some scope options under Option 51
# 
#==============================================================================================

param	( [string] $sDhcpServer = "server.name.here" # FQDN
		# Enter each Scope you want to search into an array: @('192.168.1.0','etc').  
		# Enter @('*') to search all scopes on the server
		, [array]  $arrSearchScopes = @('*') 
		)

function DhcpScopeFactory( [int] $iCount=1 ) {
	# Create a DhcpScope object(s)
	# Input:  Number of dhcp scope objects needed
	# Returns: Array of blank dhcp scope objects
	$arrReturned = @()
	for ($i = 0; $i -lt $iCount; $i++) {
		$oReturned = New-Object -TypeName System.Management.Automation.PSObject
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name Address -Value $null
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name SubnetMask -Value $null
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name State -Value $null
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name Name -Value $null
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name Comment -Value $null
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name ClientLeases -Value $null
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name ReservedLeases -Value $null
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name Options -Value $null

		$arrReturned += $oReturned
	}
	return ,$arrReturned
}
function ClientLeaseFactory( [int] $iCount=1 ) {
	# Create a ClientLease object(s)
	# Input:  Number of client lease objects needed
	# Returns: Array of blank client lease objects
	$arrReturned = @()
	for ($i = 0; $i -lt $iCount; $i++) {
		$oReturned = New-Object -TypeName System.Management.Automation.PSObject
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name IP -Value $null
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name SubnetMask -Value $null
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name MAC -Value $null
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name LeaseExpires -Value $null
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name Type -Value $null
		Add-Member -InputObject $oReturned -MemberType NoteProperty -Name Name -Value $null
		$arrReturned += $oReturned
	}
	return ,$arrReturned
}
function Get-LeaseType( $LeaseType ) {
	# Input  : The Lease type in one Char
	# Output  : The Lease type description
	# Description : This function translates a Lease type Char to it's relevant Description
	Switch($LeaseType) {
		"N" { return "None" }
		"D" { return "DHCP" }
		"B" { return "BOOTP" }
		"U" { return "UNSPECIFIED" }
		"R" { return "RESERVATION IP" } 
	}
}
function Parse-NetshScopeResults( [array] $arrQueryBlob=@() ) {
	# Parse a entire result of the Netsh DHCP scope query
	# Input: Array of the query results split at end of line
	# Returns: Array of ClientLease objects
	
	# Need column start location for Name and Comment from header
	$arrRegPrepHeader = @("(?<Garbage>^Scope Address\s+-\sSubnet\sMask\s+-\sState\s+-\s)")
	$arrRegPrepHeader += "(?<ScopeNameAndComment>.*)"
	$regHeader = [regex] ($arrRegPrepHeader -join '')
	
	# Looking for IP/Subnet like '10.3.4.60      - 255.255.248.0'
	$arrRegPrep = @("(?<Address>^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})")
	$arrRegPrep += "\s+-\s" # Garbage
	$arrRegPrep += "(?<SubnetMask>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"
	$arrRegPrep += "\s+-" # Garbage
	$arrRegPrep += "(?<State>\w+)"
	$arrRegPrep += "\s+-" # Garbage
	$arrRegPrep += "(?<ScopeNameAndComment>.*)"
	$regLine = [regex] ($arrRegPrep -join '')
	$iCommentCol = 0
	$arrReturned = @()
	$arrQueryBlob | ForEach-Object {
		$sCurLine = $_.trim()
		$matches = $null
		if ( $sCurLine -match $regLine ) {
			$oDhcpScope = (DhcpScopeFactory)[0]
			$oDhcpScope.Address = $matches.Address
			$oDhcpScope.SubnetMask = $matches.SubnetMask
			$oDhcpScope.State = $matches.State
			# Use the header column locations to split up the Name/Comment
			$sName = $matches.ScopeNameAndComment.Substring(0,$iCommentCol).trim()
			$sComment = $matches.ScopeNameAndComment.Substring($iCommentCol).trim().trim('-')
			$oDhcpScope.Name = $sName
			$oDhcpScope.Comment = $sComment
			$arrReturned += $oDhcpScope
		}
		else {
			if ( $sCurLine -match $regHeader ) {
				# There is only one hyphen in ScopeNameAndComment HEADER at this point
				# Note the header still has a leading space, this is OK.
				$iCommentCol = $matches.ScopeNameAndComment.IndexOf('-')
			}
		}
	}
	return ,$arrReturned
} # End Parse-NetshScopeResults
function Parse-NetshClientLeaseResults( [array] $arrQueryBlob=@() ) {
	# Parse a entire result of the Netsh DHCP client lease query
	# Input: Array of the query results split at end of line
	# Returns: Array of ClientLease objects
	
	# Looking for IP/Subnet like '10.3.4.60      - 255.255.248.0'
	# Looking for MAC address like '51-de-75-aa-ad-f5'.  First pattern repeats 5 times, then last pattern.
	# Looking for date like '10/10/2015 4:16:19 AM'
	# Looking for type like '  -D- '
	$arrRegPrep = @("(?<IP>^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})")
	$arrRegPrep += "\s+-\s" # Garbage
	$arrRegPrep += "(?<SubnetMask>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})"
	$arrRegPrep += "\s+-\s" # Garbage
	$arrRegPrep += "(?<MAC>([0-9,a-f]{2}-){5}[0-9,a-f]{2})"
	$arrRegPrep += "\s+-" # Garbage
	$arrRegPrep += "(?<LeaseExpires>\d{1,2}\/\d{1,2}\/\d{4}\s\d{1,2}\:\d{1,2}\:\d{1,2}\s[A,P]M)"
	$arrRegPrep += "\s+-" # Garbage
	$arrRegPrep += "(?<Type>\w{1})"
	$arrRegPrep += "-\s+" # Garbage
	$arrRegPrep += "(?<Name>\S+)"
	# Update this section for IPv6
	# IPv6 max format (39 hex char)
	# xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx:xxxx

	# Use .NET regex as it should be faster
	$regLine = [regex] ($arrRegPrep -join '')
	$arrReturned = @()
	$arrQueryBlob | ForEach-Object {
		$matches = $null
		if ( $_ -match $regLine ) {
			$oClientLease = (ClientLeaseFactory)[0]
			$oClientLease.IP = $matches.IP
			$oClientLease.SubnetMask = $matches.SubnetMask
			$oClientLease.MAC = $matches.MAC
			$oClientLease.LeaseExpires = [datetime] $matches.LeaseExpires
			$oClientLease.Type = Get-LeaseType $matches.Type
			$oClientLease.Name = $matches.Name.Trim()
			$arrReturned += $oClientLease
		}
	}
	return ,$arrReturned
} # End Parse-ClientLeaseResults


#########################################################################################
#                                      MAIN
#########################################################################################
# Get DHCP scopes
$arrNetshScope = @(netsh dhcp server \\${sDhcpServer} show scope)
$arrScopesTemp = Parse-NetshScopeResults $arrNetshScope
$arrScopes = @()
if ( $arrSearchScopes[0] -ne '*' ) {
	# Search only a subset of scopes
	$arrScopesTemp | ForEach-Object {
		if ( $arrSearchScopes -contains $_.Address ) {
			$arrScopes += $_
		}
	}
	if ( $arrScopes.Count -eq 0 ) {
		Write-Host "None of the requested Scopes and the server's Scopes overlap"
		$textout = $arrSearchScopes -join ", "
		Write-Host "Requested Scopes are: $textout" 
		break
	}
}
else {
	$arrScopes = $arrScopesTemp
	Remove-Variable arrScopesTemp
}

for ($i = 0; $i -lt $arrScopes.count; $i++) {
	$oCurScope = $arrScopes[$i]
	if ($oCurScope.State -ne 'Active') {
		continue
	}
	# Get DHCP client leases and add to the scope
	$arrNetshClientLeases = @(netsh dhcp server \\${sDhcpServer} scope $oCurScope.Address show clients 1)
	$oCurScope.ClientLeases = Parse-NetshClientLeaseResults $arrNetshClientLeases
	#$sNetshScopeDuration = (netsh dhcp server \\${sDhcpServer} scope 10.24.8.0 show option)
}
return ,$arrScopes


