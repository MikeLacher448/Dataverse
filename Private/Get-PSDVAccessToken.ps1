function Get-PSDVAccessToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Hashtable]
        $AuthContext
    )

    $isManagedIdentity = $AuthContext.ParameterSetName -in @('ManagedIdentity', 'SystemManagedIdentity')
    if ($isManagedIdentity -and $AuthContext.ManagedIdentityTokenSource -eq 'FunctionRuntime') {
        return Get-PSDVFunctionRuntimeManagedIdentityAccessToken -AuthContext $AuthContext
    }

    Import-PSDVAzureIdentityAssemblies

    if ($null -eq $AuthContext.Credential) {
        $AuthContext.Credential = New-PSDVAzureCredential -AuthContext $AuthContext
    }

    $scope = Get-PSDVTokenScope -DataverseOrgURL $AuthContext.ResourceUrl
    $tokenRequestContext = [Azure.Core.TokenRequestContext]::new([String[]]@($scope))
    $sdkToken = $AuthContext.Credential.GetToken($tokenRequestContext, [System.Threading.CancellationToken]::None)

    return ConvertTo-PSDVSdkAccessToken -AccessToken $sdkToken
}

