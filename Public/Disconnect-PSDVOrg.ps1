function Disconnect-PSDVOrg {
    <#
    .SYNOPSIS
    Clears the current Dataverse connection from the PowerShell session.

    .DESCRIPTION
    Disconnect-PSDVOrg removes the module's global Dataverse authentication context, access token, and organization URL from the current PowerShell session.

    .EXAMPLE
    Disconnect-PSDVOrg

    Clears the current Dataverse connection state.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($PSCmdlet.ShouldProcess('Dataverse connection state', 'Clear')) {
        $Global:DATAVERSEAUTHCONTEXT = $null
        $Global:DATAVERSEACCESSTOKEN = $null
        $Global:DATAVERSEORGURL = $null
        Write-Verbose 'Disconnected from Dataverse environment'
    }
}
