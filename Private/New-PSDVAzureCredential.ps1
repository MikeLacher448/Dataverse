function New-PSDVAzureCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Hashtable]
        $AuthContext
    )

    Import-PSDVAzureIdentityAssemblies

    switch ($AuthContext.ParameterSetName) {
        'ClientSecret' { return New-PSDVClientSecretCredential -AuthContext $AuthContext }
        'ClientCertificate' { return New-PSDVClientCertificateCredential -AuthContext $AuthContext }
        'ClientCertificateThumbprint' { return New-PSDVClientCertificateCredential -AuthContext $AuthContext }
        'ClientCertificatePath' { return New-PSDVClientCertificateCredential -AuthContext $AuthContext }
        'ManagedIdentity' { return New-PSDVManagedIdentityCredential -AuthContext $AuthContext }
        'SystemManagedIdentity' { return New-PSDVManagedIdentityCredential -AuthContext $AuthContext }
        'InteractiveLogin' { return New-PSDVInteractiveCredential -AuthContext $AuthContext }
        default { throw "Unsupported authentication parameter set '$($AuthContext.ParameterSetName)'" }
    }
}

