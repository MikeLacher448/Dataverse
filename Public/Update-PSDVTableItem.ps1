function Update-PSDVTableItem {
    <#
    .SYNOPSIS
    Updates an existing record in a Dataverse table.

    .DESCRIPTION
    Update-PSDVTableItem modifies an existing record in the specified Dataverse table using the provided data.
    It supports automatic field validation to ensure all provided fields exist in the target table.
    The function can optionally parse lookup relationships and convert them to the proper OData format.
    When ReturnItem is specified, it returns the updated record with current field values.
    Only the specified fields are updated; other fields remain unchanged.

    .PARAMETER Table
    The logical name of the Dataverse table containing the record to update.

    .PARAMETER EntitySet
    The entity set name of the Dataverse table (alternative to Table parameter).

    .PARAMETER ItemID
    The unique identifier (GUID) of the record to update.

    .PARAMETER ItemData
    Hashtable containing the field names and values to update in the record.

    .PARAMETER ParseItemData
    When specified, automatically parses lookup field values and converts them to OData format.

    .PARAMETER ReturnItem
    When specified, returns the updated record with current field values.

    .EXAMPLE
    $updateData = @{
        name = "Updated Company Name"
        telephone1 = "555-987-6543"
    }
    Update-PSDVTableItem -Table "account" -ItemID "12345678-1234-1234-1234-123456789012" -ItemData $updateData

    Updates an account record with new name and phone number.

    .EXAMPLE
    $contactUpdate = @{
        emailaddress1 = "newemail@contoso.com"
        parentcustomerid = "11111111-1111-1111-1111-111111111111"
    }
    Update-PSDVTableItem -Table "contact" -ItemID "87654321-4321-4321-4321-210987654321" -ItemData $contactUpdate -ParseItemData -ReturnItem

    Updates a contact's email and parent account, parses the lookup, and returns the updated record.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [parameter(Mandatory, ParameterSetName = 'TableLogicalName')]
        [String]
        $Table,

        [parameter(Mandatory, ParameterSetName = 'TableEntitySetName')]
        [string]
        $EntitySet,

        [parameter(Mandatory)]
        [System.Guid]
        $ItemID,

        [parameter(Mandatory)]
        [System.Collections.Hashtable]
        $ItemData,

        [parameter()]
        [switch]
        $ParseItemData,

        [parameter()]
        [switch]
        $ReturnItem
    )

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }

    if ($ItemID -eq [Guid]::Empty) {
        throw 'ItemID cannot be an empty GUID'
    }

    #lookup table relationships require setting the Microsoft.Dynamics.CRM.associatednavigationproperty odata.bind = /entitysetname(item ID)
    # ex, "cr33a_MACOM@odata.bind" = "/cr33a_macoms(b7322079-55d2-ee11-9078-000d3a33b5cf)"

    if (($PSCmdlet.ParameterSetName).StartsWith('TableLogicalName')) {
        $EntitySet = Get-PSDVEntitySetFromLogicalName -Table $Table
    }


    $requestHeaders = @{
        'Prefer'       = 'odata.include-annotations="*"'
    }

    if ($ReturnItem.IsPresent) {
        $requestHeaders['Prefer'] = 'odata.include-annotations="*",return=representation'
    }

    $itemDataValidation = Confirm-PSDVItemDataAttributes -Table $Table -EntitySet $EntitySet -ItemData $ItemData
    $Table = $itemDataValidation.Table
    $attributeDetails = $itemDataValidation.AttributeDetails

    if ($ParseItemData.IsPresent) {
        $ItemData2Process = ConvertTo-PSDVLookupItemData -ItemData $ItemData -AttributeDetails $attributeDetails
    }
    else {
        $ItemData2Process = $ItemData
    }


    $dvRequestUri = "$EntitySet($ItemID)"

    if ($PSCmdlet.ShouldProcess("$EntitySet($ItemID)", "Update item")) {
        return (Invoke-PSDVWebRequest -WebUri  $dvRequestUri -Headers $requestHeaders -Body $ItemData2Process -Method 'Patch' )
    }

}

