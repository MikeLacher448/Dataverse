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
        $AuthContext.Credential = switch ($AuthContext.ParameterSetName) {
            'ClientSecret' { New-PSDVClientSecretCredential -AuthContext $AuthContext }
            'ClientCertificate' { New-PSDVClientCertificateCredential -AuthContext $AuthContext }
            'ClientCertificateThumbprint' { New-PSDVClientCertificateCredential -AuthContext $AuthContext }
            'ClientCertificatePath' { New-PSDVClientCertificateCredential -AuthContext $AuthContext }
            'ManagedIdentity' { New-PSDVManagedIdentityCredential -AuthContext $AuthContext }
            'SystemManagedIdentity' { New-PSDVManagedIdentityCredential -AuthContext $AuthContext }
            'InteractiveLogin' { New-PSDVInteractiveCredential -AuthContext $AuthContext }
            default { throw "Unsupported authentication parameter set '$($AuthContext.ParameterSetName)'" }
        }
    }

    $scope = "$($AuthContext.ResourceUrl.TrimEnd('/'))/.default"
    $tokenRequestContext = [Azure.Core.TokenRequestContext]::new([String[]]@($scope))
    $sdkToken = $AuthContext.Credential.GetToken($tokenRequestContext, [System.Threading.CancellationToken]::None)

    return [PSCustomObject]@{
        Token     = ConvertTo-SecureString -String $sdkToken.Token -AsPlainText -Force
        ExpiresOn = $sdkToken.ExpiresOn.UtcDateTime
    }
}

