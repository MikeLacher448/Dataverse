BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'New-PSDVTableItem' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'creates an item in an entity set after validating supplied attributes' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            if ($Uri -match '/EntityDefinitions\?') {
                return New-PSDVPublicTestWebResponse -Payload @{ LogicalName = 'account' }
            }
            if ($Uri -match "EntityDefinitions\(LogicalName='account'\)/Attributes") {
                return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ LogicalName = 'name'; AttributeType = 'String'; SchemaName = 'name'; Targets = @() }) }
            }

            return New-PSDVPublicTestWebResponse -Payload @{ accountid = [Guid]::NewGuid(); name = 'Contoso' }
        } -ParameterFilter { $Uri -match 'EntityDefinitions|/accounts$' }

        $result = New-PSDVTableItem -EntitySet 'accounts' -ItemData @{ name = 'Contoso' } -ReturnItem

        $result.name | Should -BeExactly 'Contoso'
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 3 -Exactly
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter { $Method -eq 'Post' -and $Uri -match '/accounts$' -and $Headers['Prefer'] -match 'return=representation' -and $Body -match 'Contoso' }
    }
}
