#Requires -PSEdition Core

<#PSScriptInfo

.VERSION 0.3.0

.GUID dbd31207-825d-4cdc-8e52-7c575e0ca5d9

.AUTHOR William E. Kempf

.COMPANYNAME

.COPYRIGHT Copyright (c) 2023 William E. Kempf. All rights reserved.

.TAGS InvokeBuild, shell, dependencies

.LICENSEURI https://github.com/wekempf/PSubShell/blob/main/LICENSE

.PROJECTURI https://github.com/wekempf/PSubShell/

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<# 

.DESCRIPTION 
 Creates a sub shell configured to use locally installed scripts, modules and packages. 

#> 
[CmdletBinding(DefaultParameterSetName = 'EnterShell')]
Param(
    [Parameter(ParameterSetName = 'EnterShell', Position = 0)]
    [string]$Command,

    [Parameter(ParameterSetName = 'EnterShell', Position = 1)]
    [hashtable]$Parameters,

    [Parameter(ParameterSetName = 'Initialize')]
    [switch]$Initialize,

    [Parameter(ParameterSetName = 'EnterShell')]
    [switch]$NoProfile,

    [Parameter(ParameterSetName = 'EnterShell')]
    [switch]$NoExit,

    [Parameter(ParameterSetName = 'Update')]
    [switch]$Update,

    [Parameter(ParameterSetName = 'AddResource')]
    [string]$AddResource,

    [Parameter(ParameterSetName = 'RemoveResource')]
    [string]$RemoveResource,

    [Parameter(ParameterSetName = 'AddResource')]
    [string]$Version,

    [Parameter(ParameterSetName = 'AddResource')]
    [string[]]$Repository,

    [Parameter(ParameterSetName = 'AddResource')]
    [switch]$Prerelease,

    [Parameter(ParameterSetName = 'AddResource')]
    [switch]$TrustRepository,

    [Parameter(ParameterSetName = 'CreateBuildScript')]
    [switch]$CreateBuildScript,

    [Parameter(ParameterSetName = 'CreateBuildScript', Position = 1)]
    [string]$Path = (Join-Path $PSScriptRoot 'build.ps1'),

    [Parameter(ParameterSetName = 'CreateBuildScript')]
    [switch]$Force
)

$PSubShell = @{
    Path = Join-Path $PSScriptRoot '.psubshell'
    DepsFile = Join-Path $PSScriptRoot '.psubshell.deps.json'
    LockFile = Join-Path $PSScriptRoot '.psubshell.lock.json'
}
$PSubShell.Deps = (Get-Content $PSubShell.DepsFile -ErrorAction SilentlyContinue |
        ConvertFrom-Json -AsHashtable) ?? @{ }
$PSubShell.Locks = (Get-Content $PSubShell.LockFile -ErrorAction SilentlyContinue |
        ConvertFrom-Json -AsHashtable) ?? @{ }

function script:GetParameters([hashtable]$Given, [string[]]$Include, [string[]]$Exclude) {
    $parms = @{}
    foreach ($kv in $Given.GetEnumerator()) {
        if ((-not $Include) -or ($Include -contains $kv.Key)) {
            if ((-not $Exclude) -or (-not ($Exclude -contains $kv.Key))) {
                $parms.Add($kv.Key, $kv.Value)
            }
        }
    }
    $parms
}

