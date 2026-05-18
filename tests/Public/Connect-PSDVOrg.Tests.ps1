BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Connect-PSDVOrg' {
    BeforeEach {
        $script:OriginalIdentityEndpoint = $env:IDENTITY_ENDPOINT
        $script:OriginalIdentityHeader = $env:IDENTITY_HEADER
        $script:OriginalMsiEndpoint = $env:MSI_ENDPOINT
        $script:OriginalMsiSecret = $env:MSI_SECRET

        Clear-PSDVPublicTestConnection
    }

    AfterEach {
        $env:IDENTITY_ENDPOINT = $script:OriginalIdentityEndpoint
        $env:IDENTITY_HEADER = $script:OriginalIdentityHeader
        $env:MSI_ENDPOINT = $script:OriginalMsiEndpoint
        $env:MSI_SECRET = $script:OriginalMsiSecret

        Clear-PSDVPublicTestConnection
    }

    It 'connects with FunctionRuntime system managed identity and normalizes the organization URL' {
        $env:IDENTITY_ENDPOINT = 'http://localhost/runtime/token'
        $env:IDENTITY_HEADER = [Guid]::NewGuid().ToString('N')
        $env:MSI_ENDPOINT = $null
        $env:MSI_SECRET = $null

        Mock -CommandName Invoke-RestMethod -ModuleName Dataverse -MockWith {
            return [PSCustomObject]@{
                access_token = [Guid]::NewGuid().ToString('N')
                expires_in   = 3600
            }
        } -ParameterFilter { $Uri -match 'resource=https%3A%2F%2Fexample.crm.dynamics.com' }

        Connect-PSDVOrg -UseSystemManagedIdentity -ManagedIdentityTokenSource FunctionRuntime -DataverseOrgURL 'https://example.crm.dynamics.com'

        $Global:DATAVERSEORGURL | Should -BeExactly 'https://example.crm.dynamics.com/'
        $Global:DATAVERSEAUTHCONTEXT.ParameterSetName | Should -BeExactly 'SystemManagedIdentity'
        $Global:DATAVERSEAUTHCONTEXT.ManagedIdentityTokenSource | Should -BeExactly 'FunctionRuntime'
        $Global:DATAVERSEACCESSTOKEN.Token | Should -Not -BeNullOrEmpty
        Should -Invoke -CommandName Invoke-RestMethod -ModuleName Dataverse -Times 1 -Exactly
    }
}
