function ConvertTo-PSDVSdkAccessToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Object]
        $AccessToken
    )

    return [PSCustomObject]@{
        Token     = ConvertTo-SecureString -String $AccessToken.Token -AsPlainText -Force
        ExpiresOn = $AccessToken.ExpiresOn.UtcDateTime
    }
}

