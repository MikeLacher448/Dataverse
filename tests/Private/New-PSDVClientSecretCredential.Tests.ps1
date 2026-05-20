. (Join-Path $PSScriptRoot 'PrivateTestCommon.ps1')

Describe 'New-PSDVClientSecretCredential' {
    It 'creates an Azure.Identity client secret credential from runtime-generated secret material' {
        InModuleScope Dataverse {
            Import-PSDVAzureIdentityAssemblies
            $secret = New-PSDVTestSecureString
            $authContext = New-PSDVTestAuthContext -ParameterSetName 'ClientSecret'
            $authContext.ClientSecret = $secret.SecureString

            $credential = New-PSDVClientSecretCredential -AuthContext $authContext

            $credential.GetType().FullName | Should -Be 'Azure.Identity.ClientSecretCredential'
        }
    }
}