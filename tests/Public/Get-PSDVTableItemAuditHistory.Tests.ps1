BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Get-PSDVTableItemAuditHistory' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'queries audit history for a table record' {
        $itemId = [Guid]::NewGuid()
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ auditid = [Guid]::NewGuid(); operation = 2 }) }
        }

        $result = Get-PSDVTableItemAuditHistory -Table 'account' -ItemID $itemId -Select @('createdon', 'operation')

        $result.operation | Should -Be 2
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter { $Uri -match '/audits' }
    }
}
