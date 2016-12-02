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
$objProperties = $iniContent["databases"].Properties;
$databases = @{}


foreach( $key in $iniContent["databases"].Keys)
{
    
    $databases[$key]="";
    foreach($key2 in $iniContent["scripts"].Keys)
    {
        if($iniContent["databases"][$key] -eq $key2)
        {
            $databases[$key]=$iniContent["scripts"][$key2]
        }
    }
    
}

$SQLServer = $iniContent["settings"]["server"]
$user =$iniContent["settings"]["user"]
$password = $iniContent["settings"]["password"]

Write-Output "Start dropping databases"
foreach($key in $databases.Keys)
{
    $result=$null;
    $result=invoke-sqlcmd -ServerInstance "$SQLServer" -Username "$user" -Password "$password" -Query  "SELECT name FROM master.sys.databases WHERE name = N'$key' ;"
    if(!$result)
    {
        Write-Output "$key does not exist"
    }
    else
    {
    Write-Output "Dropping $key"
    invoke-sqlcmd -Query "Drop database [$key];"
    }
}
#$SqlConnection = New-Object System.Data.SqlClient.SqlConnection
#$SqlConnection.ConnectionString = "Server = $SQLServer; Integrated Security = True; User ID = $user; Password = $password;"
#$SqlCmd = New-Object System.Data.SqlClient.SqlCommand
#$SqlCmd.Connection = $SqlConnection
#$SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
#$SqlAdapter.SelectCommand = $SqlCmd
#$DataSet = New-Object System.Data.DataSet


$second = $databases;

$first = $iniContent[1];

