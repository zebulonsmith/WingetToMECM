<#######################################################################################################
This module is intended to be a proof of concept. Showing the viability of Winget integration with MECM.

It's not intended for use in a production environment. The goal is to show that using Winget to deploy
applications with MECM is very possible in its current state. The biggest challenge is creating a
detection rule for a deployment type as winget does not have an easy way to tell us if a package is
installed or needs updating.

Winget is not designed to be executed by the local system account. Therefore, Deployment Types must be
configured to run as the current user or local system as appropriate for a given package.
For packages that winget would normally install system-wide, configure the Deployment Type to run as System.
For packages that are intended to be installed in the context of the current user, configure the deployment
type to run as the current user.
In either condition, the Deployment Type may need to be  be configured to 'Allow users to view and interact
with the program installation.' This is because not all packages respect the --silent flag during
install/uninstall operations.

To determine which method to use, run 'winget install [packageid]' as a user without administrative privileges.
If the package's installer prompts for administrative elevation, set the Deployment Type to run as system. When
elevation is not needed to complete the install, the Deployment Type must be configured to run as the current user.

The Get-WingetMECMApplicationParameters function in this module will output an object that contains three
properties that can be used when creating an Application's Deployment Type.

InstallCommand - winget command to install the selected package
UninstallCommand - winget command to uninstall the selected package
DetectionRuleScript - The string in this property contains the code for a Powershell Script detection rule
that will detect the presence of the selected package

#######################################################################################################>





<#
.DESCRIPTION
Gets the path to winget.exe. We'll need to run winget as the local system account.
To do this, we'll use get-appxpackage to see if the "Microsoft.DesktopAppInstaller" package is installed.
Then, we'll look inside its installation path for winget.exe and return the full path.

Used primarily by other functions to make sure that winget exists, but could be ran on its own.

.EXAMPLE
Get-Wingetpath

#>
Function Get-Wingetpath {

    $wingetApp = Get-AppxPackage -allusers -Name "Microsoft.DesktopAppInstaller"

    if ($null -eq $wingetApp) {
        Throw "Microsoft.DesktopAppInstaller does not appear to be installed."
    }

    $wingetPath = "$($wingetApp.InstallLocation)\winget.exe"

    if (test-path -Path $wingetPath) {
        Return $wingetPath
    } else {
        Throw "Could not locate winget.exe in $($wingetApp.InstallLocation)"
    }

}

<#
.DESCRIPTION
Get package info from the WinGet repository by wrapping "winget show --id"
This function searches the winget repository for the specified package and returns info about it.
Used to get the currently available version of a package.

This function is here so that Get-MECMWingetApplicationParameters can use the code within to build a
MECM detection rule, but could be used on its own.

.PARAMETER PackageID
Package ID to search for. Use 'winget search' to look for packages if you need to find the ID

