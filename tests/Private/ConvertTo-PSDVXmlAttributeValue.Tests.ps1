. (Join-Path $PSScriptRoot 'PrivateTestCommon.ps1')

Describe 'ConvertTo-PSDVXmlAttributeValue' {
    It 'escapes XML attribute-sensitive characters' {
        InModuleScope Dataverse {
            ConvertTo-PSDVXmlAttributeValue -Value "a&b<'`"" | Should -BeExactly 'a&amp;b&lt;&apos;&quot;'
        }
    }

    It 'allows empty strings' {
        InModuleScope Dataverse {
            ConvertTo-PSDVXmlAttributeValue -Value '' | Should -BeExactly ''
        }
    }
}
