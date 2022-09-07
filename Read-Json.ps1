#
# fuction read json from file
#
function ReadJson {
     [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Specify the path for json file")]
        [ValidateNotNullOrEmpty()]
        [string]$Json)

        $myJson = Get-Content $Json -Raw | ConvertFrom-Json 
     
        foreach ($Users in  $myJson)
        {        
            write "$($Users.name) has the email: $($Users.email)"
        }
}
