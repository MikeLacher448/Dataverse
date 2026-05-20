. (Join-Path $PSScriptRoot 'PrivateTestCommon.ps1')

Describe 'Get-PSDVFunctionRuntimeManagedIdentityAccessToken' {
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
    }

    It 'uses the modern function runtime endpoint with the identity header' {
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
            $token = Get-PSDVFunctionRuntimeManagedIdentityAccessToken -AuthContext @{ ResourceUrl = 'https://example.crm.dynamics.com/'; ManagedIdentityID = [Guid]::NewGuid().ToString() }

            $token.Token | Should -Not -BeNullOrEmpty
        }

        Should -Invoke -CommandName Invoke-RestMethod -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter {
            $Headers['X-IDENTITY-HEADER'] -eq $env:IDENTITY_HEADER -and
            $Uri -match 'api-version=2019-08-01' -and
            $Uri -match 'client_id='
        }
    }

    It 'uses the legacy MSI endpoint when modern environment variables are absent' {
        $env:IDENTITY_ENDPOINT = $null
        $env:IDENTITY_HEADER = $null
        $env:MSI_ENDPOINT = 'http://localhost/legacy/token'
        $env:MSI_SECRET = [Guid]::NewGuid().ToString('N')

        Mock -CommandName Invoke-RestMethod -ModuleName Dataverse -MockWith {
            return [PSCustomObject]@{
                access_token = [Guid]::NewGuid().ToString('N')
                expires_on   = ([DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeSeconds()).ToString()
            }
        }

        InModuleScope Dataverse {
            $token = Get-PSDVFunctionRuntimeManagedIdentityAccessToken -AuthContext @{ ResourceUrl = 'https://example.crm.dynamics.com/'; ManagedIdentityID = [Guid]::NewGuid().ToString() }

            $token.ExpiresOn | Should -BeGreaterThan (Get-Date).ToUniversalTime()
        }

        Should -Invoke -CommandName Invoke-RestMethod -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter {
            $Headers.Secret -eq $env:MSI_SECRET -and
            $Uri -match 'api-version=2017-09-01' -and
            $Uri -match 'clientid='
        }
    }

    It 'throws when no function runtime managed identity endpoint is available' {
        $env:IDENTITY_ENDPOINT = $null
        $env:IDENTITY_HEADER = $null
        $env:MSI_ENDPOINT = $null
        $env:MSI_SECRET = $null

        InModuleScope Dataverse {
            { Get-PSDVFunctionRuntimeManagedIdentityAccessToken -AuthContext @{ ResourceUrl = 'https://example.crm.dynamics.com/' } } | Should -Throw -ExpectedMessage 'Function runtime managed identity token acquisition requires IDENTITY_ENDPOINT*'
        }
    }
}
