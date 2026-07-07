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

    It 'requests an OData max page size and still returns the combined collection' {
        $nextLink = 'https://example.crm.dynamics.com/api/data/v9.2/accounts?$skiptoken=next'

        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            if ($Uri -eq $nextLink) {
                return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ name = 'Second' }) }
            }

            return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ name = 'First' }); '@odata.nextLink' = $nextLink }
        }

        $result = Invoke-PSDVWebRequest -WebUri 'accounts' -MaxPageSize 1000

        @($result).Count | Should -Be 2
        @($result).name | Should -Be @('First', 'Second')
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 2 -Exactly -ParameterFilter { $Headers['Prefer'] -eq 'odata.maxpagesize=1000' }
    }

    It 'appends OData max page size to an existing Prefer header' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ name = 'Contoso' }) }
        }

        $result = Invoke-PSDVWebRequest -WebUri 'accounts' -MaxPageSize 500 -Headers @{ Prefer = 'odata.include-annotations="*"' }

        @($result).Count | Should -Be 1
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter { $Headers['Prefer'] -eq 'odata.include-annotations="*",odata.maxpagesize=500' }
    }

    It 'returns one page object per OData page when requested' {
        $nextLink = 'https://example.crm.dynamics.com/api/data/v9.2/accounts?$skiptoken=next'

        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            if ($Uri -eq $nextLink) {
                return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ name = 'Second' }, @{ name = 'Third' }) }
            }

            return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ name = 'First' }); '@odata.nextLink' = $nextLink }
        }

        $pages = @(Invoke-PSDVWebRequest -WebUri 'accounts' -MaxPageSize 1000 -AsPages)

        $pages.Count | Should -Be 2
        $pages[0].PageNumber | Should -Be 1
        $pages[0].Count | Should -Be 1
        $pages[0].Results.name | Should -Be 'First'
        $pages[0].NextLink | Should -Be $nextLink
        $pages[1].PageNumber | Should -Be 2
        $pages[1].Count | Should -Be 2
        $pages[1].Results.name | Should -Be @('Second', 'Third')
        $pages[1].NextLink | Should -BeNullOrEmpty
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 2 -Exactly -ParameterFilter { $Headers['Prefer'] -eq 'odata.maxpagesize=1000' }
    }

    It 'rejects page output when returning raw responses' {
        { Invoke-PSDVWebRequest -WebUri 'accounts' -ReturnRawResponse -AsPages } | Should -Throw '*-AsPages cannot be used with -ReturnRawResponse*'
    }

    It 'returns the raw web response when requested' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return [PSCustomObject]@{ Content = '{"ok":true}'; StatusCode = 204 }
        }

        $result = Invoke-PSDVWebRequest -WebUri 'accounts' -ReturnRawResponse

        $result.StatusCode | Should -Be 204
    }
}
