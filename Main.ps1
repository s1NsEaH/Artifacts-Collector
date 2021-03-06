$convertParams = @{ 
 PreContent = "<H1>$($env:COMPUTERNAME)</H1><p class='footer'>$(get-date)</p>" 
 PostContent = "<p class='footer'>$(get-date)</p>"
 head = @"
 <Title>Event Log Report</Title>
<style>
body { background-color:#E5E4E2;
       font-family:Tahoma;
       font-size:10pt; }
td, th { border:0px solid black; 
         border-collapse:collapse;
         white-space:pre; }
th { color:white;
     background-color:black; }
table, tr, td, th { padding: 2px; margin: 0px ;white-space:pre; }
tr:nth-child(odd) {background-color: lightgray}
table { width:95%;margin-left:5px; margin-bottom:20px;}
h2 {
 font-family:Tahoma;
 color:#6D7B8D;
}
.alert {
 color: red; 
 }
.footer 
{ color:green; 
  margin-left:10px; 
  font-family:Tahoma;
  font-size:8pt;
  font-style:italic;
}
</style>
"@
}

Set-ExecutionPolicy bypass
$ErrorActionPreference = "SilentlyContinue"
$invocation = (Get-Variable MyInvocation).Value 
$scriptPath = Split-Path $invocation.MyCommand.Path 

$ModuleList = dir "$scriptPath\*.psm1"
foreach($module in $ModuleList)
{
    Import-Module ($scriptPath + '\' + $module.Name)
}
[array]$ForensicData = $null
$funCtionList = @("Get-AppCompatCache", "Get-Persisted", "Get-Layers", "Get-MuiCache", "Get-Prefetch", "Get-RecentFileCache", "Get-UserAssist", "Get-JumpList", "Get-ShellBags")

foreach($funC in $funCtionList)
{
    $ForensicData += &$funC
}
$ForensicData = $ForensicData | Where-Object { $_.Path -ne $null }

$convertParams.add("body",$html.InnerXml)
$ForensicData | Where-Object { $_.LastModifiedTime -gt "2020-01-13"} | Sort-Object LastModifiedTime | convertto-html @convertParams | out-file C:\ForensData.html

[array]$ForensicDataFile = $null
$funCtionList = @("Get-RecentFile", "Get-Autoruns")
foreach($funC in $funCtionList) {
    $ForensicDataFile += &$funC
}
$ForensicDataFile | convertto-html @convertParams | out-file C:\ForensFile.html
Get-ConUSB | convertto-html @convertParams | out-file C:\ForensUSB.html