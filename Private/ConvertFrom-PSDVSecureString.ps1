function ConvertFrom-PSDVSecureString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [SecureString]
        $SecureString
    )

    $credential = [System.Management.Automation.PSCredential]::new('PSDVSecret', $SecureString)
    return $credential.GetNetworkCredential().Password
}

