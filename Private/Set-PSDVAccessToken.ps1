function Set-PSDVAccessToken {
    [CmdletBinding()]
    param(
        [Parameter()]
        [Object]
        $AccessToken,

        [Parameter()]
        [Hashtable]
        $AuthContext = $Global:DATAVERSEAUTHCONTEXT,

        [Parameter()]
        [String]
        $Operation = 'Token acquisition'
    )

    if ($null -eq $AuthContext) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }

    if ($null -eq $AccessToken) {
        if ($null -ne $Global:DATAVERSEACCESSTOKEN -and ($Global:DATAVERSEACCESSTOKEN.ExpiresOn).AddMinutes(-5) -gt (Get-Date).ToUniversalTime()) {
            return
        }

        if ($AuthContext.ParameterSetName -eq 'AccessToken') {
            throw 'The access token supplied to Connect-PSDVOrg has expired or is about to expire and cannot be refreshed automatically. Acquire a new token and run Connect-PSDVOrg again with the -AccessToken parameter.'
        }

        Write-Verbose 'Refreshing Dataverse access token'
        $AccessToken = Get-PSDVAccessToken -AuthContext $AuthContext
        $Operation = 'Access token refresh'
    }

    if ($null -eq $AccessToken) {
        throw "$Operation did not return an access token."
    }

    $propertyNames = $AccessToken.PSObject.Properties.Name
    if ($propertyNames -notcontains 'Token' -or $null -eq $AccessToken.Token) {
        throw "$Operation returned an access token object without a Token value."
    }

    if ($propertyNames -notcontains 'ExpiresOn' -or $null -eq $AccessToken.ExpiresOn) {
        throw "$Operation returned an access token object without an ExpiresOn value."
    }

    $expiresOn = ([DateTimeOffset]$AccessToken.ExpiresOn).UtcDateTime
    if ($expiresOn -le (Get-Date).ToUniversalTime()) {
        throw "$Operation returned an access token that is already expired."
    }

    if ($propertyNames -contains 'RefreshToken') {
        $AuthContext.RefreshToken = $AccessToken.RefreshToken
    }

    $Global:DATAVERSEACCESSTOKEN = $AccessToken
}
