# What is PSubShell

`PSubShell` (the `P` is silent, so pronounced "subshell") is a PowerShell **script** that enters a subshell with local resources, similar in nature to a Python virtual environment (venv).

## What does that mean in layman's terms?

A subshell is a shell started from another shell, and isolates environmental changes to that instance.

```powershell
PS> $Foo
PS> Get-Location

Path
----
C:\workspace

PS> PSubShell -Initialize
PS> PSubShell
PowerShell 7.3.9
PS> New-Item scratch -ItemType Directory

    Directory: C:\workspace

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----          11/15/2023  5:36 PM                scratch

PS> Set-Location scratch
PS> $Foo = 'Bar'
PS> $Foo
Bar
PS> Get-Location

Path
----
C:\workspace\scratch

PS> exit
PS> $Foo
PS> Get-Location

Path
----
C:\workspace

PS> Get-ChildItem

    Directory: C:\workspace

Mode                 LastWriteTime         Length Name
----                 -------------         ------ ----
d----          11/15/2023  5:36 PM                scratch
-a---          11/15/2023  5:35 PM              4 .psubshell.deps.json
-a---          11/15/2023  5:35 PM              4 .psubshell.lock.json
PS>
```

Note how changing the location and setting a variable inside the subshell had no effect after you exited to the outer shell, but changes you made to disk did. This is how a subshell works. The majority of you are now thinking "but that's what pwsh does!". This is correct. If you leave the `PSubShell -Initialize` command out and used `pwsh` instead of `PSubShell` you'd have gotten the exact same behavior. So why `PSubShell`?

## Resource isolation

`PSubShell` allows you to "install" resources (modules, scripts and packages) "locally", meaning in the directory in which you ran `PSubShell -Initialize`. That's what the `.psubshell.deps.json` and `.psubshell.lock.json` (more details on these later) are all about. Let's demonstrate this by installing the `InvokeBuild` module.

```powershell
PS> Get-Command Invoke-Build
Get-Command: The term 'Invoke-Build' is not recognized as a name of a cmdlet, function, script file, or executable program.
Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
PS> PSubShell -AddResource InvokeBuild
PowerShell 7.3.9
PS> Get-Command Invoke-Build

CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Alias           Invoke-Build                                       5.10.4     InvokeBuild

PS> exit
PS> Get-Command Invoke-Build
Get-Command: The term 'Invoke-Build' is not recognized as a name of a cmdlet, function, script file, or executable program.
Check the spelling of the name, or if a path was included, verify that the path is correct and try again.
```

When we `PSubShell -AddResource InvokeBuild` it "installs" the module locally, in a `.psubshell` directory. Then when we enter a subshell with `PSubShell` it makes that module (and any other resource we add) available within that subshell. This is resource isolation.

## Why?

This makes it possible to "distribute" a "workspace" without needing to distribute any of the dependent resources. For instance, you could create a Zip archive with everything except the `.psubshell` directory and then send this Zip archive to someone else. They could then unzip the archive and enter the `PSubShell`, which would install the added resources local to where they unzipped.

A more common scenario would be to "distribute" the "workspace" as a version controlled repository using Git, with everything except the `.psubshell` directory committed. If you create a build script using a tool like `InvokeBuild` this script can now work without the need for having any dependencies installed locally. In fact, while there are plenty of other usages, this is such a common one that there's built-in support via `PSubShell -Initialize -InvokeBuild` which not only creates the environment, but also adds `InvokeBuild` as a dependency and provides a `build.ps1` script that bootstraps itself to run within the `PSubShell`.

```powershell
param(
    [Parameter(Position = 0)]
    [ValidateSet('?', '.')]
    [string[]]$Tasks = '.'
)

if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    ./PSubShell.ps1 -NoProfile -Command "Invoke-Build $Tasks $PSCommandPath" -Parameters $PSBoundParameters
    return
}

task . { Write-Build Green 'Hello world!' }
```
