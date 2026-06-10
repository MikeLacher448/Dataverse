BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Update-PSDVTableItem' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'updates an item with PATCH after validating attributes' {
        $itemId = [Guid]::NewGuid()

        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            if ($Uri -match '/EntityDefinitions\?') {
                return New-PSDVPublicTestWebResponse -Payload @{ LogicalName = 'account' }
            }
            if ($Uri -match "EntityDefinitions\(LogicalName='account'\)/Attributes") {
                return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ LogicalName = 'name'; AttributeType = 'String'; SchemaName = 'name'; Targets = @() }) }
            }

            return New-PSDVPublicTestWebResponse -Payload @{ accountid = $itemId; name = 'Updated' }
        }

        $result = Update-PSDVTableItem -EntitySet 'accounts' -ItemID $itemId -ItemData @{ name = 'Updated' } -ReturnItem

        $result.name | Should -BeExactly 'Updated'
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter { $Method -eq 'Patch' -and $Uri -match "/accounts\($itemId\)$" -and $Headers['Prefer'] -match 'return=representation' -and $Body -match 'Updated' }
    }

    It 'rejects an empty item ID before making a web request' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith { throw 'should not be called' }

        { Update-PSDVTableItem -EntitySet 'accounts' -ItemID ([Guid]::Empty) -ItemData @{ name = 'Updated' } } | Should -Throw 'ItemID cannot be an empty GUID'
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 0 -Exactly
    }
}
