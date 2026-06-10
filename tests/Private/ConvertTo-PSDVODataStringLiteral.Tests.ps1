. (Join-Path $PSScriptRoot 'PrivateTestCommon.ps1')

Describe 'ConvertTo-PSDVODataStringLiteral' {
    It 'wraps a value in single quotes' {
        InModuleScope Dataverse {
            ConvertTo-PSDVODataStringLiteral -Value 'account' | Should -BeExactly "'account'"
        }
    }

    It 'escapes embedded single quotes for OData string literals' {
        InModuleScope Dataverse {
            ConvertTo-PSDVODataStringLiteral -Value "O'Hara" | Should -BeExactly "'O''Hara'"
        }
    }

    It 'allows empty strings' {
        InModuleScope Dataverse {
            ConvertTo-PSDVODataStringLiteral -Value '' | Should -BeExactly "''"
        }
    }
}