switch ($PSCmdlet.ParameterSetName) {
    'EnterShell' {
        if ($global:PSubShellInstance -eq $PSubShell.Path) {
            Write-Error 'Cannot reenter the same PSubShell.'
            return
        }
        $script = Join-Path ([IO.Path]::GetTempPath()) ((Get-Item .).Name + '.ps1')
        Set-Content $script @"
Set-Variable -Name OldPSubShellErrorAction -Value `$ErrorActionPreference -Scope Global
`$ErrorActionPreference = 'SilentlyContinue'
$PSCommandPath -Initialize
$Command $($Parameters.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" } | Join-String ' ')
`$PSubShellInstance = '$PSubShell.Path'
`$ErrorActionPreference = `$OldPSubShellErrorAction
Remove-Variable -Name Old -Scope Global
"@
        Invoke-Expression "pwsh -Interactive $(((-not $Command) -or $NoExit) ? '-NoExit' : '') $($NoProfile ? '-NoProfile' : '') -File $script"
    }

    'Initialize' {
        Write-Host 'Initializing PSubShell...'
        $env:PATH = (@($PSubShell.Path) + (
                $env:PATH -split [IO.Path]::PathSeparator |
                    Where-Object { $_ -ne "$PSubShell.Path" }
            )) -join [IO.Path]::PathSeparator
        $env:PSModulePath = (@($PSubShell.Path) + (
                $env:PSModulePath -split [IO.Path]::PathSeparator |
                    Where-Object { $_ -ne "$PSubShell.Path" }
            )) -join [IO.Path]::PathSeparator

        foreach ($kv in $PSubShell.Deps.GetEnumerator()) {
            $name = $kv.Key
            $type = $kv.Type
            $parms = GetParameters $kv.Value -Exclude 'Type', 'Version'
            $version = $PSubShell.Locks.$name.Version
            $resource = Find-PSResource -Name $name -Version $version `
                -ErrorAction SilentlyContinue @parms
            if ($type -eq 'Package') {
                $path = Join-Path $PSubShell.Path $name -AdditionalChildPath $version
                if (-not (Test-Path $path)) {
                    Save-PSResource -Name $name -Version $version -ErrorAction Continue `
                        -Path $PSSubShell.Path @parms
                }
                $toolsPath = Join-Path $path 'tools'
                if (Test-Path $toolsPath) {
                    $env:PATH = (@($toolsPath) + (
                            $env:PATH -split [IO.Path]::PathSeparator |
                                Where-Object { $_ -ne "$toolsPath" }
                        )) -join [IO.Path]::PathSeparator
                }
            }
            else {
            }
        }
    }

    'AddResource' {
        $name = $AddResource
        $parms = GetParameters $PSBoundParameters -Exclude 'AddResource'
        $resource = Find-PSResource -Name $name -ErrorAction Stop @parms |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1
        if (-not $resource) {
            Write-Error "Unable to find resource '$Name'."
            return
        }
        $parms.Type = $resource.Type.ToString() ?? 'Package'
        $PSubShell.Deps.$name = $parms
        $PSubShell.Locks.$name = @{
            Type = $resource.Type.ToString() ?? 'Package'
            Version = $resource.Version.ToString()
        }
        ConvertTo-Json $PSubShell.Deps | Set-Content $PSubShell.DepsFile
        ConvertTo-Json $PSubShell.Locks | Set-Content $PSubShell.LockFile
    }

    'RemoveResource' {
        $PSubShell.Deps.Remove($RemoveResource)
        $PSubShell.Locks.Remove($RemoveResource)
        ConvertTo-Json $PSubShell.Deps | Set-Content $PSubShell.DepsFile
        ConvertTo-Json $PSubShell.Locks | Set-Content $PSubShell.LockFile
    }

    'Update' {
        foreach ($kv in $PSubShell.Deps.GetEnumerator()) {
            $name = $kv.Key
            $parms = $kv.Value
            $resource = Find-PSResource -Name $name -ErrorAction SilentlyContinue @parms |
                Sort-Object -Property Version -Descending |
                Select-Object -First 1
            $PSubShell.Locks.$name = @{
                Type = $resource.Type.ToString() ?? 'Package'
                Version = $resource.Version.ToString()
            }
        }
        ConvertTo-Json $PSubShell.Locks | Set-Content $PSubShell.LockFile
    }

    'CreateBuildScript' {
        if ((-not $Force) -and (Test-Path $Path)) {
            Write-Error "File '$Path' already exists. Use -Force to overwrite."
            return
        }

        Set-Content -Path $Path -Value @'
param(
    [Parameter(Position = 0)]
    [ValidateSet('?', '.')]
    [string[]]$Tasks
)

if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    ./PSubShell.ps1 -NoProfile -Command "Invoke-Build" -Parameters $PSBoundParameters
    return
}

task . { Write-Build Green 'Hello world!' }
'@        
    }
}
