Function Get-DiskInformation

    {

     Param(
          [Parameter(Mandatory=$true)]
       [string]$drive,

       [string]$computerName = $env:computerName

    ) #end param

     Get-WmiObject -class Win32_volume -computername $computername -filter “DriveLetter = ‘$drive'”

    } #end fun
