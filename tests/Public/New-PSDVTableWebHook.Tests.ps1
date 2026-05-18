BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'New-PSDVTableWebHook' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'creates a service endpoint and webhook step for a table operation' {
        $serviceEndpointId = [Guid]::NewGuid()
        $sdkMessageId = [Guid]::NewGuid()
        $sdkMessageFilterId = [Guid]::NewGuid()
        $webhookStepId = [Guid]::NewGuid()
        $runtimeSecret = [Guid]::NewGuid().ToString('N')

        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith {
            if ($Uri -match 'sdkmessageprocessingsteps' -and $Method -eq 'Get') {
                return New-PSDVPublicTestWebResponse -Payload @{ value = @() }
            }
            if ($Uri -match 'serviceendpoints' -and $Method -eq 'Post') {
                return New-PSDVPublicTestWebResponse -Payload @{ serviceendpointid = $serviceEndpointId; name = 'Account Webhook' }
            }
            if ($Uri -match 'sdkmessages' -and $Method -eq 'Get') {
                return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ sdkmessageid = $sdkMessageId; name = 'Update' }) }
            }
            if ($Uri -match 'sdkmessagefilters' -and $Method -eq 'Get') {
                return New-PSDVPublicTestWebResponse -Payload @{ value = @(@{ sdkmessagefilterid = $sdkMessageFilterId; primaryobjecttypecode = 'account' }) }
            }
            if ($Uri -match 'sdkmessageprocessingsteps' -and $Method -eq 'Post') {
                return New-PSDVPublicTestWebResponse -Payload @{ sdkmessageprocessingstepid = $webhookStepId; name = 'account.webhook.account.update' }
            }

            throw "Unexpected request: $Method $Uri"
        }

        $result = New-PSDVTableWebHook -Table 'account' -WebHookName 'Account Webhook' -TriggerUri 'https://example.test/webhook' -Operation Update -FilteringAttributes @('name') -AuthSecret $runtimeSecret

        $result.WebHookName | Should -BeExactly 'Account Webhook'
        $result.ServiceEndpointId | Should -Be $serviceEndpointId
        $result.WebHookStepId | Should -Be $webhookStepId
        $result.FilteringAttributes | Should -Be @('name')
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 5 -Exactly
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 1 -Exactly -ParameterFilter { $Method -eq 'Post' -and $Uri -match 'serviceendpoints' -and $Body -match $runtimeSecret }
    }

    It 'rejects filtering attributes for non-update operations before making a web request' {
        Mock -CommandName Invoke-WebRequest -ModuleName Dataverse -MockWith { throw 'should not be called' }

        { New-PSDVTableWebHook -Table 'account' -WebHookName 'Account Webhook' -TriggerUri 'https://example.test/webhook' -Operation Create -FilteringAttributes @('name') } | Should -Throw 'FilteringAttributes parameter can only be used with Update operations*'
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName Dataverse -Times 0 -Exactly
    }
}
