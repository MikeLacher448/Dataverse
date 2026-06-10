. (Join-Path $PSScriptRoot 'PrivateTestCommon.ps1')

Describe 'ConvertFrom-PSDVSecureString' {
    It 'returns the original runtime-generated plain text value' {
        InModuleScope Dataverse {
            $secret = New-PSDVTestSecureString

            ConvertFrom-PSDVSecureString -SecureString $secret.SecureString | Should -BeExactly $secret.PlainText
        }
    }
}
