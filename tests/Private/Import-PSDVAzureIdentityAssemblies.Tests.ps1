. (Join-Path $PSScriptRoot 'PrivateTestCommon.ps1')

Describe 'Import-PSDVAzureIdentityAssemblies' {
    It 'returns immediately when assemblies are already marked as loaded' {
        InModuleScope Dataverse {
            $originalLoaded = $script:PSDVAzureIdentityLoaded
            $originalPath = $script:PSDVAzureIdentityAssemblyPath
            try {
                $script:PSDVAzureIdentityLoaded = $true
                $script:PSDVAzureIdentityAssemblyPath = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString('N'))

                { Import-PSDVAzureIdentityAssemblies } | Should -Not -Throw
            }
            finally {
                $script:PSDVAzureIdentityLoaded = $originalLoaded
                $script:PSDVAzureIdentityAssemblyPath = $originalPath
            }
        }
    }

    It 'throws when the bundled assembly folder is missing' {
        InModuleScope Dataverse {
            $originalLoaded = $script:PSDVAzureIdentityLoaded
            $originalPath = $script:PSDVAzureIdentityAssemblyPath
            try {
                $script:PSDVAzureIdentityLoaded = $false
                $script:PSDVAzureIdentityAssemblyPath = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString('N'))

                { Import-PSDVAzureIdentityAssemblies } | Should -Throw -ExpectedMessage "Azure.Identity bundled assemblies were not found at '*"
            }
            finally {
                $script:PSDVAzureIdentityLoaded = $originalLoaded
                $script:PSDVAzureIdentityAssemblyPath = $originalPath
            }
        }
    }
}