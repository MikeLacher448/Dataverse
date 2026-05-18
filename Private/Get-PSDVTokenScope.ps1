function Get-PSDVTokenScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]
        $DataverseOrgURL
    )

    return "$($DataverseOrgURL.TrimEnd('/'))/.default"
}

