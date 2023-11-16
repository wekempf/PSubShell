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

    [Parameter(ParameterSetName = 'EnterShell')]
    [hashtable]$Parameters = @{},

    [Parameter(ParameterSetName = 'EnterShell')]
    [switch]$NoProfile,

    [Parameter(ParameterSetName = 'EnterShell')]
    [switch]$NoExit,

    [Parameter(ParameterSetName = 'Initialize', Mandatory)]
    [switch]$Initialize,

    [Parameter(ParameterSetName = 'Initialize')]
    [switch]$Isolated,

    [Parameter(ParameterSetName = 'Initialize')]
    [switch]$InvokeBuild,

    [Parameter(ParameterSetName = 'Apply', Mandatory)]
    [switch]$Apply,

    [Parameter(ParameterSetName = 'AddResource', Mandatory)]
    [string]$AddResource,

    [Parameter(ParameterSetName = 'AddResource')]
    [string]$Version,

    [Parameter(ParameterSetName = 'AddResource')]
    [switch]$Prerelease,

    [Parameter(ParameterSetName = 'AddResource')]
    [string]$Repository,

    [Parameter(ParameterSetName = 'RemoveResource')]
    [string]$RemoveResource,

    [Parameter(ParameterSetName = 'Update', Mandatory)]
    [switch]$Update,

    [Parameter(ParameterSetName = 'Configure', Mandatory)]
    [switch]$Configure,

    [Parameter(ParameterSetName = 'Configure')]
    [string[]]$AddPath,

    [Parameter(ParameterSetName = 'Configure')]
    [string[]]$AddModulePath,

    [Parameter(ParameterSetName = 'Configure')]
    [hashtable]$AddVariable,

    [Parameter(ParameterSetName = 'Configure')]
    [hashtable]$AddEnvironmentVariable
)

for ($path = Get-Location; $path; $path = Split-Path $path) {
    if ($Initialize -or (Test-Path (Join-Path $path '.psubshell.json'))) {
        $PSubShell = @{
            Path = $path
            ConfigFile = Join-Path $path '.psubshell.json'
            LockFile = Join-Path $path '.psubshell.lock.json'
        }
        $PSubShell.Config = (Get-Content $PSubShell.ConfigFile -ErrorAction SilentlyContinue |
                ConvertFrom-Json -AsHashtable) ?? @{ Resources = @{ } }
        $PSubShell.Locks = (Get-Content $PSubShell.LockFile -ErrorAction SilentlyContinue |
                ConvertFrom-Json -AsHashtable) ?? @{ }
        break
    }
}

if (-not $PSubShell) {
    Write-Error 'No PSubShell initialized.'
    return
}

