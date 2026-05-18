function Read-PSDVTableData {
    <#
    .SYNOPSIS
    Retrieves metadata for all tables in the Dataverse environment.

    .DESCRIPTION
    Read-PSDVTableData fetches information about all tables (entities) available in the connected Dataverse environment.
    It returns basic metadata including logical names, display names, and entity set names for each table.
    This function is marked as legacy and is primarily used for compatibility with older code.

    .EXAMPLE
    Read-PSDVTableData

    Returns metadata for all tables in the Dataverse environment.

    .EXAMPLE
    Read-PSDVTableData | Where-Object { $_.LogicalName -like "*custom*" }

    Returns metadata for all custom tables (containing "custom" in the name).
    #>

#legacy function

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }

    try {
        $webResponse = Invoke-PSDVWebRequest -Method Get -WebUri ($Global:DATAVERSEORGURL + 'api/data/v9.2/EntityDefinitions?$select=DisplayName,LogicalName,EntitySetName')
    }
    catch {
        throw "Error getting Dataverse Entity Definitions: $($_.InvocationInfo.MyCommand.Name), $($_ | Out-String)"
    }


    foreach ($t in $webResponse) {
        [PSCustomObject]@{
            LogicalName = $t.LogicalName
            DisplayName   = $t.DisplayName.LocalizedLabels[0].Label
            EntitySetName = $t.EntitySetName
        }
    }
}

