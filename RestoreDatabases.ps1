param (
    [boolean]$upgradeOnly = $True
 )
Import-Module SQLPS -DisableNameChecking

function Get-IniContent ($filePath)
{#read an ini file and returns the content as an array
    $ini = @{}
    switch -regex -file $FilePath
    {
        “^\[(.+)\]” # Section
        {
            $section = $matches[1]
            $ini[$section] = @{}
            $CommentCount = 0
        }
        “^(;.*)$” # Comment
        {
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = “Comment” + $CommentCount
            $ini[$section][$name] = $value
        } 
        “(.+?)\s*=(.*)” # Key
        {
            $name,$value = $matches[1..2]
            $ini[$section][$name] = $value
        }
    }
    return $ini
}



function Get-Script-Directory 
{ 
$scriptInvocation = (Get-Variable MyInvocation -Scope 1).Value 
return Split-Path $scriptInvocation.MyCommand.Path 
} 
$scriptDirectory = Get-Script-Directory 
#load config.ini
$iniContent = Get-IniContent "$scriptDirectory\config.ini"
$databases = @{}
$SQLServer = $iniContent["settings"]["server"]
$user =$iniContent["settings"]["user"]
$password = $iniContent["settings"]["password"]

function Exists($databaseName)
{
   $result=$null;
    $result=invoke-sqlcmd -ServerInstance "$SQLServer" -Username "$user" -Password "$password" -Query  "SELECT name FROM master.sys.databases WHERE name = N'$databaseName' ;"
    if(!$result)
    {
        return $False
    }
    return $True
}

foreach( $key in $iniContent.Keys)
{
    if($key -like "database*")
    {
        $databases[$key]=$iniContent[$key];
        foreach($key2 in $iniContent["scripts"].Keys)
        {
            if($iniContent[$key]["type"] -eq $key2)
            {
                $databases[$key]["script"]=$iniContent["settings"]["scriptPath"]+"\"+$iniContent["scripts"][$key2]
            }
        }
        $databases[$key]["backup"]=$iniContent["settings"]["backupPath"]+"\"+$iniContent[$key]["backup"]
    }
}
$result=$databases["database1"];



if(!$upgradeOnly)
{
Write-Output "Start dropping databases"

foreach($key in $databases.Keys)
{
    $name=$databases[$key]["name"]
 
    if(Exists($name))
    {
        Write-Output "Dropping $name"
        Invoke-Sqlcmd -ServerInstance "$SQLServer" -Username "$user" -Password "$password" -Query "DECLARE @kill varchar(8000) = '';  SELECT @kill = @kill + 'kill ' + CONVERT(varchar(5), session_id) + ';'  FROM sys.dm_exec_sessions WHERE database_id  = db_id('$name') EXEC(@kill);"
        invoke-sqlcmd  -ServerInstance "$SQLServer" -Username "$user" -Password "$password" -Query "Drop database [$name];"
        
    }
    else
    {
        Write-Output "$name does not exist"
    }
}

Write-Output "Start restoring databases"
foreach($key in $databases.Keys)
{    
    $name=$databases[$key]["name"]
    $backup=$databases[$key]["backup"]
    Write-Output "Restoring $name"
    invoke-SqlCmd -ServerInstance "$SQLServer" -Username "$user" -Password "$password"  -querytimeout 0 –Query “RESTORE DATABASE [$name] FROM DISK='$backup'”
}
}
Write-Output "Start applying update scripts"
foreach($key in $databases.Keys)
{    
    $name=$databases[$key]["name"]
    if(Exists($name))
    {
        $script=$databases[$key]["script"]
        Write-Output "Applying $script to $name"
        invoke-SqlCmd -ServerInstance "$SQLServer" -database "$name" -Username "$user" -Password "$password" –InputFile "$script"
        
    }
    else
    {
        Write-Output "$name does not exist"
    }
}



