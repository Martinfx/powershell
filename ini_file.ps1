

if (Get-Module -ListAvailable -Name IniManager) {
    Write-Host "Module exists"
} 
else {
    Write-Host "Module does not exist. I will install .."
    Install-Module -Name IniManager

}


if(Test-Path -Path "C:\test\test.ini" -Verbose ) {
    $obj = Get-Ini -Path C:\test\test.ini
    write $obj.{[owner]}.'name '
    write $obj.{[owner]}.'organization '

    write $obj.{[database]}.'file '
    write $obj.{[database]}.'port '
} else {
    write "File not exist! C:\test\test.ini"
}
    
if(Test-Path -Path C:\test.ini) {
   write "file exist!"
} 
else {
   New-Item -Path 'C:\test.ini' -ItemType File
}
    

