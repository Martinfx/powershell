#<
# Get-ChildrenItem example
#>

write  $PSVersionTable

$location = Get-Location
$path = $location.Path +"file.txt"

if(-not( Test-Path -Path $path)){
   New-Item -Path C:\file.txt
}
if([System.IO.File]::Exists($path))
{
    $file = Get-ChildItem -Path "C:\file.txt"
    
    write "---------------------"
    write $file.Name
    write $file.Mode
    write $file.Target
    write $file.Attributes
    write "---------------------"
    write $file.CreationTime
    write $file.CreationTimeUtc
    write "---------------------"
    write $file.Directory
    write "---------------------"
    write $file.DirectoryName
    write "---------------------"
    write $file.Exists
    write $file.FullName
}


# return names files,folder in folder
Get-ChildItem -name C:\file.txt

# retun all .ps1 files
Get-ChildItem -Path "C:\*" -Include *.ps1

# return from actual folder and subfolders all .txt file
get-childitem . -include *.txt -recurse -force
