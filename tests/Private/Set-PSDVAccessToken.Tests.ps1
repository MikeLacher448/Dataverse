. (Join-Path $PSScriptRoot 'PrivateTestCommon.ps1')

Describe 'Set-PSDVAccessToken' {
    BeforeEach {
        $script:OriginalIdentityEndpoint = $env:IDENTITY_ENDPOINT
        $script:OriginalIdentityHeader = $env:IDENTITY_HEADER
        $script:OriginalMsiEndpoint = $env:MSI_ENDPOINT
        $script:OriginalMsiSecret = $env:MSI_SECRET
    }

    AfterEach {
        $env:IDENTITY_ENDPOINT = $script:OriginalIdentityEndpoint
        $env:IDENTITY_HEADER = $script:OriginalIdentityHeader
        $env:MSI_ENDPOINT = $script:OriginalMsiEndpoint
        $env:MSI_SECRET = $script:OriginalMsiSecret

        InModuleScope Dataverse {
            $Global:DATAVERSEAUTHCONTEXT = $null
            $Global:DATAVERSEACCESSTOKEN = $null
        }
    }

    It 'throws when no authentication context exists' {
        InModuleScope Dataverse {
            $Global:DATAVERSEAUTHCONTEXT = $null

            { Set-PSDVAccessToken } | Should -Throw -ExpectedMessage 'No existing connection to Dataverse Environment*'
        }
    }

    It 'stores a supplied token and copies refresh token metadata' {
        InModuleScope Dataverse {
            $authContext = New-PSDVTestAuthContext
            $accessToken = New-PSDVTestAccessToken -IncludeRefreshToken

            Set-PSDVAccessToken -AccessToken $accessToken -AuthContext $authContext

            $Global:DATAVERSEACCESSTOKEN | Should -Be $accessToken
            $authContext.RefreshToken | Should -Be $accessToken.RefreshToken
        }
    }

    It 'refreshes an expired cached token using the current auth context' {
        $env:IDENTITY_ENDPOINT = 'http://localhost/runtime/token'
        $env:IDENTITY_HEADER = [Guid]::NewGuid().ToString('N')
        $env:MSI_ENDPOINT = $null
        $env:MSI_SECRET = $null

        Mock -CommandName Invoke-RestMethod -ModuleName Dataverse -MockWith {
            return [PSCustomObject]@{
                access_token = [Guid]::NewGuid().ToString('N')
                expires_in   = 3600
            }
        }

        InModuleScope Dataverse {
            $Global:DATAVERSEAUTHCONTEXT = New-PSDVTestAuthContext -ParameterSetName 'SystemManagedIdentity'
            $Global:DATAVERSEAUTHCONTEXT.ManagedIdentityTokenSource = 'FunctionRuntime'
            $Global:DATAVERSEACCESSTOKEN = New-PSDVTestAccessToken -ExpiresOn (Get-Date).ToUniversalTime().AddMinutes(-1)

            Set-PSDVAccessToken

            $Global:DATAVERSEACCESSTOKEN.ExpiresOn | Should -BeGreaterThan (Get-Date).ToUniversalTime()
        }

        Should -Invoke -CommandName Invoke-RestMethod -ModuleName Dataverse -Times 1 -Exactly
    }

    It 'throws when a token result has no Token value' {
        InModuleScope Dataverse {
            $authContext = New-PSDVTestAuthContext
            $badToken = [PSCustomObject]@{ ExpiresOn = (Get-Date).ToUniversalTime().AddHours(1) }

            { Set-PSDVAccessToken -AccessToken $badToken -AuthContext $authContext -Operation 'Unit test token' } | Should -Throw -ExpectedMessage 'Unit test token returned an access token object without a Token value.'
        }
    }
}
