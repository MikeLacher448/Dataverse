BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Get-PSDVTableItemChangeHistory' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'returns the audit detail collection from RetrieveRecordChangeHistory' {
        $itemId = [Guid]::NewGuid()
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return New-PSDVPublicTestWebResponse -Payload @{
                AuditDetailCollection = @(
                    @{ AuditRecord = @{ auditid = [Guid]::NewGuid() }; ChangedAttributes = @('name') }
                )
            }
        } -ParameterFilter { $Uri -match 'RetrieveRecordChangeHistory' -and $Uri -match 'accounts' -and $Uri -match "$itemId" }

        $result = Get-PSDVTableItemChangeHistory -EntitySet 'accounts' -ItemID $itemId

        @($result).Count | Should -Be 1
        $result.ChangedAttributes | Should -Contain 'name'
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly
    }
}
