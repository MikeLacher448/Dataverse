BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Get-PSDVTableDetail' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'returns table metadata with attributes indexed by logical name' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            if ($Uri -match '/Attributes') {
                return New-PSDVPublicTestWebResponse -Payload @{
                    value = @(
                        @{ LogicalName = 'name'; AttributeType = 'String' },
                        @{ LogicalName = 'accountnumber'; AttributeType = 'String' }
                    )
                }
            }

            return New-PSDVPublicTestWebResponse -Payload @{
                LogicalName = 'account'
                EntitySetName = 'accounts'
            }
        }

        $result = Get-PSDVTableDetail -Table 'account'

        $result.LogicalName | Should -BeExactly 'account'
        $result.EntitySetName | Should -BeExactly 'accounts'
        $result.Fields.Keys | Should -Contain 'name'
        $result.Fields['accountnumber'].AttributeType | Should -BeExactly 'String'
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 2 -Exactly
    }
}
