. (Join-Path $PSScriptRoot 'PrivateTestCommon.ps1')

Describe 'ConvertTo-PSDVLookupItemData' {
    BeforeEach {
        InModuleScope Dataverse {
            $Global:DATAVERSEAUTHCONTEXT = New-PSDVTestAuthContext
            $Global:DATAVERSEACCESSTOKEN = New-PSDVTestAccessToken
            $Global:DATAVERSEORGURL = 'https://example.crm.dynamics.com/'
        }
    }

    AfterEach {
        InModuleScope Dataverse {
            $Global:DATAVERSEAUTHCONTEXT = $null
            $Global:DATAVERSEACCESSTOKEN = $null
            $Global:DATAVERSEORGURL = $null
        }
    }

    It 'converts lookup fields to OData bind entries and preserves scalar fields' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return [PSCustomObject]@{ Content = '{"EntitySetName":"accounts"}' }
        } -ParameterFilter { $Uri -match "EntityDefinitions\(LogicalName='account'\)" -and $Uri -match '%24select=EntitySetName' }

        InModuleScope Dataverse {
            $recordId = [Guid]::NewGuid()
            $attributes = @{
                fullname         = New-PSDVTestMetadataAttribute -LogicalName 'fullname'
                parentcustomerid = New-PSDVTestMetadataAttribute -LogicalName 'parentcustomerid' -AttributeType 'Lookup' -SchemaName 'parentcustomerid_account' -Targets @('account')
            }

            $result = ConvertTo-PSDVLookupItemData -ItemData @{ fullname = 'Ada'; parentcustomerid = $recordId } -AttributeDetails $attributes

            $result.fullname | Should -BeExactly 'Ada'
            $result['parentcustomerid_account@odata.bind'] | Should -BeExactly "/accounts($recordId)"
            $result.ContainsKey('parentcustomerid') | Should -BeFalse
        }
    }

    It 'preserves existing OData bind entries' {
        InModuleScope Dataverse {
            $recordId = [Guid]::NewGuid()
            $attributes = @{
                fullname                              = New-PSDVTestMetadataAttribute -LogicalName 'fullname'
                'parentcustomerid_account@odata.bind' = New-PSDVTestMetadataAttribute -LogicalName 'parentcustomerid' -AttributeType 'Lookup' -SchemaName 'parentcustomerid_account' -Targets @('account')
            }

            $result = ConvertTo-PSDVLookupItemData -ItemData @{ fullname = 'Ada'; 'parentcustomerid_account@odata.bind' = "/accounts($recordId)" } -AttributeDetails $attributes

            $result.fullname | Should -BeExactly 'Ada'
            $result['parentcustomerid_account@odata.bind'] | Should -BeExactly "/accounts($recordId)"
        }
    }
}
