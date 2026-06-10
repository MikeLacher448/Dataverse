BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Get-PSDVTableItem' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'queries records from an entity set with select, filter, expand, and top options' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return New-PSDVPublicTestWebResponse -Payload @{
                value = @(
                    @{ accountid = [Guid]::NewGuid(); name = 'Contoso' }
                )
            }
        }

        $result = Get-PSDVTableItem -EntitySet 'accounts' -Select @('name', 'accountnumber') -Filter "name eq 'Contoso'" -Expand 'primarycontactid' -Top 1

        @($result).Count | Should -Be 1
        $result.name | Should -BeExactly 'Contoso'
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter { $Uri -match '/accounts' -and $Headers['Prefer'] -eq 'odata.include-annotations="*"' }
    }

    It 'throws when no Dataverse connection exists' {
        Clear-PSDVPublicTestConnection

        { Get-PSDVTableItem -EntitySet 'accounts' } | Should -Throw 'No existing connection to Dataverse Environment*'
    }
}