.EXAMPLE
Get-WingetApplicationDetails -PackageID "Microsoft.VisualStudioCode"
#>
Function Get-WingetApplicationDetails {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipeline=$true,
            HelpMessage="Winget Package ID to search for."
            )
        ]
        [string]
        $PackageID
    )


    Begin {
        #Verify that winget is present
        $wingetPath = Get-Wingetpath

        #Initiate the results to return
        $returnObject = @()
    }

    Process {
        #Execute winget show
        $wingetShow = & $wingetPath show --id $PackageID

        #Parse the results.
        $Result = $wingetShow[1]

        if ($Result -eq "No package found matching input criteria.")
        {#Didn't find any results for the provided ApplicationID

        } elseif (!( [STRING]::IsNullOrEmpty(($wingetShow | Where-Object {$_ -like "Store License Terms: *"})) ))
        {#Found a store app
            #Found a store app
            $version = ($wingetShow | Where-Object {$_ -like "Version:*"}).replace("Version:","").trim()
            $Publisher = ($wingetShow | Where-Object {$_ -like "Publisher:*"}).replace("Publisher: ","").trim()
            $PublisherURL = ($wingetShow | Where-Object {$_ -like "Publisher URL:*"}).replace("Publisher URL:","").trim()
            $Description = ($wingetShow | Where-Object {$_ -like "Description:*"}).replace("Description:","").trim()
            $Copyright = ($wingetShow | Where-Object {$_ -like "Copyright:*"}).replace("Copyright:","").trim()
            $Agreements = ($wingetShow | Where-Object {$_ -like "Agreements:*"}).replace("Agreements:","").trim()
            $Category = ($wingetShow | Where-Object {$_ -like "Category:*"}).replace("Category:","").trim()
            $Pricing = ($wingetShow | Where-Object {$_ -like "Pricing:*"}).replace("Pricing:","").trim()
            $FreeTrial = ($wingetShow | Where-Object {$_ -like "Free Trial:*"}).replace("Free Trial:","").trim()
            $TermsOfTransaction = ($wingetShow | Where-Object {$_ -like "Terms of Transaction:*"}).replace("Terms of Transaction:","").trim()
            $SeizureWarning = ($wingetShow | Where-Object {$_ -like "Seizure Warning:*"}).replace("Seizure Warning:","").trim()
            $StoreLicenseTerms = ($wingetShow | Where-Object {$_ -like "Store License Terms:*"}).replace("Store License Terms:","").trim()
            $InstallerType = ($wingetShow | Where-Object {$_ -like "  Type:*"}).replace("  Type:","").trim()
            #$InstallerLocale = ($wingetShow | Where-Object {$_ -like "  Locale:*"}).replace("  Locale:","").trim()
            #$InstallerDownloadURL = ($wingetShow | Where-Object {$_ -like "  Download URL:*"}).replace(  "Download URL:","").trim()
            #$InstallerSHA256 = ($wingetShow | Where-Object {$_ -like "  SHA256:*"}).replace(  "SHA256:","").trim()

            $ReturnObject += [PSCustomObject]@{
                Result = $Result
                ID = $PackageID
                Version = $version
                Publisher = $Publisher
                PublisherURL = $PublisherURL
                Description = $Description
                Copyright = $Copyright
                Agreements = $Agreements
                Category = $Category
                Pricing = $Pricing
                FreeTrial = $FreeTrial
                TermsOfTransaction = $TermsOfTransaction
                SeizureWarning = $SeizureWarning
                StoreLicenseTerms = $StoreLicenseTerms
                InstallerType = $InstallerType
                #InstallerLocale = $InstallerLocale
                #InstallerDownloadURL = $InstallerDownloadURL
                #InstallerSHA256 = $InstallerSHA256
            }
        } elseif ( ( [STRING]::IsNullOrEmpty(($wingetShow | Where-Object {$_ -like "Store License Terms: *"})) ) )
            {#Found a standard app
                $version = ($wingetShow | Where-Object {$_ -like "Version: *"}).replace("Version: ","").trim()
                $Publisher = ($wingetShow | Where-Object {$_ -like "Publisher: *"}).replace("Publisher: ","").trim()
                $PublisherURL = ($wingetShow | Where-Object {$_ -like "Publisher URL: *"}).replace("Publisher URL: ","").trim()
                #$Moniker = ($wingetShow | Where-Object {$_ -like "Moniker: *"}).replace("Moniker: ","").trim()
                $Description = ($wingetShow | Where-Object {$_ -like "Description: *"}).replace("Description: ","").trim()
                $Homepage = ($wingetShow | Where-Object {$_ -like "Homepage: *"}).replace("Homepage: ","").trim()
                $License = ($wingetShow | Where-Object {$_ -like "License: *"}).replace("License: ","").trim()
                #$LicenseURL = ($wingetShow | Where-Object {$_ -like "License URL: *"}).replace("License URL: ","").trim()
                #$PrivacyURL = ($wingetShow | Where-Object {$_ -like "Privacy URL: *"}).replace("Privacy URL: ","").trim()
                $InstallerType = ($wingetShow | Where-Object {$_ -like "  Type: *"}).replace("  Type: ","").trim()
                #$InstallerDownloadURL = ($wingetShow | Where-Object {$_ -like "  Download URL: *"}).replace(  "Download URL: ","").trim()
                #$InstallerSHA256 = ($wingetShow | Where-Object {$_ -like "  SHA256: *"}).replace(  "SHA256: ","").trim()

                $ReturnObject += [PSCustomObject]@{
                    Result = $Result
                    ID = $PackageID
                    Version = $version
                    Publisher = $Publisher
                    PublisherURL = $PublisherURL
                    Moniker = $Moniker
                    Description = $Description
                    Homepage = $Homepage
                    License = $License
                    #LicenseURL = $LicenseURL
                    #PrivacyURL = $PrivacyURL
                    InstallerType = $InstallerType
                    #InstallerDownloadURL = $InstallerDownloadURL
                    #InstallerSHA256 = $InstallerSHA256
                }
            }#End Found a standard app

    }


    End {
        return $ReturnObject
    }

}

