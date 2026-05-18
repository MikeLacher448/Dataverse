function Get-PSDVCertificateFromPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]
        $CertificatePath,

        [Parameter()]
        [SecureString]
        $CertificatePassword
    )

    $resolvedCertificatePath = (Resolve-Path -Path $CertificatePath -ErrorAction Stop).Path
    $keyStorageFlags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet
    $plainTextPassword = if ($null -ne $CertificatePassword) { ConvertFrom-PSDVSecureString -SecureString $CertificatePassword } else { '' }
    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($resolvedCertificatePath, $plainTextPassword, $keyStorageFlags)

    if (-not $certificate.HasPrivateKey) {
        throw 'Certificate authentication requires a certificate with an accessible private key'
    }

    return $certificate
}

