BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Remove-PSDVTableItem' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'deletes an item from an entity set' {
        $itemId = [Guid]::NewGuid()
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return New-PSDVPublicTestWebResponse -Payload $null
        } -ParameterFilter { $Method -eq 'Delete' -and $Uri -match "/accounts\($itemId\)$" }

        Remove-PSDVTableItem -EntitySet 'accounts' -ItemID $itemId

        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly
    }
}
