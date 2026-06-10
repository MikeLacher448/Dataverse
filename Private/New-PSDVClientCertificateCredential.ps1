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
            $normalizedThumbprint = $AuthContext.CertificateThumbprint.Replace(' ', '').ToUpperInvariant()
            $certificate = Get-ChildItem -Path Cert:\CurrentUser\My, Cert:\LocalMachine\My -ErrorAction SilentlyContinue |
                Where-Object { $_.Thumbprint -eq $normalizedThumbprint } |
                Select-Object -First 1

            if ($null -eq $certificate) {
                throw "Certificate with thumbprint '$($AuthContext.CertificateThumbprint)' was not found in CurrentUser or LocalMachine personal certificate stores"
            }
        }
        elseif (-not [string]::IsNullOrWhiteSpace($AuthContext.CertificatePath)) {
            $resolvedCertificatePath = (Resolve-Path -Path $AuthContext.CertificatePath -ErrorAction Stop).Path
            $keyStorageFlags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet
            $plainTextPassword = if ($null -ne $AuthContext.CertificatePassword) { ConvertFrom-PSDVSecureString -SecureString $AuthContext.CertificatePassword } else { '' }
            $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($resolvedCertificatePath, $plainTextPassword, $keyStorageFlags)
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

