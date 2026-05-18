function New-PSDVClientSecretCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Hashtable]
        $AuthContext
    )

    $options = [Azure.Identity.ClientSecretCredentialOptions]::new()
    $options.AuthorityHost = Get-PSDVAzureAuthorityHost -Environment $AuthContext.Environment

    return [Azure.Identity.ClientSecretCredential]::new(
        $AuthContext.AzureTenantId,
        $AuthContext.ClientID,
        (ConvertFrom-PSDVSecureString -SecureString $AuthContext.ClientSecret),
        $options
    )
}

