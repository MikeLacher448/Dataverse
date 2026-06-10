function New-PSDVManagedIdentityCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Hashtable]
        $AuthContext
    )

    $managedIdentityID = $AuthContext.ManagedIdentityID

    if ([string]::IsNullOrWhiteSpace($managedIdentityID)) {
        return [Azure.Identity.ManagedIdentityCredential]::new()
    }

    if ($managedIdentityID.StartsWith('/subscriptions/', [System.StringComparison]::OrdinalIgnoreCase)) {
        $resourceId = [Azure.Core.ResourceIdentifier]::new($managedIdentityID)
        return [Azure.Identity.ManagedIdentityCredential]::new($resourceId)
    }

    return [Azure.Identity.ManagedIdentityCredential]::new($managedIdentityID)
}

