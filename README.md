# WingetToMECM

## Overview

This is a proof of concept that facilitates the creation of MECM Applications using Winget. It is not intended for use in production environments.

When winget was released at Ignite in 2018 (I think?), my first thought was "I hope they build an integration into MECM, or at least give us a PowerShell module for this." Coming at this from the point of view of a guy who admins MEM and spends a lot of time packaging software, it would be pretty nice to be able to press a button in the console and walk through a wizard that would build an Application to install the latest version of 7-zip or Visual Studio Code using winget. 

A few years later, I still don't have my button. The intention of this module is to showcase what I, as an MEM admin, would like to be able to do with winget. 

## Goals

I had a few requirements in mind when writing this module.

*   It should be easy to use.
*   Applications created should always install the latest version of a package, they shouldn't need to be updated after creation unless the package being installed changes.
*   The module should be able to account for different versions of winget, depending on which is currently installed.
*   There should be no need to store content for Applications created with this module.

## Usage

Winget is not designed to be executed by the local system account. For that matter, it doesn't really seem to be built with automation like this as a primary focus. Therefore, Deployment Types must be configured to run as the current user or local system as appropriate for a given package based on how it behaves.

  
For packages that winget would normally install system-wide, configure the Deployment Type to run as System.  
For packages that are intended to be installed in the context of the current user, configure the deployment type to run as the current user.

  
In either condition, the Deployment Type may need to be configured to 'Allow users to view and interact with the program installation.' This is because not all packages respect the --silent flag during install/uninstall operations.

To determine which method to use, run `winget install [packageid]` as a user without administrative privileges.  
If the package's installer prompts for administrative elevation, set the Deployment Type to run as the local system. When elevation is not needed to complete the install, the Deployment Type must be configured to run as the current user.

Even when all of this is completed, some packages may still exhibit behavior that is 'unfriendly' to a Configuration Manager deployment. _Again, this is a proof of concept._

Once all of that is figured out, download the module in this repository and install it. **This module requires Administrative privileges to work properly.**

```powershell
import-module WingetToMECM.psm1
```

Next, use the Get-WingetMECMApplicationParameters function to get an object that will provide an InstallCommand, UninstallCommand, and DetectionRuleScript.

```powershell
$params = Get-WingetMECMApplicationParameters -PackageID 7zip.7zip
```

Lastly, we take the output and use it to create a new Application and "Script Installer" Deployment Type. Set-Clipboard will come in handy here. First we'll need the command lines that the Deployment Type will use for Install and Uninstall operations.

```powershell
$params.installcommand | set-clipboard
$params.uninstallcommand | set-clipboard
```

![](https://user-images.githubusercontent.com/27856660/160049717-57620eda-1cd1-44ee-a958-fdddc65ff58d.png)

Next, we need a detection rule. Get-WingetMECMApplicationParameters will generate a block of code that we can use as a PowerShell Script Detection Rule. (That's the cool part.)

```powershell
$params.DetectionRuleScript | Set-Clipboard
```

![](https://user-images.githubusercontent.com/27856660/160050194-0afa9f7e-1272-4b73-b221-817fed581b44.png)

If you want, you can also paste the contents of the DetectionRuleScript property right into the PowerShell ISE (that we're not supposed to use) to see what's going on. 

Finish creating the Deployment Type as you'd like. Be sure to read the notes above regarding whether to configure it to run as the Current User or Local System.

![](https://user-images.githubusercontent.com/27856660/160050627-98a48c8b-53ac-4e62-8383-06663b880a0f.png)

This will leave you with an Application that will always install the current version of the provided winget package. The Detection Rule will compare the installed version with what's available in the winget repository. 

If you deploy the Application as Available, users will be able to "Install" it again when a new version of the software is released and update to the latest version.

Deploying as Required would automatically keep the installed package up to date as the Deployment Rule script checks to ensure that the latest version is present.

## Summary

This thing works (at least as of right now with Microsoft.DesktopAppInstaller version 1.17.10271.0, which includes winget version 1.2.10271), but it would be really nice to have a native module that didn't have to wrap winget.exe and then do whacky stuff to parse the output. 

As this one sits, there are still manual steps needed that make it difficult to fully automate the creation of Applications. Imagine the possibilities if we could do things like run a simple command to detect if there's an update available for a given package, determine if a package should install as a user or system-wide, and easily download an icon for the installer. (I like a pretty Software Center).
