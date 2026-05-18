function New-PSDVInteractiveCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Hashtable]
        $AuthContext
    )

    if ($AuthContext.UseDeviceCode) {
        $options = [Azure.Identity.DeviceCodeCredentialOptions]::new()
        $options.TenantId = $AuthContext.AzureTenantId
        $options.ClientId = $script:PSDVPublicClientID
        $options.AuthorityHost = Get-PSDVAzureAuthorityHost -Environment $AuthContext.Environment
        $options.DeviceCodeCallback = [System.Func[Azure.Identity.DeviceCodeInfo, System.Threading.CancellationToken, System.Threading.Tasks.Task]] {
            param($deviceCodeInfo, $cancellationToken)
            Write-Information $deviceCodeInfo.Message -InformationAction Continue
            return [System.Threading.Tasks.Task]::CompletedTask
        }

        return [Azure.Identity.DeviceCodeCredential]::new($options)
    }

    $options = [Azure.Identity.InteractiveBrowserCredentialOptions]::new()
    $options.TenantId = $AuthContext.AzureTenantId
    $options.ClientId = $script:PSDVPublicClientID
    $options.AuthorityHost = Get-PSDVAzureAuthorityHost -Environment $AuthContext.Environment

    return [Azure.Identity.InteractiveBrowserCredential]::new($options)
}

