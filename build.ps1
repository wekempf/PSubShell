param(
    [Parameter(Position = 0)]
    [ValidateSet('?', '.', 'version', 'clean', 'build', 'publish')]
    [string[]]$Tasks,

    [string]$Repository = 'PSGallery',
    [string]$NuGetApiKey = ([Environment]::GetEnvironmentVariable('NUGET_API_KEY'))
)

if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    $c = "Invoke-Build $($Tasks -join ',') -File $($MyInvocation.MyCommand.Path)"
    foreach ($kv in $PSBoundParameters) {
        $c += " $($kv.Key) $($kv.Value)"
    }
    & "$PSScriptRoot/PSubShell.ps1" -NoProfile -Command $c
    return
}

Set-BuildHeader {
    param($Path)
    Write-Build Green ('=' * 79)
    $synopsis = Get-BuildSynopsis $Task
    Write-Build Green "Task $(Split-Path -Leaf $Path)$(if ($synopsis) { " - $synopsis" })"
    Write-Build DarkGray "At $($Task.InvocationInfo.ScriptName):$($Task.InvocationInfo.ScriptLineNumber)"
    Write-Build Green ''
}

Set-BuildFooter {
    param($Path)
    if ($Path -ne '/.') {
        Write-Build DarkGray ''
        Write-Build DarkGray "Task $(Split-Path -Leaf $Path) completed: $($Task.Elapsed)"
    }
}

$script:scriptName = 'PSubShell'
$script:buildPath = Join-Path $PSScriptRoot '.build'

task version {
    $script:version = Test-ScriptFileInfo "$scriptName.ps1" | Select-Object -ExpandProperty Version
    $branch = git rev-parse --abbrev-ref HEAD
    if ($branch -ne 'main') {
        $script:version = "$script:version-alpha$(git rev-list --count HEAD)"
    }
    Write-Build Cyan $script:version
    $latestVersion = Find-Script $scriptName -Repository:$Repository -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Version
    if ($latestVersion -and ([System.Management.Automation.SemanticVersion]$latestVersion -ge [System.Management.Automation.SemanticVersion]$version)) {
        throw "Version $latestVersion already published. Bump version and try again."
    }
}

task clean {
    remove $buildPath
}

task build version, clean, {
    New-Item $buildPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
    Copy-Item "$scriptName.ps1" (Join-Path $buildPath "$scriptName.ps1")
    Update-ScriptFileInfo (Join-Path $buildPath "$scriptName.ps1") -Version $version
}

task publish {
    if (-not (Test-Path (Join-Path $buildPath "$scriptName.ps1"))) {
        throw "Build script not found. Run 'build' task first."
    }
    $branch = git rev-parse --abbrev-ref HEAD
    $githubActions = [Environment]::GetEnvironmentVariable('GITHUB_ACTIONS')
    if (($branch -ne 'main') -and $githubActions) {
        Write-Build Yellow 'Registering GitHub repository...'
        Register-PSRepository -Name GitHub `
            -SourceLocation 'https://nuget.pkg.github.com/wekempf/index.json' `
            -ScriptSourceLocation 'https://nuget.pkg.github.com/wekempf/index.json' `
            -PublishLocation 'https://nuget.pkg.github.com/wekempf/' `
            -ScriptPublishLocation 'https://nuget.pkg.github.com/wekempf/' `
            -InstallationPolicy Trusted
        $Repository = 'GitHub'
        $NuGetApiKey = [Environment]::GetEnvironmentVariable('GITHUB_TOKEN')
    }
    if (-not $NuGetApiKey) {
        throw 'NuGetApiKey parameter is required.'
    }
    Publish-Script -Path (Join-Path $buildPath "$scriptName.ps1") -Repository $Repository -NuGetApiKey $NuGetApiKey
    if (($branch -ne 'main') -and ([Environment]::GetEnvironmentVariable('GITHUB_ACTIONS'))) {
        Unregister-PSRepository -Name GitHub
    }
}

task . build