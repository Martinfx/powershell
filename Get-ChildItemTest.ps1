
<# https://msendpointmgr.com/2020/03/17/manage-win32-applications-in-microsoft-intune-with-powershell/
# 1. create intune package 
# 2. upload intune package to intune store

# 1. New-IntuneWin32AppPackage
# 2. New-IntuneWin32AppRequirementRule
# 3. New-IntuneWin32AppIcon 
# 4. Add-IntuneWin32App and upload 
#>


function IntuneWin32AppTest {
    [CmdletBinding()]
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
                                    Write-Host $IntuneWinAppMetaData.ChildNodes
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
                                write $IntuneWinAppMetaData.ApplicationInfo.Name + " " + $IntuneWinAppMetaData.ApplicationInfo.MsiInfo.MsiProductVersion
                                write $IntuneWinAppMetaData.ApplicationInfo.MsiInfo.MsiPublisheronInfo.Name
                                

                              # Add-IntuneWin32App -FilePath $FilePath -DisplayName $DisplayName -Description $DisplayName -Publisher $Publisher -InstallExperience "system" -RestartBehavior "suppress" -DetectionRule $DetectionRule -ReturnCode $ReturnCode -Icon $Icon -Verbose

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

function Add-IntuneWin32App {
    <#
    .SYNOPSIS
        Create a new Win32 application in Microsoft Intune.

    .DESCRIPTION
        Create a new Win32 application in Microsoft Intune.

    .PARAMETER FilePath
        Specify a local path to where the win32 app .intunewin file is located.

    .PARAMETER DisplayName
        Specify a display name for the Win32 application.
    
    .PARAMETER Description
        Specify a description for the Win32 application.
    
    .PARAMETER Publisher
        Specify a publisher name for the Win32 application.

    .PARAMETER AppVersion
        Specify the app version for the Win32 application.
    
    .PARAMETER Developer
        Specify the developer name for the Win32 application.

    .PARAMETER Owner
        Specify the owner property for the Win32 application.

    .PARAMETER Notes
        Specify the notes property for the Win32 application.

    .PARAMETER InformationURL
        Specify the information URL for the Win32 application.
    
    .PARAMETER PrivacyURL
        Specify the privacy URL for the Win32 application.
    
    .PARAMETER CompanyPortalFeaturedApp
        Specify whether to have the Win32 application featured in Company Portal or not.

    .PARAMETER InstallCommandLine
        Specify the install command line for the Win32 application.
    
    .PARAMETER UninstallCommandLine
        Specify the uninstall command line for the Win32 application.

    .PARAMETER InstallExperience
        Specify the install experience for the Win32 application. Supported values are: system or user.
    
    .PARAMETER RestartBehavior
        Specify the restart behavior for the Win32 application. Supported values are: allow, basedOnReturnCode, suppress or force.
    
    .PARAMETER DetectionRule
        Provide an array of a single or multiple OrderedDictionary objects as detection rules that will be used for the Win32 application.

    .PARAMETER RequirementRule
        Provide an OrderedDictionary object as requirement rule that will be used for the Win32 application.

    .PARAMETER AdditionalRequirementRule
        Provide an array of OrderedDictionary objects as additional requirement rule, e.g. for file, registry or script rules, that will be used for the Win32 application.

    .PARAMETER ReturnCode
        Provide an array of a single or multiple hash-tables for the Win32 application with return code information.

    .PARAMETER Icon
        Provide a Base64 encoded string of the PNG/JPG/JPEG file.

    .NOTES

    #>
    [CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName = "MSI")]
    param(
        [parameter(Mandatory = $true, ParameterSetName = "MSI", HelpMessage = "Specify a local path to where the win32 app .intunewin file is located.")]
        [parameter(Mandatory = $true, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern("^[A-Za-z]{1}:\\\w+")]
        [ValidateScript({
            # Check if path contains any invalid characters
            if ((Split-Path -Path $_ -Leaf).IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0) {
                Write-Warning -Message "$(Split-Path -Path $_ -Leaf) contains invalid characters"; break
            }
            else {
            # Check if file extension is intunewin
                if ([System.IO.Path]::GetExtension((Split-Path -Path $_ -Leaf)) -like ".intunewin") {
                    return $true
                }
                else {
                    Write-Warning -Message "$(Split-Path -Path $_ -Leaf) contains unsupported file extension. Supported extension is '.intunewin'"; break
                }
            }
        })]
        [string]$FilePath,

        [parameter(Mandatory = $true, ParameterSetName = "MSI", HelpMessage = "Specify a display name for the Win32 application.")]
        [parameter(Mandatory = $true, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName,

        [parameter(Mandatory = $true, ParameterSetName = "MSI", HelpMessage = "Specify a description for the Win32 application.")]
        [parameter(Mandatory = $true, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        [string]$Description,

        [parameter(Mandatory = $true, ParameterSetName = "MSI", HelpMessage = "Specify a publisher name for the Win32 application.")]
        [parameter(Mandatory = $true, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        [string]$Publisher,

        [parameter(Mandatory = $false, ParameterSetName = "MSI", HelpMessage = "Specify the app version for the Win32 application.")]
        [parameter(Mandatory = $false, ParameterSetName = "EXE")]
        [string]$AppVersion = [string]::Empty,

        [parameter(Mandatory = $false, ParameterSetName = "MSI", HelpMessage = "Specify the developer name for the Win32 application.")]
        [parameter(Mandatory = $false, ParameterSetName = "EXE")]
        [string]$Developer = [string]::Empty,

        [parameter(Mandatory = $false, ParameterSetName = "MSI", HelpMessage = "Specify the owner property for the Win32 application.")]
        [parameter(Mandatory = $false, ParameterSetName = "EXE")]
        [string]$Owner = [string]::Empty,

        [parameter(Mandatory = $false, ParameterSetName = "MSI", HelpMessage = "Specify the notes property for the Win32 application.")]
        [parameter(Mandatory = $false, ParameterSetName = "EXE")]
        [string]$Notes = [string]::Empty,

        [parameter(Mandatory = $false, ParameterSetName = "MSI", HelpMessage = "Specify the information URL for the Win32 application.")]
        [parameter(Mandatory = $false, ParameterSetName = "EXE")]
        [ValidatePattern("(http[s]?|[s]?ftp[s]?)(:\/\/)([^\s,]+)")]
        [string]$InformationURL = [string]::Empty,

        [parameter(Mandatory = $false, ParameterSetName = "MSI", HelpMessage = "Specify the privacy URL for the Win32 application.")]
        [parameter(Mandatory = $false, ParameterSetName = "EXE")]
        [ValidatePattern("(http[s]?|[s]?ftp[s]?)(:\/\/)([^\s,]+)")]
        [string]$PrivacyURL = [string]::Empty,

        [parameter(Mandatory = $false, ParameterSetName = "MSI", HelpMessage = "Specify whether to have the Win32 application featured in Company Portal or not.")]
        [parameter(Mandatory = $false, ParameterSetName = "EXE")]
        [bool]$CompanyPortalFeaturedApp = $false,

        [parameter(Mandatory = $true, ParameterSetName = "EXE", HelpMessage = "Specify the install command line for the Win32 application.")]
        [ValidateNotNullOrEmpty()]
        [string]$InstallCommandLine,

        [parameter(Mandatory = $true, ParameterSetName = "EXE", HelpMessage = "Specify the uninstall command line for the Win32 application.")]
        [ValidateNotNullOrEmpty()]
        [string]$UninstallCommandLine,

        [parameter(Mandatory = $true, ParameterSetName = "MSI", HelpMessage = "Specify the install experience for the Win32 application. Supported values are: system or user.")]
        [parameter(Mandatory = $true, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("system", "user")]
        [string]$InstallExperience,

        [parameter(Mandatory = $true, ParameterSetName = "MSI", HelpMessage = "Specify the restart behavior for the Win32 application. Supported values are: allow, basedOnReturnCode, suppress or force.")]
        [parameter(Mandatory = $true, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("allow", "basedOnReturnCode", "suppress", "force")]
        [string]$RestartBehavior,

        [parameter(Mandatory = $true, ParameterSetName = "MSI", HelpMessage = "Provide an array of a single or multiple OrderedDictionary objects as detection rules that will be used for the Win32 application.")]
        [parameter(Mandatory = $true, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Specialized.OrderedDictionary[]]$DetectionRule,

        [parameter(Mandatory = $false, ParameterSetName = "MSI", HelpMessage = "Provide an OrderedDictionary object as requirement rule that will be used for the Win32 application.")]
        [parameter(Mandatory = $false, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Specialized.OrderedDictionary]$RequirementRule,

        [parameter(Mandatory = $false, ParameterSetName = "MSI", HelpMessage = "Provide an array of OrderedDictionary objects as additional requirement rule, e.g. for file, registry or script rules, that will be used for the Win32 application.")]
        [parameter(Mandatory = $false, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Specialized.OrderedDictionary[]]$AdditionalRequirementRule,

        [parameter(Mandatory = $false, ParameterSetName = "MSI", HelpMessage = "Provide an array of a single or multiple hash-tables for the Win32 application with return code information.")]
        [parameter(Mandatory = $false, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        [System.Collections.Hashtable[]]$ReturnCode,

        [parameter(Mandatory = $false, ParameterSetName = "MSI", HelpMessage = "Provide a Base64 encoded string of the PNG/JPG/JPEG file.")]
        [parameter(Mandatory = $false, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        [string]$Icon
    )
   # Begin {
        # Ensure required authentication header variable exists
        #if ($Global:AuthenticationHeader -eq $null) {
        #    Write-Warning -Message "Authentication token was not found, use Connect-MSIntuneGraph before using this function"; break
        #}
        #else {
        #    $TokenLifeTime = ($Global:AuthenticationHeader.ExpiresOn - (Get-Date).ToUniversalTime()).Minutes
        #    if ($TokenLifeTime -le 0) {
        #        Write-Warning -Message "Existing token found but has expired, use Connect-MSIntuneGraph to request a new authentication token"; break
        #    }
        #    else {
        #        Write-Verbose -Message "Current authentication token expires in (minutes): $($TokenLifeTime)"
        #    }
        #}

        # Set script variable for error action preference
        #$ErrorActionPreference = "Stop"
   # }
   # Process {
        try {
            # Attempt to gather all possible meta data from specified .intunewin file
            Write-Verbose -Message "Attempting to gather additional meta data from .intunewin file: $($FilePath)"
            #$IntuneWinXMLMetaData = Get-IntuneWin32AppMetaData -FilePath $FilePath -ErrorAction Stop

            if ($IntuneWinXMLMetaData -ne $null) {
                Write-Verbose -Message "Successfully gathered additional meta data from .intunewin file"

                # Generate Win32 application body data table with different parameters based upon parameter set name
                Write-Verbose -Message "Start constructing basic layout of Win32 app body"
                switch ($PSCmdlet.ParameterSetName) {
                    "MSI" {
                        # Determine the execution context of the MSI installer and define the installation purpose
                        $MSIExecutionContext = $IntuneWinXMLMetaData.ApplicationInfo.MsiInfo.MsiExecutionContext
                        $MSIInstallPurpose = "DualPurpose"
                        switch ($MSIExecutionContext) {
                            "System" {
                                $MSIInstallPurpose = "PerMachine"
                            }
                            "User" {
                                $MSIInstallPurpose = "PerUser"
                            }
                        }

                        # Handle special meta data variable values
                        $MSIRequiresReboot = $IntuneWinXMLMetaData.ApplicationInfo.MsiInfo.MsiRequiresReboot
                        switch ($MSIRequiresReboot) {
                            "true" {
                                $MSIRequiresReboot = $true
                            }
                            "false" {
                                $MSIRequiresReboot = $false
                            }
                        }

                        # Handle special parameter inputs
                        if (-not($PSBoundParameters["DisplayName"])) {
                            $DisplayName = $IntuneWinXMLMetaData.ApplicationInfo.Name
                        }
                        if (-not($PSBoundParameters["Description"])) {
                            $Description = $IntuneWinXMLMetaData.ApplicationInfo.Name
                        }
                        if (-not($PSBoundParameters["Publisher"])) {
                            $Publisher = $IntuneWinXMLMetaData.ApplicationInfo.MsiInfo.MsiPublisher
                        }
                        if (-not($PSBoundParameters["Developer"])) {
                            $Developer = [string]::Empty
                        }
                        
                        # Generate Win32 application body
                        $AppBodySplat = @{
                            "MSI" = $true
                            "DisplayName" = $DisplayName
                            "Description" = $Description
                            "Publisher" = $Publisher
                            "AppVersion" = $AppVersion
                            "Developer" = $Developer
                            "Owner" = $Owner
                            "Notes" = $Notes
                            "InformationURL" = $InformationURL
                            "PrivacyURL" = $PrivacyURL
                            "CompanyPortalFeaturedApp" = $CompanyPortalFeaturedApp
                            "FileName" = $IntuneWinXMLMetaData.ApplicationInfo.FileName
                            "SetupFileName" = $IntuneWinXMLMetaData.ApplicationInfo.SetupFile
                            "InstallExperience" = $InstallExperience
                            "RestartBehavior" = $RestartBehavior
                            "MSIInstallPurpose" = $MSIInstallPurpose
                            "MSIProductCode" = $IntuneWinXMLMetaData.ApplicationInfo.MsiInfo.MsiProductCode
                            "MSIProductName" = $DisplayName
                            "MSIProductVersion" = $IntuneWinXMLMetaData.ApplicationInfo.MsiInfo.MsiProductVersion
                            "MSIRequiresReboot" = $MSIRequiresReboot
                            "MSIUpgradeCode" = $IntuneWinXMLMetaData.ApplicationInfo.MsiInfo.MsiUpgradeCode
                        }
                        if ($PSBoundParameters["Icon"]) {
                            $AppBodySplat.Add("Icon", $Icon)
                        }
                        if ($PSBoundParameters["RequirementRule"]) {
                            $AppBodySplat.Add("RequirementRule", $RequirementRule)
                        }

                        $Win32AppBody = New-IntuneWin32AppBody @AppBodySplat
                        Write-Verbose -Message "Constructed the basic layout for 'MSI' Win32 app body type"
                    }
                    "EXE" {
                        # Generate Win32 application body
                        $AppBodySplat = @{
                            "EXE" = $true
                            "DisplayName" = $DisplayName
                            "Description" = $Description
                            "Publisher" = $Publisher
                            "AppVersion" = $AppVersion
                            "Developer" = $Developer
                            "Owner" = $Owner
                            "Notes" = $Notes
                            "InformationURL" = $InformationURL
                            "PrivacyURL" = $PrivacyURL
                            "CompanyPortalFeaturedApp" = $CompanyPortalFeaturedApp
                            "FileName" = $IntuneWinXMLMetaData.ApplicationInfo.FileName
                            "SetupFileName" = $IntuneWinXMLMetaData.ApplicationInfo.SetupFile
                            "InstallExperience" = $InstallExperience
                            "RestartBehavior" = $RestartBehavior
                            "InstallCommandLine" = $InstallCommandLine
                            "UninstallCommandLine" = $UninstallCommandLine
                        }
                        if ($PSBoundParameters["Icon"]) {
                            $AppBodySplat.Add("Icon", $Icon)
                        }
                        if ($PSBoundParameters["RequirementRule"]) {
                            $AppBodySplat.Add("RequirementRule", $RequirementRule)
                        }

                        $Win32AppBody = New-IntuneWin32AppBody @AppBodySplat
                        Write-Verbose -Message "Constructed the basic layout for 'EXE' Win32 app body type"
                    }
                }

                # Validate that correct detection rules have been passed on command line, only 1 PowerShell script based detection rule is allowed
                if (($DetectionRule.'@odata.type' -contains "#microsoft.graph.win32LobAppPowerShellScriptDetection") -and (@($DetectionRules).'@odata.type'.Count -gt 1)) {
                    Write-Warning -Message "Multiple PowerShell Script detection rules were detected, this is not a supported configuration"; break
                }
               
                # Add detection rules to Win32 app body object
                Write-Verbose -Message "Detection rule objects passed validation checks, attempting to add to existing Win32 app body"
                $Win32AppBody.Add("detectionRules", $DetectionRule)

                # Retrieve the default return codes for a Win32 app
                Write-Verbose -Message "Retrieving default set of return codes for Win32 app body construction"
                $DefaultReturnCodes = Get-IntuneWin32AppDefaultReturnCode

                # Add custom return codes from parameter input to default set of objects
                if ($PSBoundParameters["ReturnCode"]) {
                    Write-Verbose -Message "Additional return codes where passed as command line input, adding to array of default return codes"
                    foreach ($ReturnCodeItem in $ReturnCode) {
                        $DefaultReturnCodes += $ReturnCodeItem
                    }
                }

                # Add return codes to Win32 app body object
                Write-Verbose -Message "Adding array of return codes to Win32 app body construction"
                $Win32AppBody.Add("returnCodes", $DefaultReturnCodes)

                # Add additional requirement rules to Win32 app body object
                if ($PSBoundParameters["AdditionalRequirementRule"]) {
                    $Win32AppBody.Add("requirementRules", $AdditionalRequirementRule)
                }

                # Create the Win32 app
                Write-Verbose -Message "Attempting to create Win32 app using constructed body converted to JSON content"
                $Win32MobileAppRequest = Invoke-IntuneGraphRequest -APIVersion "Beta" -Resource "mobileApps" -Method "POST" -Body ($Win32AppBody | ConvertTo-Json)
                if ($Win32MobileAppRequest.'@odata.type' -notlike "#microsoft.graph.win32LobApp") {
                    Write-Warning -Message "Failed to create Win32 app using constructed body. Passing converted body as JSON to output."; break
                    Write-Output -InputObject ($Win32AppBody | ConvertTo-Json)
                }
                else {
                    Write-Verbose -Message "Successfully created Win32 app with ID: $($Win32MobileAppRequest.id)"

                    # Create Content Version for the Win32 app
                    Write-Verbose -Message "Attempting to create contentVersions resource for the Win32 app"
                    $Win32MobileAppContentVersionRequest = Invoke-IntuneGraphRequest -APIVersion "Beta" -Resource "mobileApps/$($Win32MobileAppRequest.id)/microsoft.graph.win32LobApp/contentVersions" -Method "POST" -Body "{}"
                    if ([string]::IsNullOrEmpty($Win32MobileAppContentVersionRequest.id)) {
                        Write-Warning -Message "Failed to create contentVersions resource for Win32 app"; break
                    }
                    else {
                        Write-Verbose -Message "Successfully created contentVersions resource with ID: $($Win32MobileAppContentVersionRequest.id)"

                        # Extract compressed .intunewin file to subfolder
                        $IntuneWinFilePath = Expand-IntuneWin32AppCompressedFile -FilePath $FilePath -FileName $IntuneWinXMLMetaData.ApplicationInfo.FileName -FolderName "Expand"
                        if ($IntuneWinFilePath -ne $null) {
                            # Create a new file entry in Intune for the upload of the .intunewin file
                            Write-Verbose -Message "Constructing Win32 app content file body for uploading of .intunewin file"
                            $Win32AppFileBody = [ordered]@{
                                "@odata.type" = "#microsoft.graph.mobileAppContentFile"
                                "name" = $IntuneWinXMLMetaData.ApplicationInfo.FileName
                                "size" = [int64]$IntuneWinXMLMetaData.ApplicationInfo.UnencryptedContentSize
                                "sizeEncrypted" = (Get-Item -Path $IntuneWinFilePath).Length
                                "manifest" = $null
                                "isDependency" = $false
                            }

                            # Create the contentVersions files resource
                            $Win32MobileAppFileContentRequest = Invoke-IntuneGraphRequest -APIVersion "Beta" -Resource "mobileApps/$($Win32MobileAppRequest.id)/microsoft.graph.win32LobApp/contentVersions/$($Win32MobileAppContentVersionRequest.id)/files" -Method "POST" -Body ($Win32AppFileBody | ConvertTo-Json)
                            if ([string]::IsNullOrEmpty($Win32MobileAppFileContentRequest.id)) {
                                Write-Warning -Message "Failed to create Azure Storage blob for contentVersions/files resource for Win32 app"
                            }
                            else {
                                # Wait for the Win32 app file content URI to be created
                                Write-Verbose -Message "Waiting for Intune service to process contentVersions/files request"
                                $FilesUri = "mobileApps/$($Win32MobileAppRequest.id)/microsoft.graph.win32LobApp/contentVersions/$($Win32MobileAppContentVersionRequest.id)/files/$($Win32MobileAppFileContentRequest.id)"
                                $ContentVersionsFiles = Wait-IntuneWin32AppFileProcessing -Stage "AzureStorageUriRequest" -Resource $FilesUri
                                
                                # Upload .intunewin file to Azure Storage blob
                                Invoke-AzureStorageBlobUpload -StorageUri $ContentVersionsFiles.azureStorageUri -FilePath $IntuneWinFilePath -Resource $FilesUri

                                # Retrieve encryption meta data from .intunewin file
                                $IntuneWinEncryptionInfo = [ordered]@{
                                    "encryptionKey" = $IntuneWinXMLMetaData.ApplicationInfo.EncryptionInfo.EncryptionKey
                                    "macKey" = $IntuneWinXMLMetaData.ApplicationInfo.EncryptionInfo.macKey
                                    "initializationVector" = $IntuneWinXMLMetaData.ApplicationInfo.EncryptionInfo.initializationVector
                                    "mac" = $IntuneWinXMLMetaData.ApplicationInfo.EncryptionInfo.mac
                                    "profileIdentifier" = "ProfileVersion1"
                                    "fileDigest" = $IntuneWinXMLMetaData.ApplicationInfo.EncryptionInfo.fileDigest
                                    "fileDigestAlgorithm" = $IntuneWinXMLMetaData.ApplicationInfo.EncryptionInfo.fileDigestAlgorithm
                                }
                                $IntuneWinFileEncryptionInfo = @{
                                    "fileEncryptionInfo" = $IntuneWinEncryptionInfo
                                }

                                # Create file commit request
                                $CommitResource = "mobileApps/$($Win32MobileAppRequest.id)/microsoft.graph.win32LobApp/contentVersions/$($Win32MobileAppContentVersionRequest.id)/files/$($Win32MobileAppFileContentRequest.id)/commit"
                                $Win32AppFileCommitRequest = Invoke-IntuneGraphRequest -APIVersion "Beta" -Resource $CommitResource -Method "POST" -Body ($IntuneWinFileEncryptionInfo | ConvertTo-Json)

                                # Wait for Intune service to process the commit file request
                                Write-Verbose -Message "Waiting for Intune service to process the commit file request"
                                $CommitFileRequest = Wait-IntuneWin32AppFileProcessing -Stage "CommitFile" -Resource $FilesUri
                                
                                # Update committedContentVersion property for Win32 app
                                Write-Verbose -Message "Updating committedContentVersion property with ID '$($Win32MobileAppContentVersionRequest.id)' for Win32 app with ID: $($Win32MobileAppRequest.id)"
                                $Win32AppFileCommitBody = [ordered]@{
                                    "@odata.type" = "#microsoft.graph.win32LobApp"
                                    "committedContentVersion" = $Win32MobileAppContentVersionRequest.id
                                }
                                $Win32AppFileCommitBodyRequest = Invoke-IntuneGraphRequest -APIVersion "Beta" -Resource "mobileApps/$($Win32MobileAppRequest.id)" -Method "PATCH" -Body ($Win32AppFileCommitBody | ConvertTo-Json)

                                # Handle return output
                                Write-Verbose -Message "Successfully created Win32 app and committed file content to Azure Storage blob"
                                $Win32MobileAppRequest = Invoke-IntuneGraphRequest -APIVersion "Beta" -Resource "mobileApps/$($Win32MobileAppRequest.id)" -Method "GET"
                                Write-Output -InputObject $Win32MobileAppRequest
                            }

                            # Cleanup extracted .intunewin file in Extract folder
                            Remove-Item -Path (Split-Path -Path $IntuneWinFilePath -Parent) -Recurse -Force -Confirm:$false | Out-Null
                        }
                    }                     
                }
            }
        }
        catch [System.Exception] {
            Write-Warning -Message "An error occurred while creating the Win32 application. Error message: $($_.Exception.Message)"
        }
    }
#}
