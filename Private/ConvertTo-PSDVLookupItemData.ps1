function ConvertTo-PSDVLookupItemData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.Hashtable]
        $ItemData,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable]
        $AttributeDetails
    )

    $parsedItemData = @{}

    foreach ($attribute in $AttributeDetails.Keys) {
        if ($attribute -like '*@odata.bind') {
            $parsedItemData.Add($attribute, $ItemData[$attribute])
        }
        elseif ($AttributeDetails[$attribute].AttributeType -eq 'Lookup') {
            $navProperty = $AttributeDetails[$attribute].SchemaName
            $targetTable = $AttributeDetails[$attribute].Targets[0]
            $targetTableSet = Get-PSDVEntitySetFromLogicalName -Table $targetTable
            $targetItemID = $ItemData[$attribute]
            $parsedItemData.Add("$navProperty@odata.bind", "/$targetTableSet($targetItemID)")
        }
        else {
            $parsedItemData.Add($attribute, $ItemData[$attribute])
        }
    }

    return $parsedItemData
}
