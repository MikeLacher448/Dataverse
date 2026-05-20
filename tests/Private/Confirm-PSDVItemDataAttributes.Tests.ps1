. (Join-Path $PSScriptRoot 'PrivateTestCommon.ps1')

Describe 'Confirm-PSDVItemDataAttributes' {
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

    It 'returns metadata for valid item attributes' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return [PSCustomObject]@{ Content = '{"value":[{"LogicalName":"name","AttributeType":"String","SchemaName":"name","Targets":[]},{"LogicalName":"primarycontactid","AttributeType":"Lookup","SchemaName":"primarycontactid_contact","Targets":["contact"]}]}' }
        } -ParameterFilter { $Uri -match "EntityDefinitions\(LogicalName='account'\)/Attributes" }

        InModuleScope Dataverse {
            $result = Confirm-PSDVItemDataAttributes -Table 'account' -ItemData @{ name = 'Contoso'; primarycontactid = [Guid]::NewGuid() }

            $result.Table | Should -BeExactly 'account'
            $result.AttributeDetails.Keys | Should -Contain 'name'
            $result.AttributeDetails.Keys | Should -Contain 'primarycontactid'
        }
    }

    It 'resolves logical name from entity set when table is not supplied' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            if ($Uri -match '/EntityDefinitions\?') {
                return [PSCustomObject]@{ Content = '{"LogicalName":"contact"}' }
            }

            return [PSCustomObject]@{ Content = '{"value":[{"LogicalName":"fullname","AttributeType":"String","SchemaName":"fullname","Targets":[]}]}' }
        }

        InModuleScope Dataverse {
            $result = Confirm-PSDVItemDataAttributes -EntitySet 'contacts' -ItemData @{ fullname = 'Ada' }

            $result.Table | Should -BeExactly 'contact'
        }

        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 2 -Exactly
    }

    It 'throws when item data contains invalid attributes' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return [PSCustomObject]@{ Content = '{"value":[{"LogicalName":"name","AttributeType":"String","SchemaName":"name","Targets":[]}]}' }
        }

        InModuleScope Dataverse {
            { Confirm-PSDVItemDataAttributes -Table 'account' -ItemData @{ invalidfield = 'value' } } | Should -Throw 'Invalid attributes not present in account : invalidfield'
        }
    }
}
