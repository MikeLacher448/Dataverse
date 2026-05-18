function Get-PSDVTableItem {
    <#
    .SYNOPSIS
    Retrieves records from a Dataverse table.

    .DESCRIPTION
    Get-PSDVTableItem fetches one or more records from a specified Dataverse table. It supports both
    single record retrieval by ID and querying multiple records with filters. The function provides
    flexible parameter sets for different scenarios and includes support for field selection, record
    expansion, and filtering. Legacy parameter names are supported for backward compatibility but
    will generate deprecation warnings.

    .PARAMETER Table
    The logical name of the Dataverse table to retrieve records from.

    .PARAMETER EntitySet
    The entity set name of the Dataverse table (alternative to Table parameter).

    .PARAMETER ItemID
    The unique identifier (GUID) of a specific record to retrieve.

    .PARAMETER Filter
    OData filter expression to specify which records to retrieve.

    .PARAMETER Expand
    OData expand expression to include related records in the response.

    .PARAMETER Select
    Array of field names to include in the response (limits returned data).

    .PARAMETER FilterQuery
    Legacy parameter name for Filter (deprecated, use Filter instead).

    .PARAMETER ExpandQuery
    Legacy parameter name for Expand (deprecated, use Expand instead).

    .PARAMETER Top
    The maximum number of records to return. Corresponds to the OData $top query parameter.

    .PARAMETER SelectFields
    Legacy parameter name for Select (deprecated, use Select instead).

    .EXAMPLE
    Get-PSDVTableItem -Table "account" -ItemID "12345678-1234-1234-1234-123456789012"

    Retrieves a specific account record by its ID.

    .EXAMPLE
    Get-PSDVTableItem -Table "contact" -Filter "firstname eq 'John'" -Select @("firstname", "lastname", "emailaddress1")

    Retrieves contacts named John with only specific fields.

    .EXAMPLE
    Get-PSDVTableItem -Table "account" -Filter "revenue gt 1000000" -Expand "primarycontactid"

    Retrieves accounts with revenue over $1M and includes primary contact details.

    .EXAMPLE
    Get-PSDVTableItem -EntitySet "accounts" -Filter "name contains 'Microsoft'"

    Retrieves accounts containing "Microsoft" in the name using entity set name.

    .EXAMPLE
    Get-PSDVTableItem -Table "account" -Top 10

    Retrieves the first 10 account records.
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory, ParameterSetName = 'TableLogicalNameItemLookup')]
        [parameter(Mandatory, ParameterSetName = 'TableLogicalNameQuery')]
        [parameter(Mandatory, ParameterSetName = 'TableLogicalNameItemLookupLegacy')]
        [parameter(Mandatory, ParameterSetName = 'TableLogicalNameQueryLegacy')]
        [String]
        $Table,

        [parameter(Mandatory, ParameterSetName = 'TableEntitySetNameItemLookup')]
        [parameter(Mandatory, ParameterSetName = 'TableEntitySetNameQuery')]
        [parameter(Mandatory, ParameterSetName = 'TableEntitySetNameItemLookupLegacy')]
        [parameter(Mandatory, ParameterSetName = 'TableEntitySetNameQueryLegacy')]
        [string]
        $EntitySet,

        [parameter(Mandatory, ParameterSetName = 'TableLogicalNameItemLookup')]
        [parameter(Mandatory, ParameterSetName = 'TableEntitySetNameItemLookup')]
        [parameter(Mandatory, ParameterSetName = 'TableLogicalNameItemLookupLegacy')]
        [parameter(Mandatory, ParameterSetName = 'TableEntitySetNameItemLookupLegacy')]
        [guid]
        $ItemID,

        [parameter(ParameterSetName = 'TableLogicalNameQuery')]
        [parameter(ParameterSetName = 'TableEntitySetNameQuery')]
        [String]
        $Filter,

        [parameter(ParameterSetName = 'TableLogicalNameItemLookup')]
        [parameter(ParameterSetName = 'TableLogicalNameQuery')]
        [parameter(ParameterSetName = 'TableEntitySetNameItemLookup')]
        [parameter(ParameterSetName = 'TableEntitySetNameQuery')]
        [string]
        $Expand,

        [parameter(ParameterSetName = 'TableLogicalNameItemLookup')]
        [parameter(ParameterSetName = 'TableLogicalNameQuery')]
        [parameter(ParameterSetName = 'TableEntitySetNameItemLookup')]
        [parameter(ParameterSetName = 'TableEntitySetNameQuery')]
        [String[]]
        $Select,

        [parameter(ParameterSetName = 'TableLogicalNameQuery')]
        [parameter(ParameterSetName = 'TableEntitySetNameQuery')]
        [ValidateRange(1, 5000)]
        [Int32]
        $Top,

        [parameter(Mandatory, ParameterSetName = 'TableLogicalNameQueryLegacy')]
        [parameter(Mandatory, ParameterSetName = 'TableEntitySetNameQueryLegacy')]
        [String]
        $FilterQuery,

        [parameter(ParameterSetName = 'TableLogicalNameQueryLegacy')]
        [parameter(ParameterSetName = 'TableEntitySetNameQueryLegacy')]
        [parameter(ParameterSetName = 'TableLogicalNameItemLookupLegacy')]
        [parameter(ParameterSetName = 'TableEntitySetNameItemLookupLegacy')]
        [string]
        $ExpandQuery,

        [parameter(ParameterSetName = 'TableLogicalNameQueryLegacy')]
        [parameter(ParameterSetName = 'TableEntitySetNameQueryLegacy')]
        [parameter(ParameterSetName = 'TableLogicalNameItemLookupLegacy')]
        [parameter(ParameterSetName = 'TableEntitySetNameItemLookupLegacy')]
        [String[]]
        $SelectFields

    )

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }

    if (($PSCmdlet.ParameterSetName).StartsWith('TableLogicalName')) {
        try {
            $EntitySet = (Invoke-PSDVWebRequest -WebUri "EntityDefinitions(LogicalName='$Table')" -Select 'EntitySetName').EntitySetName
        }
        catch {
            throw "Cannot find table $Table in Dataverse Environment. $($_.InvocationInfo.MyCommand.Name),  $($_.InvocationInfo.InvocationName) , $($_ | Out-String)"
        }
    }


    if (($PSCmdlet.ParameterSetName).Contains(('Legacy'))) {
        Write-Warning "The ParameterSet $($PSCmdlet.ParameterSetName) is deprecated and will be removed in future releases. Please use -Select, -Filter and -Expand parameters instead of -SelectFields, -FilterQuery and -ExpandQuery"

        if ($PSBoundParameters.ContainsKey('SelectFields')) {
            $Select = $SelectFields
        }

        if ($PSBoundParameters.ContainsKey('FilterQuery')) {
            $Filter = $FilterQuery
        }

        if ($PSBoundParameters.ContainsKey('ExpandQuery')) {
            $Expand = $ExpandQuery
        }

    }


    $requestHeaders = @{'Prefer' = 'odata.include-annotations="*"' }

    if ($Select.Length -gt 0) {
        $selectQuery = '$select=' + ($Select -join ',')
    }

    #build the dv web query
    $dvRequestUri = [System.UriBuilder]::new($Global:DATAVERSEORGURL + "api/data/v9.2/$EntitySet")

    if ($PSBoundParameters.ContainsKey('ItemID')) {
        $dvRequestUri.Path += "($ItemID)"
    }

    if ($selectQuery.Length -gt 0) {
        $dvRequestUri.Query = $selectQuery
    }

    if ($Filter.Length -gt 0){
        if ($dvRequestUri.Query.Length -gt 0) {
            $dvRequestUri.Query += "&`$filter=$Filter"
        }
        else {
            $dvRequestUri.Query = "`$filter=$Filter"
        }
    }

    if ($Expand.Length -gt 0) {
        if ($dvRequestUri.Query.Length -gt 0) {
            $dvRequestUri.Query += "&`$expand=$Expand"
        }
        else {
            $dvRequestUri.Query = "`$expand=$Expand"
        }
    }

    if ($PSBoundParameters.ContainsKey('Top')) {
        if ($dvRequestUri.Query.Length -gt 0) {
            $dvRequestUri.Query += "&`$top=$Top"
        }
        else {
            $dvRequestUri.Query = "`$top=$Top"
        }
    }

    return (Invoke-PSDVWebRequest -WebUri  $($dvRequestUri.Uri.AbsoluteUri) -Headers $requestHeaders)
}

