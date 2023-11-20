param(
    [Parameter(Position = 0)]
    [ValidateSet('?', '.', 'version', 'clean', 'test', 'build', 'publish')]
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

function semver($version) {
    [System.Management.Automation.SemanticVersion]$version
}

$script:scriptName = 'PSubShell'
$script:buildPath = Join-Path $PSScriptRoot '.build'

task version {
    $script:version = semver (Test-ScriptFileInfo "$scriptName.ps1" |
            Select-Object -ExpandProperty Version)
    $script:commits = exec { git rev-list --count main..HEAD }
    if ($commits -ne 0) {
        $script:version = semver "$script:version-alpha$commits"
    }
    $latestVersion = semver (
        Find-PSResource $scriptName -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty Version)
    if ($latestVersion) {
        if ($latestVersion -ge $version) {
            throw "Version $latestVersion already published. Bump version and try again."
        }
        $releaseVersion = semver "$($script:version.Major).$($script:version.Minor).$($script:version.Patch)"
        $patchBump = semver "$($latestVersion.Major).$($latestVersion.Minor).$($latestVersion.Patch + 1)"
        $minorBump = semver "$($latestVersion.Major).$($latestVersion.Minor + 1).0"
        $majorBump = semver "$($latestVersion.Major + 1).0.0"
        if (($releaseVersion -ne $patchBump) -and
            ($releaseVersion -ne $minorBump) -and
            ($releaseVersion -ne $majorBump)) {
            throw "Invalid version bump. Update version to $patchBump, $minorBump, or $majorBump and try again."
        }
    }
    Write-Build Cyan $script:version
}

task clean {
    remove $buildPath
}

task test {
    Invoke-Pester
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
    $githubActions = [Environment]::GetEnvironmentVariable('GITHUB_ACTIONS')
    if ($script:version.PreReleaseLabel -and $githubActions) {
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
    Publish-Script -Path (Join-Path $buildPath "$scriptName.ps1") `
        -Repository $Repository -NuGetApiKey $NuGetApiKey
    if ($script:version.PreReleaseLabel -and $githubActions) {
        Unregister-PSRepository -Name GitHub
    }
}

task . version, clean, test, build
