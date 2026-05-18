function Get-PSDVAzureAuthorityHost {
    [CmdletBinding()]
    param(
        [Parameter()]
        [String]
        $Environment = 'AzureCloud'
    )

    if ([string]::IsNullOrWhiteSpace($Environment)) {
        $Environment = 'AzureCloud'
    }

    if (-not $script:PSDVAzureAuthorityHosts.ContainsKey($Environment)) {
        throw "Unsupported Azure environment '$Environment'"
    }

    return [System.Uri]::new($script:PSDVAzureAuthorityHosts[$Environment])
}

