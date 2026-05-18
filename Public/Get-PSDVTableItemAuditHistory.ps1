function Get-PSDVTableItemAuditHistory {
    <#
    .SYNOPSIS
    Retrieves audit history for a specific Dataverse record.

    .DESCRIPTION
    Get-PSDVTableItemAuditHistory fetches the audit trail for a specific record in a Dataverse table.
    It returns audit information including who made changes, when changes were made, and what operations
    were performed. This function is useful for compliance, troubleshooting, and tracking data modifications.
    Auditing must be enabled on the table and fields for this function to return meaningful data.

    .PARAMETER Table
    The logical name of the Dataverse table containing the record.

    .PARAMETER ItemID
    The unique identifier (GUID) of the record to retrieve audit history for.

    .PARAMETER Select
    Array of audit field names to include in the response.

    .EXAMPLE
    Get-PSDVTableItemAuditHistory -Table "account" -ItemID "12345678-1234-1234-1234-123456789012"

    Retrieves all audit history for a specific account record.

    .EXAMPLE
    Get-PSDVTableItemAuditHistory -Table "contact" -ItemID "87654321-4321-4321-4321-210987654321" -Select @("createdon", "createdby", "operation")

    Retrieves specific audit fields for a contact record.
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [String]
        $Table,

        [parameter()]
        [String]
        $ItemID,

        [parameter()]
        [String[]]
        $Select
    )

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }


    Update-PSDVAccessToken

    $requestHeaders = @{'Prefer' = 'odata.include-annotations="*"' }

    $queryFilter = "objecttypecode eq '$Table' and _objectid_value eq '$ItemID'"

    if ($PSBoundParameters.ContainsKey('Select')) {
      $selectQuery = $Select -join ','
    }

    $dvRequestUri = $Global:DATAVERSEORGURL + 'api/data/v9.2/audits'

    $dvRequestUri += "?`$filter=$queryFilter"

    if ($selectQuery.Length -gt 0) {
        $dvRequestUri += "&`$select=$selectQuery"
    }

    return (Invoke-PSDVWebRequest -WebUri  $dvRequestUri -Headers $requestHeaders -Method 'Get')

}

