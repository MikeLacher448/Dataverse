function Update-PSDVAccessToken {
    <#
    .SYNOPSIS
    Updates the Dataverse access token if it's close to expiration.

    .DESCRIPTION
    Update-PSDVAccessToken checks if the current Dataverse access token will expire within 5 minutes.
    If the token is approaching expiration, it automatically refreshes the token to ensure continued
    access to the Dataverse API without interruption.

    .EXAMPLE
    Update-PSDVAccessToken

    Checks and refreshes the access token if needed.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }

    if (($Global:DATAVERSEACCESSTOKEN.ExpiresOn).AddMinutes(-5) -le (Get-Date).ToUniversalTime() ) {
        if ($PSCmdlet.ShouldProcess("Access Token", "Refresh")) {
            if ($null -eq $Global:DATAVERSEAUTHCONTEXT) {
                throw 'No authentication context is available, run Connect-PSDVOrg again'
            }

            $accessToken = Get-PSDVAccessToken -AuthContext $Global:DATAVERSEAUTHCONTEXT
            if ($accessToken.PSObject.Properties.Name -contains 'RefreshToken') {
                $Global:DATAVERSEAUTHCONTEXT.RefreshToken = $accessToken.RefreshToken
            }

            $Global:DATAVERSEACCESSTOKEN = $accessToken
        }
    }
}

