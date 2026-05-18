function Get-PSDVCertificateByThumbprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]
        $CertificateThumbprint
    )

    $normalizedThumbprint = $CertificateThumbprint.Replace(' ', '').ToUpperInvariant()
    $certificate = Get-ChildItem -Path Cert:\CurrentUser\My, Cert:\LocalMachine\My -ErrorAction SilentlyContinue |
        Where-Object { $_.Thumbprint -eq $normalizedThumbprint } |
        Select-Object -First 1

    if ($null -eq $certificate) {
        throw "Certificate with thumbprint '$CertificateThumbprint' was not found in CurrentUser or LocalMachine personal certificate stores"
    }

    return $certificate
}

