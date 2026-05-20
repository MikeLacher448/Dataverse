. (Join-Path $PSScriptRoot 'PrivateTestCommon.ps1')

Describe 'New-PSDVManagedIdentityCredential' {
    It 'creates a system-assigned managed identity credential when no ID is supplied' {
        InModuleScope Dataverse {
            Import-PSDVAzureIdentityAssemblies
            $credential = New-PSDVManagedIdentityCredential -AuthContext (New-PSDVTestAuthContext -ParameterSetName 'SystemManagedIdentity')

            $credential.GetType().FullName | Should -Be 'Azure.Identity.ManagedIdentityCredential'
        }
    }

    It 'creates a user-assigned managed identity credential from a runtime-generated client ID' {
        InModuleScope Dataverse {
            Import-PSDVAzureIdentityAssemblies
            $authContext = New-PSDVTestAuthContext -ParameterSetName 'ManagedIdentity'
            $authContext.ManagedIdentityID = [Guid]::NewGuid().ToString()

            $credential = New-PSDVManagedIdentityCredential -AuthContext $authContext

            $credential.GetType().FullName | Should -Be 'Azure.Identity.ManagedIdentityCredential'
        }
    }
}