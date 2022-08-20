
<# https://msendpointmgr.com/2020/03/17/manage-win32-applications-in-microsoft-intune-with-powershell/
# 1. create intune package 
# 2. upload intune package to intune store

# 1. New-IntuneWin32AppPackage
# 2. New-IntuneWin32AppRequirementRule
# 3. New-IntuneWin32AppIcon 
# 4. Add-IntuneWin32App and upload 
#>


function IntuneWin32AppTest {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Specify the full path of the source folder where the setup file and all of it's potential dependency files reside.")]
        [ValidateNotNullOrEmpty()]
        [string]$SourceFolder,

        [parameter(Mandatory = $true, HelpMessage = "Specify the complete setup file name including it's file extension, e.g. Setup.exe or Installer.msi.")]
        [ValidateNotNullOrEmpty()]
        [string]$SetupFile,

        [parameter(Mandatory = $true, HelpMessage = "Specify the full path of the output folder where the packaged .intunewin file will be exported to.")]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFolder,

        [parameter(Mandatory = $false, HelpMessage = "Specify the full path to the IntuneWinAppUtil.exe file.")]
        [ValidateNotNullOrEmpty()]
        [string]$IntuneWinAppUtilPath = (Join-Path -Path $env:TEMP -ChildPath "IntuneWinAppUtil.exe")
    )
        # Trim trailing backslashes from input paths
        $SourceFolder = $SourceFolder.TrimEnd("\")
        $OutputFolder = $OutputFolder.TrimEnd("\")

        if (Test-Path -Path $SourceFolder) {
            Write-Verbose -Message "Successfully detected specified source folder: $($SourceFolder)"

            if (Test-Path -Path (Join-Path -Path $SourceFolder -ChildPath $SetupFile)) {
                Write-Verbose -Message "Successfully detected specified setup file '$($SetupFile)' in source folder"

                if (Test-Path -Path $OutputFolder) {
                    Write-Verbose -Message "Successfully detected specified output folder: $($OutputFolder)"

                    if (-not(Test-Path -Path $IntuneWinAppUtilPath)) {                      
                        if (-not($PSBoundParameters["IntuneWinAppUtilPath"])) {
                            # Download IntuneWinAppUtil.exe if not present in context temporary folder
                            Write-Verbose -Message "Unable to detect IntuneWinAppUtil.exe in specified location, attempting to download to: $($env:TEMP)"
                            Start-DownloadFile -URL "https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool/raw/master/IntuneWinAppUtil.exe" -Path $env:TEMP -Name "IntuneWinAppUtil.exe"

                            # Override path for IntuneWinApputil.exe if custom path was passed as a parameter, but was not found and downloaded to temporary location
                            $IntuneWinAppUtilPath = Join-Path -Path $env:TEMP -ChildPath "IntuneWinAppUtil.exe"
                        }
                    }

                    if (Test-Path -Path $IntuneWinAppUtilPath) {
                        Write-Verbose -Message "Successfully detected IntuneWinAppUtil.exe in: $($IntuneWinAppUtilPath)"

                        # Invoke IntuneWinAppUtil.exe with parameter inputs
                        $PackageInvocation = Invoke-Executable -FilePath $IntuneWinAppUtilPath -Arguments "-c ""$($SourceFolder)"" -s ""$($SetupFile)"" -o ""$($OutPutFolder)""" # -q
                        #try {
                        #$PackageInvocation = Start-Process -FilePath $IntuneWinAppUtilPath -ArgumentList "-c $($SourceFolder)"," -s $($SetupFile)"," -o $($OutPutFolder)"
                        #Write-Host $PackageInvocation.ExitCode
                        #}                      
                        #catch [System.Exception] {
                        #   Write-Warning -Message $_.Exception.Message; break  
                        #}
                        #$Arguments =  "-c ""$($SourceFolder)"" -s ""$($SetupFile)"" -o ""$($OutPutFolder)"""
                        #$ProcessOptions = @{
                        #        FilePath = $IntuneWinAppUtilPath
                        #        NoNewWindow = $true
                        #        Passthru = $true
                        #        ErrorAction = "Stop"
                        #}
                        #   if (-not([System.String]::IsNullOrEmpty($Arguments))) {
                        #        $ProcessOptions.Add("ArgumentList", $Arguments)
                        #}
                        
                        #$ProcessOptions.add("ArgumentList",  $Arguments)
                        # Invoke executable and wait for process to exit
                        #try {
                        #    $Invocation = Start-Process @ProcessOptions
                        #    $Handle = $Invocation.Handle
                        #    $Invocation.WaitForExit()
                        #catch [System.Exception] {
                        #     Write-Warning -Message $_.Exception.Message; break
                        #}  

                        if ($PackageInvocation -eq 0) {
                            $IntuneWinAppPackage = Join-Path -Path $OutputFolder -ChildPath "$([System.IO.Path]::GetFileNameWithoutExtension($SetupFile)).intunewin"
                            if (Test-Path -Path $IntuneWinAppPackage) {
                                Write-Verbose -Message "Successfully created Win32 app package object"

                                # Retrieve Win32 app package meta data
                                #$IntuneWinAppMetaData = Get-IntuneWin32AppMetaData -FilePath $IntuneWinAppPackage
                                $FilePath = (Get-ChildItem -Path *.intunewin -Recurse).FullName
                                            # Attemp to open compressed .intunewin archive file from parameter input
                                $IntuneWin32AppFile = [System.IO.Compression.ZipFile]::OpenRead($FilePath)
                          
                                                # Attempt to extract meta data from .intunewin file
                                 try {
                                    if ($IntuneWin32AppFile -ne $null) {
                                    # Determine the detection.xml file inside zip archive
                                    $DetectionXMLFile = $IntuneWin32AppFile.Entries | Where-Object { $_.Name -like "detection.xml" }
                    
                                    # Open the detection.xml file
                                    $FileStream = $DetectionXMLFile.Open()
    
                                    # Construct new stream reader, pass file stream and read XML content to the end of the file
                                    $StreamReader = New-Object -TypeName "System.IO.StreamReader" -ArgumentList $FileStream -ErrorAction Stop
                                    $IntuneWinAppMetaData = [xml]($StreamReader.ReadToEnd())
                    
                                    # Close and dispose objects to preserve memory usage
                                    $FileStream.Close()
                                    $StreamReader.Close()
                                    $IntuneWin32AppFile.Dispose()
                                    }
                                }
                                catch [System.Exception] {
                                        Write-Warning -Message "An error occurred while reading application information from detection.xml file. Error message: $($_.Exception.Message)"
                                }


                                # Construct output object with package details
                                $PSObject = [PSCustomObject]@{
                                    "Name" = $IntuneWinAppMetaData.ApplicationInfo.Name
                                    "FileName" = $IntuneWinAppMetaData.ApplicationInfo.FileName
                                    "SetupFile" = $IntuneWinAppMetaData.ApplicationInfo.SetupFile
                                    "UnencryptedContentSize" = $IntuneWinAppMetaData.ApplicationInfo.UnencryptedContentSize
                                    "Path" = $IntuneWinAppPackage
                                }
                                Write-Output -InputObject $PSObject
                            }
                            else {
                                Write-Warning -Message "Unable to detect expected '$($SetupFile).intunewin' file after IntuneWinAppUtil.exe invocation"
                            }
                        }
                        else {
                            Write-Warning -Message "Unexpect error occurred while packaging Win32 app. Return code from invocation: $($PackageInvocation)"
                        }
                    }
                    else {
                        Write-Warning -Message "Unable to detect IntuneWinAppUtil.exe in: $($IntuneWinAppUtilPath)"
                    }
                }
                else {
                    Write-Warning -Message "Unable to detect specified output folder: $($OutputFolder)"
                }
            }
            else {
                Write-Warning -Message "Unable to detect specified setup file '$($SetupFile)' in source folder: $($SourceFolder)"
            }
        }
        else {
            Write-Warning -Message "Unable to detect specified source folder: $($SourceFolder)"
        }
} 


function Start-DownloadFile {
    <#
    .SYNOPSIS
        Download a file from a given URL and save it in a specific location.

    .DESCRIPTION
        Download a file from a given URL and save it in a specific location.
    #>     
    param(
        [parameter(Mandatory = $true, HelpMessage = "URL for the file to be downloaded.")]
        [ValidateNotNullOrEmpty()]
        [string]$URL,

        [parameter(Mandatory = $true, HelpMessage = "Folder where the file will be downloaded.")]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [parameter(Mandatory = $true, HelpMessage = "Name of the file including file extension.")]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    Begin {
        # Set global variable
        $ErrorActionPreference = "Stop"

        # Construct WebClient object
        $WebClient = New-Object -TypeName System.Net.WebClient
    }
    Process {
        # Create path if it doesn't exist
        if (-not(Test-Path -Path $Path)) {
            New-Item -Path $Path -ItemType Directory -Force | Out-Null
        }

        # Register events for tracking download progress
        $Global:DownloadComplete = $false
        $EventDataComplete = Register-ObjectEvent $WebClient DownloadFileCompleted -SourceIdentifier WebClient.DownloadFileComplete -Action {$Global:DownloadComplete = $true}
        $EventDataProgress = Register-ObjectEvent $WebClient DownloadProgressChanged -SourceIdentifier WebClient.DownloadProgressChanged -Action { $Global:DPCEventArgs = $EventArgs }                

        # Start download of file
        $WebClient.DownloadFileAsync($URL, (Join-Path -Path $Path -ChildPath $Name))

        # Track the download progress
        do {
            $PercentComplete = $Global:DPCEventArgs.ProgressPercentage
            $DownloadedBytes = $Global:DPCEventArgs.BytesReceived
            if ($DownloadedBytes -ne $null) {
                Write-Progress -Activity "Downloading file: $($Name)" -Id 1 -Status "Downloaded bytes: $($DownloadedBytes)" -PercentComplete $PercentComplete
            }
        }
        until ($Global:DownloadComplete)
    }
    End {
        # Dispose of the WebClient object
        $WebClient.Dispose()

        # Unregister events used for tracking download progress
        Unregister-Event -SourceIdentifier WebClient.DownloadProgressChanged
        Unregister-Event -SourceIdentifier WebClient.DownloadFileComplete
    }
}

function Invoke-Executable {
    param(
        [parameter(Mandatory = $true, HelpMessage = "Specify the file name or path of the executable to be invoked, including the extension.")]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [parameter(Mandatory = $false, HelpMessage = "Specify arguments that will be passed to the executable.")]
        [ValidateNotNull()]
        [string]$Arguments
    )

    # Construct a hash-table for default parameter splatting
    $SplatArgs = @{
        FilePath = $FilePath
        NoNewWindow = $true
        Passthru = $true
        ErrorAction = "Stop"
    }

    # Add ArgumentList param if present
    if (-not([System.String]::IsNullOrEmpty($Arguments))) {
        $SplatArgs.Add("ArgumentList", $Arguments)
    }

    # Invoke executable and wait for process to exit
    try {
        $Invocation = Start-Process @SplatArgs
        $Handle = $Invocation.Handle
        $Invocation.WaitForExit()
    }
    catch [System.Exception] {
        Write-Warning -Message $_.Exception.Message; break
    }

    return $Invocation.ExitCode
} 
