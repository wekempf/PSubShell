param(
    [Parameter(Position = 0)]
    [string[]]$Tasks
)

if ($MyInvocation.ScriptName -notlike '*Invoke-Build.ps1') {
    $c = "Invoke-Build $($Tasks -join ',') -File $($MyInvocation.MyCommand.Path)"
    foreach ($kv in $PSBoundParameters) {
        $c += " $($kv.Key) $($kv.Value)"
    }
    ./PSubShell.ps1 -NoProfile -Command $c
    return
}

task . { Write-Build Green 'Hello world!' }