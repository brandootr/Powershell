function global:get-adcomputerinfo{
Param(

   [Parameter(Mandatory=$true)]

   [string]$ComputerInfoFile)
#$ComputerInfoFile='c:\CC\Servers4.txt'
$header="<!DOCTYPE html>
<html>
<head>
<style>
.content {
  padding: 0 18px;
  background-color: white;
  max-height: 0;
  overflow: hidden;
  transition: max-height 0.2s ease-out;
}
.collapsible {
  background-color: #777;
  color: white;
  cursor: pointer;
  padding: 18px;
  width: 100%;
  border: none;
  text-align: left;
  outline: none;
  font-size: 15px;
}

.active, .collapsible:hover {
  background-color: #555;
}
.collapsible:after {
  content: '\002B';
  color: white;
  font-weight: bold;
  float: right;
  margin-left: 5px;
}

.active:after {
  content: ""\2212"";
}
ol.a {
  list-style-type: circle;
}

ol.b {
  list-style-type: square;
}

ol.c {
  list-style-type: upper-roman;
}

ol.d {
  list-style-type: lower-alpha;
}
</style>

</head>
<body>
"
$footscript='<script>
var coll = document.getElementsByClassName("collapsible");
var i;

for (i = 0; i < coll.length; i++) {
  coll[i].addEventListener("click", function() {
    this.classList.toggle("active");
    var content = this.nextElementSibling;
    if (content.style.maxHeight){
      content.style.maxHeight = null;
    } else {
      content.style.maxHeight = content.scrollHeight + "px";
    } 
  });
}
</script>
</body></html>
'
if ((test-path -Path $ComputerInfoFile) -eq $true) {
Clear-Content -Path $ComputerInfoFile
}
Add-Content -path $ComputerInfoFile -Value $header

$cnames=get-adcomputer -Filter * | select -expandProperty name

foreach ($cname in $cnames){
write-host "Accessing Server $cname"

# Run test to verify the server is available, if it is not it will be skipped

$connectiontest=Test-NetConnection $cname | select -ExpandProperty PingSucceeded

# Begin examining reachable Server

if ($connectiontest -eq $true){
$cinfo=Get-CimInstance -ComputerName $cname -ClassName Win32_OperatingSystem |
  Select-Object -Property BuildNumber,BuildType,OSType,ServicePackMajorVersion,ServicePackMinorVersion

$disks=@(Get-CimInstance -ComputerName $cname -ClassName Win32_LogicalDisk -Filter "DriveType=3" | select -property DeviceID,Size,FreeSpace)
$mem=(get-wmiobject Win32_ComputerSystem -ComputerName $cname | select -ExpandProperty TotalPhysicalMemory) / 1073741824
$mem=([Math]::Round($mem, 2))
$cputotal=@(Get-WmiObject -computername $cname –class Win32_processor | select -ExpandProperty Numberoflogicalprocessors)
$cores=$cputotal.length
$x=0
foreach($cpu in $cputotal){
$x= ($x + $cpu)
}
$cputotal = $x

$OStype=$cinfo | select -ExpandProperty BuildNumber
if ($ostype -eq 17763)
    {
    $ostype = "Server 2019"
    }
if ($ostype -eq 7601)
    {
    $ostype = "Server 2008 R2"
    }
if ($OStype -eq 14393)
    {
    $ostype="Server 2016"
    }
if ($ostype -eq  9600)
    {
    $ostype="Server 2012 R2"
    }


add-content -Path $ComputerInfoFile -Value "<h1><font color=red>$cname $ostype</font></h1>"
add-content -path $ComputerInfoFile -Value "<button class=""collapsible"">Info</button>`r`n<div class=""content""><ol class=""b"">"
add-content -Path $ComputerInfoFile -Value "<li>Total CPU Cores is <b>$cores</b></li>"
add-content -Path $ComputerInfoFile -Value "<li>Total Logical Processors is <b>$cputotal</b></li>"
foreach($d in $disks){
$dletter=$d.deviceid
$tsize= ($d.size / 1073741824)
$tsize= ([Math]::Round($tsize, 0))
$tfree= ($d.FreeSpace / 1073741824)
$tfree= ([Math]::Round($tfree, 0))
$diskstring='<li><b>' + $dletter + ' </b>Total Size <b>' + $tsize + ' </b>MB Free Space <b>' + $tfree + ' </b>MB</li>'
Add-Content -path $ComputerInfoFile -value $diskstring
}
#add-content -path $ComputerInfoFile -Value $diskinfo | ft
add-content -path $ComputerInfoFile -Value "<li>Total Memory <b>$mem</b> GB</li></ol></div>"
#add-content -path $ComputerInfoFile -Value $cpuinfo
#Add-Content -Path $ComputerInfoFile -Value "`r`n"
}





}
add-content -Path $ComputerInfoFile -Value $footscript
}

