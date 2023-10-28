# PSubShell

`PSubShell` is a PowerShell **script** used to manage local (to a directory) module, script and package dependencies and to create subshells utilizing those dependencies. It's initial design was for use in build scripts (using InvokeBuild, PSake or other build scripts), allowing a script to run without the need to install tools globally (dependency isolation). It has usage scenarios broader than this, for instance to test out new modules without effecting your global environment.

## Quick Usage

From a directory in which you want to run a `PSubShell`.

```powershell
PS> Save-Script PSubShell
PS> ./PSubShell.ps1 -AddModule InvokeBuild
PS> ./PSubShell.ps1 -CreateBuildScript
PS> ./build.ps1
```

## Why a script?

`PSubShell` is a PowerShell script, not a module. This is in furtherance of the dependency isolation that is the core of it's design. Rather than being installed into the global environment, it's saved into the local environment. For build scripts this means that the `PSubShell.ps1` is saved alongside the build script and committed to source control. Consumers of the project now can run your build script without having to install any dependencies, including `PSubShell` on their machines.

That said, there are other uses for `PSubShell` and if you'd rather have access to it from anywhere on your machine, just save the script to a directory in your `$env:PATH`.

## Usage

`PSubShell` has a lot of parameter set variants, each designed for a specific operation.

### Entering a `PSubShell`

```powershell
PSubShell.ps1 [[-Command] <Object>] [-NoProfile] [-NoExit]
```

The default parameter set allows you to start a new subshell. When this subshell is entered the configured modules, scripts and packages are made available. An optional `Command` can be specified to be run. If a `Command` is specified, by default it is run in the subshell and then the subshell is exited. If you want to remain in the subshell after running the command, provide the `NoExit` switch as well. Commands can be specified either as a string or as a `[ScriptBlock]`.

By default profile scripts are also run when entering the subshell. This can be disabled by supplying the `NoProfile` switch.

### Initializing the Environment

```powershell
PSubShell.ps1 [-Initialize]
```

The operation is intended for use by `PSubShell` itself, to make the configured modules, scripts and packages available to the current shell. You can call this yourself, just be aware it will modify the current environment.

### Updating

```powershell
PSubShell.ps1 [-Update]
```

This updates the versions of all configured module, script and package dependencies to use the latest available. Note that his obeys the constraints originally supplied when adding the dependency. If you want to update the constraints, use one of the Add operations instead.

### AddModule

```powershell
PSubShell.ps1 [-AddModule] [-Name] <String> [-MinimumVersion <String>] [-MaximumVersion <String>] [-RequiredVersion <String>] [-Repository <String[]>] [-AllowPrerelease] [-AcceptLicense]
```

Adds a module to the `PSubShell` configuration. Modules are imported when a `PSubShell` is entered.

### RemoveModule

```powershell
PSubShell.ps1 [-RemoveModule] [-Name] <String>
```

Removes a module from the `PSubShell` configuration.

### AddScript

```powershell
PSubShell.ps1 [-AddScript] [-Name] <String> [-MinimumVersion <String>] [-MaximumVersion <String>] [-RequiredVersion <String>] [-Repository <String[]>] [-AllowPrerelease] [-AcceptLicense]
```

Adds a script to the `PSubShell` configuration. Aliases with the same name (sans the `.ps1` extension) are created when a `PSubShell` is entered. For instance if you add a script `Get-MyLocation` you will be able to directly execute the script with (surprise) `Get-MyLocation`. It also works to dot source the script using the alias. For instance if you add a script to `MyInvokeBuildTasks` you can dot source it in your `build.ps1` with `. MyInvokeBuildTasks`.

### RemoveScript

```powershell
PSubShell.ps1 [-RemoveScript] [-Name] <String>
```

Removes a script from the `PSubShell` configuration.

### AddPackage

```powershell
PSubShell.ps1 [-AddPackage] [-Name] <String> [-MinimumVersion <String>] [-MaximumVersion <String>] [-RequiredVersion <String>] [-Repository <String[]>] [-AllowPrerelease] [-AcceptLicense]
```

Adds a package to the `PSubShell`. If the package contains a `tools` directory (the primary purpose for this operation) then that directory is added to the `$env:PATH` when the `PSubShell` is entered.

### RemovePackage

```powershell
PSubShell.ps1 [-RemovePackage] [-Name] <String>
```

Removes a package from the `PSubShell` configuration.

### CreateBuildScript

```powershell
PSubShell.ps1 [-CreateBuildScript] [[-Path] <String>] [-Force]
```

Creates a new `build.ps1` script that uses `PSubShell.ps1` to call `Invoke-Build` recursively using the `build.ps1` script. For this to work you should also `./PSubShell.ps1 -AddModule InvokeBuild` to install `InvokeBuild` in the `PSubShell` used. Committing `PSubShell.ps1` and `build.ps1` would be all that's necessary for users to run the build script, without having any requirements for having `InvokeBuild` (or other dependencies you install in the `PSubShell`) installed.

This `build.ps1` can be modified to use what ever `task`s are appropriate for your needs. Pro tip: reuse tasks and helper functions within this build script by publishing them in scripts to a repository such as `PowerShell Gallery` or `GitHub Packages`, adding them to the `PSubShell` configuration and then dot sourcing the script with the alias supplied in the `PSubShell`.

### Detailed Explanation

When adding modules, scripts and packages using the `PSubShell.ps1` script it adds data to the `.psubshell.lock.json` (creating it if needed) including the parameters used while adding it and the latest version of the dependency found that satisfies any constraints given. Then when a `PSubShell` is entered the dependencies specified are installed locally in the `.psubshell` directory and then made available for use within the subshell. If being used within a version control repository `PSubShell.ps1` and the `.psubshell.lock.json` should be committed, but the `.psubshell` directory should be ignored and not added.
