. (Join-Path $PSScriptRoot 'PrivateTestCommon.ps1')

Describe 'New-PSDVInteractiveCredential' {
    It 'creates an interactive browser credential by default' {
        InModuleScope Dataverse {
            Import-PSDVAzureIdentityAssemblies
            $authContext = New-PSDVTestAuthContext -ParameterSetName 'InteractiveLogin'

            $credential = New-PSDVInteractiveCredential -AuthContext $authContext

            $credential.GetType().FullName | Should -Be 'Azure.Identity.InteractiveBrowserCredential'
        }
    }

    It 'creates a device code credential when requested' {
        InModuleScope Dataverse {
            Import-PSDVAzureIdentityAssemblies
            $authContext = New-PSDVTestAuthContext -ParameterSetName 'InteractiveLogin'
            $authContext.UseDeviceCode = $true

            $credential = New-PSDVInteractiveCredential -AuthContext $authContext
            $credential.GetType().FullName | Should -Be 'Azure.Identity.DeviceCodeCredential'
        }
    }
}