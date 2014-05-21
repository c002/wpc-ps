$trusted_users=@("BUILTIN\Rendszergazdák","BUILTIN\Administrators","NT AUTHORITY\SYSTEM","NT SERVICE\TrustedInstaller")
$dangerous_service_rights=@("FullControl","Write","Modify","ChangePermissions","WriteAttributes","WriteExtendedAttributes","AppendData","Delete")
$dangerous_registry_rights=@("FullControl")

<#
.SYNOPSIS
   Get Unprotected Service binaries
.DESCRIPTION
   Enumerates binaries referenced by services that can be modified by untrusted users
#>
function Get-UnprotectedServiceBinaries
{
	Begin
	{
	}
	Process
	{
		$services = get-wmiobject -query 'select * from Win32_Service';
		$paths=@()
		$services | ForEach-Object {
			$path=$_.PathName
			if ($path.StartsWith('"')){
				$parts=$path.Split('"')
				$p=$parts[1]
				if (!($paths -contains $p)){
					$paths+=$p
				}
			}else{
				$p=$path.Split(" ")[0]
				if (!($paths -contains $p)){
					$paths+=$p
				}
			}
		}

		$paths | ForEach-Object{
			$current_path=$_
			(Get-Acl $_).Access | ForEach-Object{
				$danger=$FALSE
				$_.FileSystemRights.ToString().Replace(" ","").Split(",") | ForEach-Object{
					if ($dangerous_service_rights -contains $_){
						$danger=$TRUE
					}
				}
				if  ($danger -and !($trusted_users -contains $_.IdentityReference) -and ($_.AccessControlType -eq "Allow")){
					echo $current_path
					echo $_.IdentityReference 
					echo $_.FileSystemRights
					echo $_.AccessControlType
				}
			}
		}
	}
	End
	{
	}
}

<#
.SYNOPSIS
   User owned Service keys
.DESCRIPTION
   Checks for Service descriptors in Registry which can be modified by untrusted users
#>
function Get-UserOwnedServiceKeys
{
	Begin
	{
	}
	Process
	{
		$services=Get-ChildItem -path hklm:\system\currentcontrolset\services\
		$services | ForEach-Object{
			$service=$_
			$service_access=$_.GetAccessControl().Access
			$service_access | ForEach-Object{
				$danger=$FALSE
				$_.RegistryRights.ToString().Replace(" ","").Split(",") | ForEach-Object{
					if ($dangerous_registry_rights -contains $_){
						$danger=$TRUE
					}
				}
				if  ($danger -and !($trusted_users -contains $_.IdentityReference) -and ($_.AccessControlType -eq "Allow")){
					echo $service.Name
					echo $_.IdentityReference 
					echo $_.RegistryRights
					echo $_.AccessControlType
				}
			}	
		}
	}
	End
	{
	}
}