switch ($PSCmdlet.ParameterSetName) {
    'Initialize' {
        if ((-not $PSBoundParameters.ContainsKey('Isolated')) -and $InvokeBuild) {
            $Isolated = $True
        }
        if ($ISolated) {
            Save-PSResource -Name PSubShell -Path . -IncludeXml -WarningAction SilentlyContinue
            Remove-Item PSubShell_InstalledScriptInfo.xml
        }
        if ($InvokeBuild) {
            $resource = Find-PSResource InvokeBuild -ErrorAction Stop
            $PSubShell.Config.Resources.InvokeBuild = @{ Type = $resource.Type.ToString() }
            $PSubShell.Locks.InvokeBuild = @{ Type = $resource.Type.ToString(); Version = $resource.Version.ToString() }
            if ($Isolated) {
                Set-Content -Path 'build.ps1' -Value @'
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
'@
            }
            else {
                Set-Content -Path 'build.ps1' -Value @'
param(
    [Parameter(Position = 0)]
    [ValidateSet('?', '.')]
    [string[]]$Tasks = '.'
)

if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    PSubShell -NoProfile -Command "Invoke-Build $Tasks $PSCommandPath" -Parameters $PSBoundParameters
    return
}

task . { Write-Build Green 'Hello world!' }
'@
            }
        }
        ConvertTo-Json $PSubShell.Config | Set-Content $PSubShell.ConfigFile
        ConvertTo-Json $PSubShell.Locks | Set-Content $PSubShell.LockFile
        return
    }
    'EnterShell' {
        if ($global:PSubShellInstance -eq $PSubShell.Path) {
            Write-Error 'Cannot reenter the same PSubShell.'
            return
        }

        $script = Join-Path ([System.IO.Path]::GetTempPath()) "tmp$((New-Guid) -replace '-','').ps1"
        try {
            Set-Content -Path $script -Value @"
`$global:PSubShellInstance = '$($PSubShell.Path)'
Set-Alias -Name PSubShell -Value $($MyInvocation.MyCommand.Path)
$PSCommandPath -Apply
$Command $($Parameters.GetEnumerator() | ForEach-Object { "$($_.Key) $($_.Value)" } | Join-String ' ')
"@
            #Get-Content $script
            Invoke-Expression "pwsh -Interactive $(((-not $Command) -or $NoExit) ? '-NoExit' : '') $($NoProfile ? '-NoProfile' : '') -File $script"
        }
        finally {
            Remove-Item -Path $script -Force -ErrorAction SilentlyContinue
        }
    }

    'AddResource' {
        $parms = @{}
        foreach ($parm in $PSBoundParameters.Keys) {
            if ($parm -ne 'AddResource') {
                if ($PSBoundParameters.$parm -is [switch]) {
                    $parms.Add($parm, [bool]$PSBoundParameters.$parm)
                }
                else {
                    $parms.Add($parm, $PSBoundParameters.$parm)
                }
            }
        }
        $resource = Find-PSResource -Name $AddResource -ErrorAction SilentlyContinue @parms |
            Sort-Object -Property Version -Descending |
            Select-Object -First 1
        if (-not $resource) {
            Write-Error "Unable to find resource '$AddResource'."
            return
        }
        $type = $resource.Type.ToString()
        if ((-not $type) -or ($type -eq 'None')) {
            $type = 'Package'
        }
        $PSubShell.Config.Resources.$AddResource = @{
            Type = $type
        } + $parms
        $PSubShell.Locks.$AddResource = @{
            Type = $type
            Version = $resource.Version.ToString()
        }
        ConvertTo-Json $PSubShell.Config | Set-Content $PSubShell.ConfigFile
        ConvertTo-Json $PSubShell.Locks | Set-Content $PSubShell.LockFile
    }

    'RemoveResource' {
        if ($PSubShell.Config.Resources.$RemoveResource) { $PSubShell.Config.Resources.Remove($RemoveResource) }
        if ($PSubShell.Locks.$RemoveResource) { $PSubShell.Locks.Remove($RemoveResource) }
        ConvertTo-Json $PSubShell.Config | Set-Content $PSubShell.ConfigFile
        ConvertTo-Json $PSubShell.Locks | Set-Content $PSubShell.LockFile
    }

    'Update' {
        foreach ($name in $PSubShell.Config.Resources.Keys) {
            $parms = @{ }
            foreach ($parm in $PSubShell.Config.Resources.$resource) {
                if ($parm -ne 'Type') {
                    $parms.Add($parm, $PSubShell.Config.Resources.$name.$parm)
                }
            }
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

    'Configure' {
        $updated = $false
        if ($AddPath) {
            if (-not $PSubShell.Config.ContainsKey('Path')) {
                $PSubShell.Config.Path = @()
            }
            $fqpWarning = $false
            foreach ($path in @($AddPath)) {
                if ([System.IO.Path]::IsPathFullyQualified($path)) {
                    Write-Warning "Adding fully qualified path '$path'."
                    $fqpWarning = $true
                }
            }
            if ($fqpWarning) {
                Write-Warning 'Adding fully qualified paths is not recommended.'
            }
            $PSubShell.Config.Path += @($AddPath)
            $updated = $true
        }
        if ($AddModulePath) {
            if (-not $PSubShell.Config.ContainsKey('ModulePath')) {
                $PSubShell.Config.ModulePath = @()
            }
            $fqpWarning = $false
            foreach ($path in @($AddModulePath)) {
                if ([System.IO.Path]::IsPathFullyQualified($path)) {
                    Write-Warning "Adding fully qualified module path '$path'."
                    $fqpWarning = $true
                }
            }
            if ($fqpWarning) {
                Write-Warning 'Adding fully qualified paths is not recommended.'
            }
            $PSubShell.Config.ModulePath += @($AddPath)
            $updated = $true
        }
        if ($AddVariable) {
            if (-not $PSubShell.Config.ContainsKey('Variables')) {
                $PSubShell.Config.Variables = @{}
            }
            foreach ($key in $AddVariable.Keys) {
                $PSubShell.Config.Variables.$key = $AddVariable.$key
            }
            $updated = $true
        }
        if ($AddEnvironmentVariable) {
            if (-not $PSubShell.Config.ContainsKey('EnvironmentVariables')) {
                $PSubShell.Config.EnvironmentVariables = @{}
            }
            foreach ($key in $AddEnvironmentVariable.Keys) {
                $PSubShell.Config.EnvironmentVariables.$key = $AddEnvironmentVariable.$key
            }
            $updated = $true
        }
        if ($updated) {
            ConvertTo-Json $PSubShell.Config | Set-Content $PSubShell.ConfigFile
        }
        else {
            Write-Warning 'No configuration changes made.'
        }
    }

    'Apply' {
        Write-Host 'Applying PSubShell...'
        $psubshellpath = Join-Path $PSubShell.Path '.psubshell'
        $cpath = @($PSubShell.Config.Path)
        [Array]::Reverse($cpath)
        foreach ($path in $cpath) {
            if (-not ([IO.Path]::IsPathRooted($path))) {
                $path = Join-Path $PSubShell.Path $path
            }
            $path = Join-Path $path '.'
            $path = [IO.Path]::GetFullPath($path)
            $existingPaths = $env:PATH -split [IO.Path]::PathSeparator
            if (-not ($existingPaths -contains $path)) {
                $env:PATH = $path + [IO.Path]::PathSeparator + $env:PATH
            }
        }
        $cpath = @($PSubShell.Config.ModulePath)
        [Array]::Reverse($cpath)
        foreach ($path in $cpath) {
            if (-not ([IO.Path]::IsPathRooted($path))) {
                $path = Join-Path $PSubShell.Path $path
            }
            $path = Join-Path $path '.'
            $path = [IO.Path]::GetFullPath($path)
            $existingPaths = $env:PSModulePath -split [IO.Path]::PathSeparator
            if (-not ($existingPaths -contains $path)) {
                $env:PSModulePath = $path + [IO.Path]::PathSeparator + $env:PSModulePath
            }
        }
        foreach ($key in $PSubShell.Config.Variables.Keys) {
            Set-Variable -Name $key -Value $PSubShell.Config.Variables.$key -Scope Global
        }
        foreach ($key in $PSubShell.Config.EnvironmentVariables.Keys) {
            Set-Item -Path "env:$key" -Value $PSubShell.Config.EnvironmentVariables.$key
        }
        foreach ($resource in $PSubShell.Locks.Keys) {
            New-Item -Path $psubshellpath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
            switch ($PSubShell.Locks.$resource.Type) {
                'Script' {
                    $resourcePath = Join-Path $psubshellpath "$resource.ps1"
                    $found = $false
                    if (Test-Path $resourcePath) {
                        $info = Get-PSScriptFileInfo -Path $resourcePath
                        if ($info.Version -eq $PSubShell.Locks.$resource.Version) {
                            $found = $true
                        }
                    }
                    if (-not $found) {
                        Remove-Item -Path $resourcePath -Force -ErrorAction SilentlyContinue
                        Save-PSResource -Name $resource -Version $PSubShell.Locks.$resource.Version `
                            -Path $psubshellpath -IncludeXml -WarningAction SilentlyContinue
                    }
                    Set-Alias -Name $resource -Value $resourcePath -Scope Global
                    Write-Host "Set-Alias -Name $resource -Value $resourcePath"
                }
                'Module' {
                    $resourcePath = Join-Path $psubshellpath $resource -AdditionalChildPath $PSubShell.Locks.$resource.Version
                    if (-not (Test-Path $resourcePath)) {
                        Remove-Item -Path (Join-Path $psubshellpath $resource) -Force -ErrorAction SilentlyContinue
                        Save-PSResource -Name $resource -Version $PSubShell.Locks.$resource.Version `
                            -Path $psubshellpath -IncludeXml -WarningAction SilentlyContinue
                    }
                    Import-Module (Join-Path $psubshellpath $resource) -Force
                }
                'Package' {
                    $resourcePath = Join-Path $psubshellpath $resource -AdditionalChildPath $PSubShell.Locks.$resource.Version
                    if (-not (Test-Path $resourcePath)) {
                        Remove-Item -Path (Join-Path $psubshellpath $resource) -Force -ErrorAction SilentlyContinue
                        Save-PSResource -Name $resource -Version $PSubShell.Locks.$resource.Version `
                            -Path $psubshellpath -IncludeXml -WarningAction SilentlyContinue
                    }
                    $tools = Join-Path $resourcePath 'tools'
                    if (Test-Path $tools) {
                        $env:PATH = (@($tools) + (
                                $env:PATH -split [IO.Path]::PathSeparator |
                                    Where-Object { $_ -ne $tools }
                            )) -join [IO.Path]::PathSeparator
                    }
                }
            }
        }
    }
}