<#
.DESCRIPTION
Get info about currently installed packages using winget --export and parsing the json output. Currently,
this is the only way to use winget to determine if an application is installed and what version it is. 

This function is here so that Get-MECMWingetApplicationParameters can use the code within to build a
MECM detection rule, but could be used on its own.

.PARAMETER outputDir
By default, this function will save a .json file to $env:temp and parse it there. If another location is desired,
this parameter can be used to choose a different path.

.PARAMETER PackageID
To return the result for a specific PackageID, specifiy it here. Otherwise, all installed packages will be returned.

.EXAMPLE
Get-WingetInstalledApps -PackageID "Microsoft.VisualStudioCode"
#>
Function Get-WingetInstalledApps {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory=$false,
            HelpMessage="Provide a path to save the json file output from winget export. %Temp% will be used by default."
        )]
        [STRING]
        $outputDir = $($env:temp),

        [Parameter(
            Mandatory=$false,
            HelpMessage="Filter the results to a specific PackageID"
        )]
        [STRING]
        $PackageID    )
    #Verify that winget is present
    $wingetPath = Get-wingetpath

    #Make sure that the output dir exists
    if (!(Test-path $outputDir)) {
        throw [System.AddIn.Hosting.InvalidPipelineStoreException]::New("Unable to access directory $outputDir")
    } else {
        $outFile = "$($outputDir)\WingetOutput$(Get-date -format FileDateTime).json"
    }

    <#
    Export info about the currently installed applications to a json file that we can parse.
    This is the only good way to get this information for now.
    #>
    Try {
        & $wingetPath export -o $outfile --include-versions | out-null
    } catch {
        Throw $_
    }

    #Winget Export produces a file containing application and version info for currently installed products
    If (! (Test-path $outFile)) {
        throw [System.IO.FileNotFoundException]::New("Unable to access exported file $outFile")
    } else {
        $wingetJson = Get-Content -Path $outFile | ConvertFrom-Json
    }

    #Import and parse the json
    $ReturnObject = @()
    Foreach ($jsonSource in $wingetJson.Sources) {
        $thisPackageSource = $jsonSource.SourceDetails.Name
        Foreach ($package in $jsonSource.packages) {
            $thisPackageIdentifier = $Package.PackageIdentifier
            $thisPackageVersion = $Package.Version

            $ReturnObject += [PSCustomObject]@{
                PackageIdentifier = $thisPackageIdentifier;
                PackageVersion = $thisPackageVersion;
                PackageSource = $thisPackageSource
            }
        }
    }

    if ($PackageID) {
        return $ReturnObject | Where-Object {$_.PackageIdentifier -eq $PackageID}
    } else {
        return $ReturnObject
    }
}

<#
.DESCRIPTION
This function will output an object that contains an install command line, uninstall command line and detection rule that
can be used to build an Application Deployment Type in MECM.

