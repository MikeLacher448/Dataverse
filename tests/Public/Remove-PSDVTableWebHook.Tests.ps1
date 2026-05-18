BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Remove-PSDVTableWebHook' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'deletes associated webhook steps and the service endpoint' {
        $serviceEndpointId = [Guid]::NewGuid()
        $stepId = [Guid]::NewGuid()

        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            if ($Uri -match "serviceendpoints\($serviceEndpointId\)" -and $Method -eq 'Get') {
                return New-PSDVPublicTestWebResponse -Payload @{ serviceendpointid = $serviceEndpointId; name = 'Account Endpoint'; url = 'https://example.test/webhook' }
            }
            if ($Uri -match 'sdkmessageprocessingsteps' -and $Method -eq 'Get') {
                return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ sdkmessageprocessingstepid = $stepId; name = 'Account Step' }) }
            }

            return New-PSDVPublicTestWebResponse -Payload $null
        }

        $result = Remove-PSDVTableWebHook -ServiceEndpointId $serviceEndpointId

        $result.Deleted | Should -BeTrue
        $result.ServiceEndpointId | Should -Be $serviceEndpointId
        $result.AssociatedStepsDeleted | Should -Be 1
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 4 -Exactly
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter { $Method -eq 'Delete' -and $Uri -match "sdkmessageprocessingsteps\($stepId\)" }
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter { $Method -eq 'Delete' -and $Uri -match "serviceendpoints\($serviceEndpointId\)" }
    }
}
