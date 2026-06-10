. (Join-Path $PSScriptRoot 'PrivateTestCommon.ps1')

Describe 'Join-PSDVQueryString' {
    It 'URL-encodes keys and values in insertion order' {
        InModuleScope Dataverse {
            $query = [ordered]@{
                '$select' = 'name,accountnumber'
                '$filter' = "name eq 'A&B'"
            }

            Join-PSDVQueryString -QueryParameters $query | Should -BeExactly '%24select=name%2Caccountnumber&%24filter=name%20eq%20%27A%26B%27'
        }
    }

    It 'omits null and whitespace-only values' {
        InModuleScope Dataverse {
            $query = [ordered]@{
                keep      = 'value'
                skipNull  = $null
                skipBlank = '   '
            }

            Join-PSDVQueryString -QueryParameters $query | Should -BeExactly 'keep=value'
        }
    }
}
