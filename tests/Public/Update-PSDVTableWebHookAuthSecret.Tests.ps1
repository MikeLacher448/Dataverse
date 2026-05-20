BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Update-PSDVTableWebHookAuthSecret' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'updates a webhook service endpoint auth value by webhook step ID' {
        $webhookStepId = [Guid]::NewGuid()
        $serviceEndpointId = [Guid]::NewGuid()
        $runtimeSecret = [Guid]::NewGuid().ToString('N')

        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            if ($Uri -match "sdkmessageprocessingsteps\($webhookStepId\)" -and $Method -eq 'Get') {
                return New-PSDVPublicTestWebResponse -Payload @{
                    sdkmessageprocessingstepid = $webhookStepId
                    name = 'Account Webhook Step'
                    eventhandler_serviceendpoint = @{
                        serviceendpointid = $serviceEndpointId
                        name = 'Account Endpoint'
                        url = 'https://example.test/webhook'
                    }
                    sdkmessagefilterid = @{ primaryobjecttypecode = 'account' }
                }
            }

            return New-PSDVPublicTestWebResponse -Payload $null
        }

        $result = Update-PSDVTableWebHookAuthSecret -Table 'account' -WebHookStepId $webhookStepId -AuthSecret $runtimeSecret

        $result.AuthSecretUpdated | Should -BeTrue
        $result.WebHookStepId | Should -Be $webhookStepId
        $result.ServiceEndpointId | Should -Be $serviceEndpointId
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 2 -Exactly
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter { $Method -eq 'Patch' -and $Uri -match "serviceendpoints\($serviceEndpointId\)" -and $Body -match $runtimeSecret }
    }
}
