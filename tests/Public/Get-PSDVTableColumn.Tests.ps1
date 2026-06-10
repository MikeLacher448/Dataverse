BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Get-PSDVTableColumn' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'returns column details and enriches choice fields with option labels' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            if ($Uri -match 'PicklistAttributeMetadata') {
                return New-PSDVPublicTestWebResponse -Payload @{
                    value = @(
                        @{
                            LogicalName = 'accountcategorycode'
                            OptionSet = @{
                                Options = @(
                                    @{ Value = 1; Label = @{ LocalizedLabels = @(@{ Label = 'Preferred' }) } }
                                )
                            }
                        }
                    )
                }
            }

            return New-PSDVPublicTestWebResponse -Payload @{
                value = @(
                    @{
                        LogicalName = 'accountcategorycode'
                        DisplayName = @{ LocalizedLabels = @(@{ Label = 'Category' }) }
                        AttributeType = 'Picklist'
                        IsValidForCreate = $true
                        IsValidForUpdate = $true
                        IsValidForRead = $true
                        RequiredLevel = @{ Value = 'None' }
                        MaxLength = $null
                        Precision = $null
                        Targets = @()
                    }
                )
            }
        }

        $result = Get-PSDVTableColumn -Table 'account' -ColumnName 'accountcategorycode'

        $result.LogicalName | Should -BeExactly 'accountcategorycode'
        $result.DisplayName | Should -BeExactly 'Category'
        $result.ChoiceValues['Preferred'] | Should -Be 1
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 2 -Exactly
    }
}
