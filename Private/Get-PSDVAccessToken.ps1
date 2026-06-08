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

    # Resolve the GetToken method and its TokenRequestContext parameter type directly from the
    # credential instance. In hosts that preload the Az modules (e.g. Azure Cloud Shell), more than
    # one version of Azure.Core can be present. Binding the [Azure.Core.TokenRequestContext] literal
    # may resolve to a different Azure.Core than the one the credential's GetToken expects, producing
    # "Cannot find an overload for GetToken and the argument count 2". Using reflection guarantees the
    # argument type matches the loaded credential's method signature.
    $getTokenMethod = $AuthContext.Credential.GetType().GetMethod(
        'GetToken',
        [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::Public)
    if ($null -eq $getTokenMethod) {
        throw "The configured credential of type '$($AuthContext.Credential.GetType().FullName)' does not expose a GetToken method."
    }

    $tokenRequestContextType = $getTokenMethod.GetParameters()[0].ParameterType
    $tokenRequestContextCtor = $tokenRequestContextType.GetConstructor([Type[]]@([string[]]))
    if ($null -eq $tokenRequestContextCtor) {
        throw "Unable to construct '$($tokenRequestContextType.FullName)' for the token request."
    }

    $tokenRequestContext = $tokenRequestContextCtor.Invoke(@(, [string[]]@($scope)))
    $sdkToken = $getTokenMethod.Invoke(
        $AuthContext.Credential,
        @($tokenRequestContext, [System.Threading.CancellationToken]::None))

    return [PSCustomObject]@{
        Token     = ConvertTo-SecureString -String $sdkToken.Token -AsPlainText -Force
        ExpiresOn = $sdkToken.ExpiresOn.UtcDateTime
    }
}

