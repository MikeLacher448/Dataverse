function Confirm-PSDVItemDataAttributes {
    [CmdletBinding()]
    param(
        [Parameter()]
        [String]
        $Table,

        [Parameter()]
        [String]
        $EntitySet,

        [Parameter(Mandatory)]
        [System.Collections.Hashtable]
        $ItemData
    )

    if ([string]::IsNullOrWhiteSpace($Table)) {
        $entitySetLiteral = ConvertTo-PSDVODataStringLiteral -Value $EntitySet
        $Table = (Invoke-PSDVWebRequest -WebUri 'EntityDefinitions' -Filter "EntitySetName eq $entitySetLiteral" -Select 'LogicalName').LogicalName
    }

    $tableLiteral = ConvertTo-PSDVODataStringLiteral -Value $Table
    $tableColumns = Invoke-PSDVWebRequest -WebUri "EntityDefinitions(LogicalName=$tableLiteral)/Attributes"
    $attributeDetails = @{}
    $invalidAttributes = @()

    foreach ($attribute in $ItemData.Keys) {
        if ($tableColumns.LogicalName -notcontains $attribute) {
            $invalidAttributes += $attribute
        }
        else {
            $attributeDetails.Add($attribute, ($tableColumns | Where-Object { $_.LogicalName -eq $attribute } | Select-Object -Property AttributeType, SchemaName, Targets))
        }
    }

    if ($invalidAttributes.Count -gt 0) {
        throw "Invalid attributes not present in $Table : $($invalidAttributes -join ', ')"
    }

    return [PSCustomObject]@{
        Table            = $Table
        AttributeDetails = $attributeDetails
    }
}