Winget is not designed to be executed by the local system account. Therefore, Deployment Types must be
configured to run as the current user or local system as appropriate for a given package.
For packages that winget would normally install system-wide, configure the Deployment Type to run as System.
For packages that are intended to be installed in the context of the current user, configure the deployment
type to run as the current user.
In either condition, the Deployment Type may need to be  be configured to 'Allow users to view and interact
ith the program installation.' This is because not all packages respect the --silent flag during
install/uninstall operations.

To determine which method to use, run 'winget install [packageid]' as a user without administrative priviledges.
If the package's installer prompts for administrative elevation, set the Deployment Type to run as system. When
elevation is not needed to complete the install, the Deployment Type must be configured to run as the curren user.

.PARAMETER PackageID
The PackageID for the winget package to install. Use Winget Search to find a PackageID to install.

.EXAMPLE
$parameters = Get-WingetMECMApplicationParameters -PackageID "Microsoft.VisualStudioCode"
$parameters.DetectionRuleScript | Set-Clipboard

#$parameters.InstallCommand - command line to use as the Install Program
#$parameters.UninstallCommand - command line to use as the Uninstall Program
#$parameters.DetectionRuleScript - The text in this property is a script that can be copy/pasted into a script detection rule
#>
Function Get-WingetMECMApplicationParameters {

    [CmdletBinding()]
    param (
        [Parameter()]
        [STRING]
        $PackageID
    )

    $AppParams = [PSCustomObject]@{
        InstallCommand = ""
        UninstallCommand = ""
        DetectionRuleScript = ""
    }

    #region Build Detection Rule
    <#
    Hold on, this is a wild ride. We're going to use get-command to get the code contained by the
    Get-WingetPath, Get-WingetInstalledApps and Get-WingetApplicationDetails functions in this module.
    Then we'll build the text of a script that will be added to the return object of this function.
    That script can be dropped into an MECM Deployment Type's detection rule.
    #>
    $RuleString = ""

    $RuleString += "Function Get-WingetPath {"
    $RuleString += (Get-command -Name Get-Wingetpath).ScriptBlock
    $RuleString += "}`n"


    $RuleString += "Function Get-WingetInstalledApps {"
    $RuleString += (Get-Command -Name Get-WingetInstalledApps).ScriptBlock
    $RuleString += "}`n"

    $RuleString += "Function Get-WingetApplicationDetails {"
    $RuleString += (Get-Command -Name Get-WingetApplicationDetails).ScriptBlock
    $RuleString += "}`n"

    $RuleString += @'
    $InstallStatus = Get-WingetInstalledApps -PackageId
'@
    $RuleString += " $($PackageID)`n"

    $RuleString += @'
    $appdetails = Get-WingetApplicationDetails -PackageId
'@

    $RuleString += " $($PackageID)`n"

    $RuleString += @'
    if ($appdetails.version -eq $InstallStatus.packageversion) {
        Return "Installed"
    }
'@
    $AppParams.DetectionRuleScript = $RuleString
    #endregion


    #region Command Lines
    <#
    We have to assume that the target device might have a different version of winget than what is on the one running this function.
    Install and Uninstall commands should find the path to the currently installed version of winget.
    #>

    $AppParams.InstallCommand = @'
echo start-process -filepath "$((Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller).installlocation)\winget.exe"
'@
    $AppParams.InstallCommand += " -argumentlist 'install --id $PackageID --silent --accept-package-agreements --accept-source-agreements'  | powershell.exe -command -"

    $AppParams.UninstallCommand = @'
echo start-process -filepath "$((Get-AppxPackage -AllUsers -Name Microsoft.DesktopAppInstaller).installlocation)\winget.exe"
'@
    $AppParams.UninstallCommand += " -argumentlist 'uninstall --id $PackageID --silent --accept-source-agreements' | powershell.exe -command -"


    #endregion

    Return $AppParams

}
