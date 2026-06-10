BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')

    function New-PSDVPublicTestJwt {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory)]
            [Int64]
            $ExpiresOnEpoch
        )

        function ConvertTo-PSDVPublicTestBase64Url {
            param([Parameter(Mandatory)][String]$Value)

            return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Value)).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        }

        $header = ConvertTo-PSDVPublicTestBase64Url -Value '{"alg":"none","typ":"JWT"}'
        $payload = ConvertTo-PSDVPublicTestBase64Url -Value ('{{"exp":{0}}}' -f $ExpiresOnEpoch)
        return '{0}.{1}.sig' -f $header, $payload
    }
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

    It 'connects with a supplied access token and explicit expiration without acquiring a token' {
        Mock -CommandName Get-PSDVAccessToken -ModuleName Dataverse -MockWith {
            throw 'Get-PSDVAccessToken should not be called for supplied access tokens.'
        }

        $secureToken = ConvertTo-SecureString -String 'opaque-token' -AsPlainText -Force
        $expiresOn = [DateTimeOffset]::UtcNow.AddHours(1)

        Connect-PSDVOrg -AccessToken $secureToken -AccessTokenExpiresOn $expiresOn -DataverseOrgURL 'https://example.crm.dynamics.com'

        $Global:DATAVERSEORGURL | Should -BeExactly 'https://example.crm.dynamics.com/'
        $Global:DATAVERSEAUTHCONTEXT.ParameterSetName | Should -BeExactly 'AccessToken'
        $Global:DATAVERSEACCESSTOKEN.Token | Should -Be $secureToken
        $Global:DATAVERSEACCESSTOKEN.ExpiresOn | Should -Be $expiresOn.UtcDateTime
        Should -Invoke -CommandName Get-PSDVAccessToken -ModuleName Dataverse -Times 0 -Exactly
    }

    It 'connects with a supplied JWT access token and parses the exp claim' {
        Mock -CommandName Get-PSDVAccessToken -ModuleName Dataverse -MockWith {
            throw 'Get-PSDVAccessToken should not be called for supplied access tokens.'
        }

        $expiresOnEpoch = [DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeSeconds()
        $expectedExpiresOn = [DateTimeOffset]::FromUnixTimeSeconds($expiresOnEpoch).UtcDateTime
        $secureToken = ConvertTo-SecureString -String (New-PSDVPublicTestJwt -ExpiresOnEpoch $expiresOnEpoch) -AsPlainText -Force

        Connect-PSDVOrg -AccessToken $secureToken -DataverseOrgURL 'https://example.crm.dynamics.com'

        $Global:DATAVERSEAUTHCONTEXT.ParameterSetName | Should -BeExactly 'AccessToken'
        $Global:DATAVERSEACCESSTOKEN.Token | Should -Be $secureToken
        $Global:DATAVERSEACCESSTOKEN.ExpiresOn | Should -Be $expectedExpiresOn
        Should -Invoke -CommandName Get-PSDVAccessToken -ModuleName Dataverse -Times 0 -Exactly
    }

    It 'requires an explicit expiration when the supplied token expiration cannot be determined' {
        $secureToken = ConvertTo-SecureString -String 'opaque-token' -AsPlainText -Force

        { Connect-PSDVOrg -AccessToken $secureToken -DataverseOrgURL 'https://example.crm.dynamics.com' } |
            Should -Throw -ExpectedMessage 'Unable to determine the supplied access token expiration*'
    }
}
