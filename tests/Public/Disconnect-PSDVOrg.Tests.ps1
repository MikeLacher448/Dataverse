BeforeAll {
    . (Join-Path $PSScriptRoot 'PublicTestCommon.ps1')
}

Describe 'Disconnect-PSDVOrg' {
    BeforeEach {
        Initialize-PSDVPublicTestConnection
    }

    AfterEach {
        Clear-PSDVPublicTestConnection
    }

    It 'clears the current Dataverse connection state' {
        Disconnect-PSDVOrg

        $Global:DATAVERSEAUTHCONTEXT | Should -BeNullOrEmpty
        $Global:DATAVERSEACCESSTOKEN | Should -BeNullOrEmpty
        $Global:DATAVERSEORGURL | Should -BeNullOrEmpty
    }

    It 'honors WhatIf without clearing connection state' {
        Disconnect-PSDVOrg -WhatIf

        $Global:DATAVERSEAUTHCONTEXT | Should -Not -BeNullOrEmpty
        $Global:DATAVERSEACCESSTOKEN | Should -Not -BeNullOrEmpty
        $Global:DATAVERSEORGURL | Should -BeExactly 'https://example.crm.dynamics.com/'
    }
}
