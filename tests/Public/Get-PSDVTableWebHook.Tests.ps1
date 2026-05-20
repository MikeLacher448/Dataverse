BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Get-PSDVTableWebHook' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'returns friendly webhook registration objects from SDK message processing steps' {
        $stepId = [Guid]::NewGuid()
        $serviceEndpointId = [Guid]::NewGuid()

        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            return New-PSDVPublicTestWebResponse -Payload @{
                value = @(
                    @{
                        sdkmessageprocessingstepid = $stepId
                        name = 'Account Create Webhook'
                        description = 'Account create notification'
                        stage = 40
                        rank = 1
                        mode = 1
                        statuscode = 1
                        supporteddeployment = 0
                        filteringattributes = 'name,accountnumber'
                        eventhandler_serviceendpoint = @{
                            serviceendpointid = $serviceEndpointId
                            name = 'Account Endpoint'
                            url = 'https://example.test/webhook'
                            authtype = 5
                            iscustomizable = @{ Value = $true }
                        }
                        sdkmessagefilterid = @{ primaryobjecttypecode = 'account' }
                        sdkmessageid = @{ name = 'Create' }
                    }
                )
            }
        }

        $result = Get-PSDVTableWebHook -Table 'account'

        $result.WebHookStepId | Should -Be $stepId
        $result.ServiceEndpointId | Should -Be $serviceEndpointId
        $result.Stage | Should -BeExactly 'PostOperation'
        $result.Mode | Should -BeExactly 'Asynchronous'
        $result.ColumnFilter | Should -Be @('name', 'accountnumber')
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter { $Uri -match '/sdkmessageprocessingsteps' }
    }
}
