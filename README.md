# PSubShell

`PSubShell` is a PowerShell **script** used to manage local module, script and package dependencies and to create subshells utilizing those dependencies. It's initial design was for use in build scripts (using InvokeBuild, PSake or other build scripts), allowing a script to run without the need to install tools globally (dependency isolation). It has usage scenarios broader than this.

## Quick Usage

From a directory in which you want to run a `PSubShell`.

```powershell
PS> Save-Script PSubShell
PS> ./PSubShell.ps1 -AddModule InvokeBuild
PS> ./PSubShell.ps1 -CreateBuildScript
PS> ./build.ps1
```
