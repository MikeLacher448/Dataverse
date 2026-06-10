BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Invoke-PSDVWebRequest' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'builds a Dataverse API request, sends JSON body content, and parses a single response object' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return New-PSDVPublicTestWebResponse -Payload @{ accountid = [Guid]::NewGuid(); name = 'Contoso' }
        }

        $result = Invoke-PSDVWebRequest -WebUri 'accounts' -Select 'name' -Filter "name eq 'Contoso'" -Body @{ name = 'Contoso' }

        $result.name | Should -BeExactly 'Contoso'
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter { $Method -eq 'Post' -and $Uri -match '/accounts' -and $Headers['Content-Type'] -eq 'application/json' -and $Body -match 'Contoso' }
    }

    It 'follows OData pagination links and returns the combined collection' {
        $nextLink = 'https://example.crm.dynamics.com/api/data/v9.2/accounts?$skiptoken=next'

        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            if ($Uri -eq $nextLink) {
                return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ name = 'Second' }) }
            }

            return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ name = 'First' }); '@odata.nextLink' = $nextLink }
        }

        $result = Invoke-PSDVWebRequest -WebUri 'accounts'

        @($result).Count | Should -Be 2
        @($result).name | Should -Be @('First', 'Second')
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 2 -Exactly
    }

    It 'returns the raw web response when requested' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return [PSCustomObject]@{ Content = '{"ok":true}'; StatusCode = 204 }
        }

        $result = Invoke-PSDVWebRequest -WebUri 'accounts' -ReturnRawResponse

        $result.StatusCode | Should -Be 204
    }
}
