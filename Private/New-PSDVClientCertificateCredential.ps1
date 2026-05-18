function New-PSDVClientCertificateCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Hashtable]
        $AuthContext
    )

    $certificate = $AuthContext.Certificate
    if ($null -eq $certificate) {
        if (-not [string]::IsNullOrWhiteSpace($AuthContext.CertificateThumbprint)) {
            $certificate = Get-PSDVCertificateByThumbprint -CertificateThumbprint $AuthContext.CertificateThumbprint
        }
        elseif (-not [string]::IsNullOrWhiteSpace($AuthContext.CertificatePath)) {
            $certificate = Get-PSDVCertificateFromPath -CertificatePath $AuthContext.CertificatePath -CertificatePassword $AuthContext.CertificatePassword
        }
    }

    if ($null -eq $certificate -or -not $certificate.HasPrivateKey) {
        throw 'Certificate authentication requires a certificate with an accessible private key'
    }

    $options = [Azure.Identity.ClientCertificateCredentialOptions]::new()
    $options.AuthorityHost = Get-PSDVAzureAuthorityHost -Environment $AuthContext.Environment

    return [Azure.Identity.ClientCertificateCredential]::new(
        $AuthContext.AzureTenantId,
        $AuthContext.ClientID,
        $certificate,
        $options
    )
}

