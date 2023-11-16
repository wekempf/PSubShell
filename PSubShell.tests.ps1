BeforeAll {
    Set-Alias PSubShell (Join-Path $PSScriptRoot 'PSubShell.ps1')
}
AfterAll {
    Remove-Alias PSubShell
}
$setup = {
    Push-Location TestDrive:/
    Remove-Item * -Recurse -Force
}
$teardown = {
    Remove-Item * -Recurse -Force
    Pop-Location
}

Describe 'Enter PSubShell' {
    Context 'No PSubShell initialized' {
        BeforeEach $setup
        AfterEach $teardown

        It 'should fail' {
            { PSubShell -NoProfile -ErrorAction Stop } | Should -Throw
        }
    }

    Context 'PSubShell initialized' {
        BeforeEach $setup
        AfterEach $teardown

        # Not sure why this causes the tests to hang, but this is tested manually.
        # It 'should fail when recursively entered' {
        #     PSubShell -Initialize
        #     $output = PSubShell -Command { PSubShell -NoProfile } -NoProfile
        #     $output | Should -Be 'Write-Error: Cannot reenter the same PSubShell.'
        # }

        It 'should execute command' {
            PSubShell -Initialize
            $output = PSubShell -Command { Write-Output 'Hello, World!' } -NoProfile
            $output -Join ' ' | Should -BeLike '*Hello, World!*'
        }
    }
}

Describe '-Initialize' {
    Context 'not initialized' {
        BeforeEach $setup
        AfterEach $teardown
    
        It 'should create deps and lock file' {
            PSubShell -Initialize
            '.psubshell.deps.json' | Should -Exist
            '.psubshell.lock.json' | Should -Exist
            'PSubShell.ps1' | Should -Not -Exist
            'build.ps1' | Should -Not -Exist
        }

        It 'should add PSubShell.ps1 when -Isolated' {
            PSubShell -Initialize -Isolated
            '.psubshell.deps.json' | Should -Exist
            '.psubshell.lock.json' | Should -Exist
            'PSubShell.ps1' | Should -Exist
            'build.ps1' | Should -Not -Exist
        }

        It 'should add build.ps1 and PSubShell.ps1 when -InvokeBuild' {
            PSubShell -Initialize -InvokeBuild
            '.psubshell.deps.json' | Should -Exist
            '.psubshell.lock.json' | Should -Exist
            'PSubShell.ps1' | Should -Exist
            'build.ps1' | Should -Exist
        }

        It 'should add build.ps1 but not PSubShell.ps1 when -InvokeBuild -Isolated:$false' {
            PSubShell -Initialize -InvokeBuild -Isolated:$False
            '.psubshell.deps.json' | Should -Exist
            '.psubshell.lock.json' | Should -Exist
            'PSubShell.ps1' | Should -Not -Exist
            'build.ps1' | Should -Exist
        }
    }
}

Describe '-AddResource' {
    Context 'valid resource' {
        BeforeEach $setup
        AfterEach $teardown
    
        It 'should record parameters and type' {
            PSubShell -Initialize
            PSubShell -AddResource posh-git -Version '[1.1.0, 2.0.0)' -Repository PSGallery -Prerelease:$false
            $deps = Get-Content '.psubshell.deps.json' | ConvertFrom-Json -AsHashtable
            $deps.'posh-git' | Should -Not -BeNull
            $deps.'posh-git'.Version | Should -Be '[1.1.0, 2.0.0)'
            $deps.'posh-git'.Repository | Should -Be 'PSGallery'
            $deps.'posh-git'.Prerelease | Should -Be $false
            $deps.'posh-git'.Type | Should -Be 'Module'
        }

        It 'should record type when it is a module' {
            PSubShell -Initialize
            PSubShell -AddResource posh-git
            $deps = Get-Content '.psubshell.deps.json' | ConvertFrom-Json -AsHashtable
            $deps.'posh-git' | Should -Not -BeNull
            $deps.'posh-git'.Type | Should -Be 'Module'
        }

        It 'should record type when it is a script' {
            PSubShell -Initialize
            PSubShell -AddResource PSubShell
            $deps = Get-Content '.psubshell.deps.json' | ConvertFrom-Json -AsHashtable
            $deps.PSubShell | Should -Not -BeNull
            $deps.PSubShell.Type | Should -Be 'Script'
        }

        It 'should record type when it is a package' {
            PSubShell -Initialize
            PSubShell -AddResource GitVersion.CommandLine
            $deps = Get-Content '.psubshell.deps.json' | ConvertFrom-Json -AsHashtable
            $deps.'GitVersion.CommandLine' | Should -Not -BeNull
            $deps.'GitVersion.CommandLine'.Type | Should -Be 'Package'
        }
    }
}

Describe '-RemoveResource' {
    Context 'existing resource' {
        BeforeEach $setup
        AfterEach $teardown
    
        It 'should remove resource' {
            PSubShell -Initialize
            PSubShell -AddResource posh-git
            PSubShell -RemoveResource posh-git
            $deps = Get-Content '.psubshell.deps.json' | ConvertFrom-Json -AsHashtable
            $deps.'posh-git' | Should -BeNull
        }
    }
}
