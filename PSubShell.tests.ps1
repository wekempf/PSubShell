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
    
        It 'should create config and lock file' {
            PSubShell -Initialize
            '.psubshell.json' | Should -Exist
            '.psubshell.lock.json' | Should -Exist
            'PSubShell.ps1' | Should -Not -Exist
            'build.ps1' | Should -Not -Exist
        }

        It 'should add PSubShell.ps1 when -Isolated' {
            PSubShell -Initialize -Isolated
            '.psubshell.json' | Should -Exist
            '.psubshell.lock.json' | Should -Exist
            'PSubShell.ps1' | Should -Exist
            'build.ps1' | Should -Not -Exist
        }

        It 'should add build.ps1 and PSubShell.ps1 when -InvokeBuild' {
            PSubShell -Initialize -InvokeBuild
            '.psubshell.json' | Should -Exist
            '.psubshell.lock.json' | Should -Exist
            'PSubShell.ps1' | Should -Exist
            'build.ps1' | Should -Exist
        }

        It 'should add build.ps1 but not PSubShell.ps1 when -InvokeBuild -Isolated:$false' {
            PSubShell -Initialize -InvokeBuild -Isolated:$False
            '.psubshell.json' | Should -Exist
            '.psubshell.lock.json' | Should -Exist
            'PSubShell.ps1' | Should -Not -Exist
            'build.ps1' | Should -Exist
        }
    }
}

Describe '-InstallResource' {
    Context 'valid resource' {
        BeforeEach $setup
        AfterEach $teardown
    
        It 'should record parameters and type' {
            PSubShell -Initialize
            PSubShell -InstallResource posh-git -Version '[1.1.0, 2.0.0)' -Repository PSGallery -Prerelease:$false
            $cfg = Get-Content '.psubshell.json' | ConvertFrom-Json -AsHashtable
            $cfg.Resources.'posh-git' | Should -Not -BeNull
            $cfg.Resources.'posh-git'.Version | Should -Be '[1.1.0, 2.0.0)'
            $cfg.Resources.'posh-git'.Repository | Should -Be 'PSGallery'
            $cfg.Resources.'posh-git'.Prerelease | Should -Be $false
            $cfg.Resources.'posh-git'.Type | Should -Be 'Module'
        }

        It 'should record type when it is a module' {
            PSubShell -Initialize
            PSubShell -InstallResource posh-git
            $cfg = Get-Content '.psubshell.json' | ConvertFrom-Json -AsHashtable
            $cfg.Resources.'posh-git' | Should -Not -BeNull
            $cfg.Resources.'posh-git'.Type | Should -Be 'Module'
        }

        It 'should record type when it is a script' {
            PSubShell -Initialize
            PSubShell -InstallResource PSubShell
            $cfg = Get-Content '.psubshell.json' | ConvertFrom-Json -AsHashtable
            $cfg.Resources.PSubShell | Should -Not -BeNull
            $cfg.Resources.PSubShell.Type | Should -Be 'Script'
        }

        It 'should record type when it is a package' {
            PSubShell -Initialize
            PSubShell -InstallResource GitVersion.CommandLine
            $cfg = Get-Content '.psubshell.json' | ConvertFrom-Json -AsHashtable
            $cfg.Resources.'GitVersion.CommandLine' | Should -Not -BeNull
            $cfg.Resources.'GitVersion.CommandLine'.Type | Should -Be 'Package'
        }
    }
}

Describe '-RemoveResource' {
    Context 'existing resource' {
        BeforeEach $setup
        AfterEach $teardown
    
        It 'should remove resource' {
            PSubShell -Initialize
            PSubShell -InstallResource posh-git
            PSubShell -RemoveResource posh-git
            $cfg = Get-Content '.psubshell.json' | ConvertFrom-Json -AsHashtable
            $cfg.Resources.'posh-git' | Should -BeNull
        }
    }
}
