function watcher {
    param ($folder)

#if ($folder -eq $null) {
#$folder = read-host -Prompt "give me folder:" 
#}

# specify the path to the folder you want to monitor:
$Path = $folder

# specify which files you want to monitor
$FileFilter = '*'  

# specify whether you want to monitor subfolders as well:
$IncludeSubfolders = $true

# specify the file or folder properties you want to monitor:
$AttributeFilter = [IO.NotifyFilters]::FileName, [IO.NotifyFilters]::LastWrite, [IO.NotifyFilters]::DirectoryName

# specify the type of changes you want to monitor:
$ChangeTypes = [System.IO.WatcherChangeTypes]::Created, [System.IO.WatcherChangeTypes]::Deleted,
                 [System.IO.WatcherChangeTypes]::Renamed

# specify the maximum time (in milliseconds) you want to wait for changes:
$Timeout = 1000

# define a function that gets called for every change:
function Invoke-SomeAction
{
  param
  (
    [Parameter(Mandatory)]
    [System.IO.WaitForChangedResult]
    $ChangeInformation
  )
  
  Write-Warning 'Change detected:'
  $ChangeInformation | Out-String | Write-Host -ForegroundColor DarkYellow
  

  switch($ChangeInformation.ChangeType) {
      'Changed'  { "CHANGED" }
      'Created'  { "CREATED"
         $newpath = Join-Path $path $ChangeInformation.Name  
         write $newpath
         Copy-Item -Path $newpath -Destination C:\test2 -Recurse
      }
      'Deleted'  { "DELETED"}
      'Renamed'  { 
        # this executes only when a file was renamed
        $text = "File {0} was renamed to {1}" -f $ChangeInformation.OldName,  $ChangeInformation.Name
        Write-Host $text -ForegroundColor Yellow
      }
        
      # any unhandled change types surface here:
      default   { Write-Host $ChangeInformation.Name }
  }
}

try
{
  Write-Warning "FileSystemWatcher is monitoring $Path"
  
  # create a filesystemwatcher object
  $FileSystemWatcher = New-Object -TypeName IO.FileSystemWatcher -ArgumentList $Path, $FileFilter -Property @{
    IncludeSubdirectories = $IncludeSubfolders
    NotifyFilter = $AttributeFilter
  }

  #Register-ObjectEvent -InputObject $FileSystemWatcher -SourceIdentifier Monitoring1  -EventName Created  -Action {

  #$Object  = "{0} was  {1} at {2}" -f $Event.SourceEventArgs.FullPath,
  #$Event.SourceEventArgs.ChangeType,
  #$Event.TimeGenerated
  #write  -f $Event.SourceEventArgs.FullPath
 # Write-Host $Object -ForegroundColor Green
#}

  # start monitoring manually in a loop:
  do
  {
    # wait for changes for the specified timeout
    # IMPORTANT: while the watcher is active, PowerShell cannot be stopped
    # so it is recommended to use a timeout of 1000ms and repeat the
    # monitoring in a loop. This way, you have the chance to abort the
    # script every second.
    
    $result = $FileSystemWatcher.WaitForChanged($ChangeTypes, $Timeout)
    # if there was a timeout, continue monitoring:
    if ($result.TimedOut) { continue }
    
    Invoke-SomeAction -Change $result
    # the loop runs forever until you hit CTRL+C    
  } while ($true)
}
finally
{
  # release the watcher and free its memory:
  $watcher.Dispose()
  Write-Warning 'FileSystemWatcher removed.'
}

}
