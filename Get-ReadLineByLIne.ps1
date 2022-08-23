<#
 # Read file line by line 
 #>

$newstreamreader = New-Object System.IO.StreamReader("C:\Users\test\Documents\test.txt")
$eachlinenumber = 1
while (($readeachline =$newstreamreader.ReadLine()) -ne $null)
{
    Write-Host "$eachlinenumber  $readeachline"
    $eachlinenumber++
}
$newstreamreader.Dispose()

