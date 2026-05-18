BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Read-PSDVTableData' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'returns simplified metadata for available Dataverse tables' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return New-PSDVPublicTestWebResponse -Payload @{
                value = @(
                    @{
                        LogicalName = 'account'
                        EntitySetName = 'accounts'
                        DisplayName = @{ LocalizedLabels = @(@{ Label = 'Account' }) }
                    }
                )
            }
        } -ParameterFilter { $Uri -match 'EntityDefinitions' -and $Uri -match '%24select=DisplayName%2CLogicalName%2CEntitySetName' }

        $result = Read-PSDVTableData

        $result.LogicalName | Should -BeExactly 'account'
        $result.DisplayName | Should -BeExactly 'Account'
        $result.EntitySetName | Should -BeExactly 'accounts'
    }
}
