function Connect-PSDVOrg {
    <#
    .SYNOPSIS
    Establishes a connection to a Microsoft Dataverse organization.

    .DESCRIPTION
    Connect-PSDVOrg creates an authenticated connection to a Microsoft Dataverse environment using various authentication methods.
    It supports service principal authentication with client secrets, managed identity authentication, and interactive login.
    Upon successful connection, it retrieves and stores an access token for subsequent Dataverse API calls.

    .PARAMETER ClientID
    The Application (client) ID of the Azure AD application registration used for service principal authentication.

    .PARAMETER ClientSecret
    The client secret (secure string) for the Azure AD application used for service principal authentication.

    .PARAMETER ManagedIdentityID
    The object ID of the managed identity to use for authentication in Azure environments (user-assigned managed identity).

    .PARAMETER UseSystemManagedIdentity
    When specified, uses the system-assigned managed identity for authentication. No additional identity configuration is required.

    .PARAMETER AzureTenantId
    The Azure Active Directory tenant ID where the Dataverse environment is located.

    .PARAMETER SubscriptionId
    The Azure subscription ID containing the Dataverse environment (required for interactive login).

    .PARAMETER DataverseOrgURL
    The URL of the Dataverse organization (e.g., https://orgname.crm.dynamics.com/).

    .PARAMETER Environment
    The Azure cloud environment. Valid values are AzureCloud, AzureChinaCloud, AzureUSGovernment, or AzureGermanCloud.

    .EXAMPLE
    Connect-PSDVOrg -AzureTenantId "12345678-1234-1234-1234-123456789012" -SubscriptionId "87654321-4321-4321-4321-210987654321" -DataverseOrgURL "https://contoso.crm.dynamics.com/" -Environment "AzureCloud"

    Connects to Dataverse using interactive authentication.

    .EXAMPLE
    $secret = ConvertTo-SecureString "MyClientSecret" -AsPlainText -Force
    Connect-PSDVOrg -ClientID "12345678-1234-1234-1234-123456789012" -ClientSecret $secret -AzureTenantId "87654321-4321-4321-4321-210987654321" -DataverseOrgURL "https://contoso.crm.dynamics.com/" -Environment "AzureCloud"

    Connects to Dataverse using service principal authentication.

    .EXAMPLE
    Connect-PSDVOrg -ManagedIdentityID "12345678-1234-1234-1234-123456789012" -DataverseOrgURL "https://contoso.crm.dynamics.com/" -Environment "AzureCloud"

    Connects to Dataverse using user-assigned managed identity authentication.

    .EXAMPLE
    Connect-PSDVOrg -UseSystemManagedIdentity -DataverseOrgURL "https://contoso.crm.dynamics.com/"

    Connects to Dataverse using system-assigned managed identity authentication.
    #>

    [CmdletBinding(DefaultParameterSetName = 'InteractiveLogin')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'ClientSecret')]
        [String]
        $ClientID,

        [Parameter(Mandatory, ParameterSetName = 'ClientSecret')]
        [SecureString]
        $ClientSecret,

        [Parameter(Mandatory, ParameterSetName = 'ManagedIdentity')]
        [String]
        $ManagedIdentityID,

        [Parameter(Mandatory, ParameterSetName = 'SystemManagedIdentity')]
        [Switch]
        $UseSystemManagedIdentity,

        [Parameter(Mandatory, ParameterSetName = 'ClientSecret')]
        [Parameter(Mandatory, ParameterSetName = 'InteractiveLogin')]
        [String]
        $AzureTenantId,

        [Parameter(Mandatory, ParameterSetName = 'InteractiveLogin')]
        [String]
        $SubscriptionId,

        [Parameter(Mandatory)]
        [String]
        $DataverseOrgURL,

        [Parameter(Mandatory, ParameterSetName = 'InteractiveLogin')]
        [ValidateSet('AzureCloud', 'AzureChinaCloud', 'AzureUSGovernment', 'AzureGermanCloud')]
        [String]
        $Environment
    )

    $ConnectAzAccountParams = @{}
    

    switch ($PSCmdlet.ParameterSetName) {
        'ClientSecret' {
            $clientCredential = [System.Management.Automation.PSCredential]::new($ClientID, $ClientSecret)
            $ConnectAzAccountParams.Add('Credential', $clientCredential)
            $ConnectAzAccountParams.Add('TenantID', $AzureTenantId)
            $ConnectAzAccountParams.Add('ServicePrincipal', $true)
        }

        'ManagedIdentity' {
            $ConnectAzAccountParams.Add('Identity', $true)
            $ConnectAzAccountParams.Add('AccountID', $ManagedIdentityID)
        }

        'SystemManagedIdentity' {
            $ConnectAzAccountParams.Add('Identity', $true)
        }

        'InteractiveLogin' {
            $ConnectAzAccountParams.Add('Environment', $Environment)
            $ConnectAzAccountParams.Add('Tenant', $AzureTenantId)
            $ConnectAzAccountParams.Add('Subscription', $SubscriptionId)
        }
    }

    #Ensure DataverseOrgURL has a trailing slash
    if (-not $DataverseOrgURL.EndsWith('/')) {
        $DataverseOrgURL = $DataverseOrgURL + '/'
    }
    
    try {
        Write-Verbose "Connecting to Azure Tenant $AzureTenantId"
        Connect-AzAccount @ConnectAzAccountParams
    }
    catch {
        throw "Error executing $($_.InvocationInfo.MyCommand.Name), $($_.ToString())"
    }

    try {
        Write-Verbose "Getting Dataverse Access Token for $DataverseOrgUrl"
        $Global:DATAVERSEACCESSTOKEN = Get-AzAccessToken -ResourceUrl $DataverseOrgURL -AsSecureString
        $Global:DATAVERSEORGURL = $DataverseOrgURL
    }
    catch {
        throw "Error executing $($_.InvocationInfo.MyCommand.Name), $($_.ToString())"
    }

}


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
            $Global:DATAVERSEACCESSTOKEN = Get-AzAccessToken -ResourceUrl $Global:DATAVERSEORGURL -AsSecureString
        }
    }
}

function Invoke-PSDVWebRequest {
    <#
    .SYNOPSIS
    Executes authenticated web requests to the Dataverse Web API.

    .DESCRIPTION
    Invoke-PSDVWebRequest is the core function for making authenticated HTTP requests to the Microsoft Dataverse Web API.
    It handles OAuth authentication, URL construction, query parameter formatting, and automatic pagination.
    The function supports all HTTP methods (GET, POST, PATCH, DELETE, PUT) and automatically follows OData nextLink
    properties to retrieve complete result sets for large datasets.

    .PARAMETER WebUri
    The Web API endpoint URI. Can be a full URL, relative path with 'api/data/v9.2/', or just the resource name.

    .PARAMETER Method
    The HTTP method to use. Valid values are Get, Post, Patch, Delete, or Put. Default is Get.

    .PARAMETER Select
    OData $select parameter to specify which fields to return.

    .PARAMETER Filter
    OData $filter parameter to specify query conditions.

    .PARAMETER Expand
    OData $expand parameter to include related records.

    .PARAMETER Body
    Hashtable containing the request body data for POST/PATCH operations.

    .PARAMETER Headers
    Additional HTTP headers to include in the request.

    .PARAMETER ReturnRawResponse
    Returns the raw web response object instead of parsing the JSON content.

    .EXAMPLE
    Invoke-PSDVWebRequest -WebUri "accounts" -Select "name,accountnumber"

    Retrieves all accounts with only name and account number fields.

    .EXAMPLE
    Invoke-PSDVWebRequest -WebUri "contacts" -Filter "firstname eq 'John'" -Expand "parentcustomerid_account"

    Retrieves contacts named John and expands the parent account information.

    .EXAMPLE
    $data = @{ name = "New Account"; accountnumber = "ACC001" }
    Invoke-PSDVWebRequest -WebUri "accounts" -Method Post -Body $data

    Creates a new account record.
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [String]
        $WebUri,

        [parameter()]
        [ValidateSet('Get', 'Post', 'Patch', 'Delete', 'Put')]
        [string]
        $Method = 'Get',

        [parameter()]
        [string]
        $Select,

        [parameter()]
        [string]
        $Filter,

        [parameter()]
        [string]
        $Expand,

        [parameter()]
        [hashtable]
        $Body,

        [parameter()]
        [hashtable]
        $Headers,

        [parameter()]
        [switch]
        $ReturnRawResponse = $false
    )

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }

    Update-PSDVAccessToken

    # Remove leading slash if present
    if ($WebUri.StartsWith('/')) {
        $WebUri = $WebUri.Substring(1)
    }

    if ($WebUri.StartsWith(($Global:DATAVERSEORGURL))) {
        $dvRequestUri = $WebUri
    }
    elseif ( $WebUri.Contains('api/data/v9.2/') ) {
        $dvRequestUri = $Global:DATAVERSEORGURL + $WebUri
    }
    else {
        $dvRequestUri = $Global:DATAVERSEORGURL + 'api/data/v9.2/' + $WebUri
    }
    $dvRequestUri = [System.UriBuilder]$dvRequestUri

    # Append query parameters if provided
    $queryParams = @{}
    if ($Select) { $queryParams['$select'] = $Select }
    if ($Filter) { $queryParams['$filter'] = $Filter }
    if ($Expand) { $queryParams['$expand'] = $Expand }

    if ($queryParams.Count -gt 0) {
        $existingQuery = $dvRequestUri.Query
        if ($existingQuery.StartsWith('?')) {
            $existingQuery = $existingQuery.Substring(1)
        }
        $newQuery = ($queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join '&'
        if ($existingQuery) {
            $dvRequestUri.Query = "$existingQuery&$newQuery"
        }
        else {
            $dvRequestUri.Query = $newQuery
        }
    }

    if ($Body) {
        if ($Method -eq 'Get') {
            $Method = 'Post'
        }

        $bodyContent = $Body | ConvertTo-Json
        $httpHeaders = @{
            'Content-Type' = 'application/json'
            'Accept'       = 'application/json'
        }
    }
    else {
        $bodyContent = $null
        $httpHeaders = @{}
    }

    if ($PSBoundParameters.ContainsKey('Headers')) {
        foreach ($key in $Headers.Keys) {
            $httpHeaders[$key] = $Headers[$key]
        }
    }

    try {
        Write-Verbose "Executing Web API: $($dvRequestUri.Uri.AbsoluteUri)"
        $webResponse = Invoke-WebRequest -Authentication OAuth -Token $Global:DATAVERSEACCESSTOKEN.Token -Method $method -Uri $dvRequestUri.Uri.AbsoluteUri -Body $bodyContent -Headers $httpHeaders
    }
    catch {
        if ($_.ErrorDetails) {
            try {
                $errorContent = (ConvertFrom-Json $_.ErrorDetails.ToString()).error
            }
            catch {
                $errorContent = $_.ErrorDetails.ToString()
            }
        }
        else {
            $errorContent = $_.ToString()
        }
        throw "Error executing web query: $($_.Exception.Message), $errorContent"
    }

    if ($ReturnRawResponse) {
        return $webResponse
    }
    else {
        $jsonResponse = $webResponse.Content | ConvertFrom-Json
        $allResults = @()

        # Handle paging by following @odata.nextLink
        do {
           if ($jsonResponse.value.count -gt 0) {
                $allResults += $jsonResponse.value
            }
            elseif ($jsonResponse.PSObject.Properties.Name -contains 'Value' -and $jsonResponse.value.count -eq 0) {
                # empty collection, no results
                return $null
            }
            else {
                #single item
                return $jsonResponse
            }

            # Check if there's a next page
            if ($jsonResponse.'@odata.nextLink') {
                try {
                    Write-Verbose "Following pagination link: $($jsonResponse.'@odata.nextLink')"
                    $webResponse = Invoke-WebRequest -Authentication OAuth -Token $Global:DATAVERSEACCESSTOKEN.Token -Method Get -Uri $jsonResponse.'@odata.nextLink' -Headers $httpHeaders
                    $jsonResponse = $webResponse.Content | ConvertFrom-Json
                }
                catch {
                    Write-Warning "Error retrieving next page: $($_.Exception.Message)"
                    break
                }
            }
            else {
                $jsonResponse = $null
            }
        } while ($jsonResponse)

        return $allResults
    }
}

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
        throw "Error getting Dataverse Entity Definitions: $($_.InvocationInfo.MyCommand.Name), $($_.ToString())"
    }


    foreach ($t in $webResponse) {
        [PSCustomObject]@{
            LogicalName = $t.LogicalName
            DisplayName   = $t.DisplayName.LocalizedLabels[0].Label
            EntitySetName = $t.EntitySetName
        }
    }
}


function Get-PSDVTableDetail {
    <#
    .SYNOPSIS
    Retrieves detailed metadata for a specific Dataverse table.

    .DESCRIPTION
    Get-PSDVTableDetails fetches comprehensive metadata for a specified Dataverse table, including
    the table definition and all field/column information. It returns a detailed object containing
    table properties and a Fields collection with information about each attribute in the table.
    This function provides schema information useful for understanding table structure.

    .PARAMETER Table
    The logical name of the Dataverse table to retrieve details for.

    .EXAMPLE
    Get-PSDVTableDetails -Table "account"

    Returns detailed metadata for the Account table including all field definitions.

    .EXAMPLE
    $tableInfo = Get-PSDVTableDetails -Table "contact"
    $tableInfo.Fields.Keys

    Gets table details and lists all available field names.
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [String]
        $Table
    )

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }


    #Get table details
    try {
        $webResponse = Invoke-PSDVWebRequest  -Method Get -WebUri ($Global:DATAVERSEORGURL + "api/data/v9.2/EntityDefinitions(LogicalName='$Table')")
    }
    catch {
        throw "Error getting table details: $($_.InvocationInfo.MyCommand.Name), $($_.ToString())"
    }

    $tableDetails = $webResponse

    #get fields / column details
    try {
        $webResponse = Invoke-PSDVWebRequest  -Method Get -WebUri ($Global:DATAVERSEORGURL + "api/data/v9.2/EntityDefinitions(LogicalName='$Table')/Attributes")
    }
    catch {
        throw "Error getting attribute details: $($_.InvocationInfo.MyCommand.Name), $($_.ToString())"
    }

    $columnDetails = $webResponse
    $columnDetailsProperties = @{}

    foreach ($column in $columnDetails) {
        $columnDetailsProperties.Add($column.LogicalName, $column)
    }

    # Create a hashtable with all properties including Fields
    $allProperties = @{ Fields = $columnDetailsProperties }

    # Add all original properties from tableDetails
    foreach ($property in $tableDetails.PSObject.Properties) {
        $allProperties[$property.Name] = $property.Value
    }

    # Create new PSCustomObject with all properties
    $tableDetailsWithFields = [PSCustomObject]$allProperties

    return $tableDetailsWithFields
}

function Get-PSDVTableColumn {
    <#
    .SYNOPSIS
    Retrieves column metadata for a specific Dataverse table.

    .DESCRIPTION
    Get-PSDVTableColumn returns detailed information about columns (attributes) in a specified Dataverse table.
    For each column, it provides metadata including logical name, display name, data type, validation rules,
    maximum length, precision, and relationship targets. This function is useful for understanding the
    structure and constraints of table fields before performing data operations. Optionally, you can specify
    specific column names to retrieve only those columns' metadata.

    .PARAMETER Table
    The logical name of the Dataverse table to retrieve column information for.

    .PARAMETER ColumnName
    Optional array of column logical names to retrieve. If not specified, all columns are returned.

    .EXAMPLE
    Get-PSDVTableColumn -Table "account"

    Returns detailed column information for all columns in the Account table.

    .EXAMPLE
    Get-PSDVTableColumn -Table "account" -ColumnName @("name", "telephone1", "websiteurl")

    Returns detailed column information for only the specified columns in the Account table.

    .EXAMPLE
    Get-PSDVTableColumn -Table "contact" | Where-Object { $_.RequiredLevel -eq "ApplicationRequired" }

    Returns only the required columns for the Contact table.

    .EXAMPLE
    Get-PSDVTableColumn -Table "account" -ColumnName @("accountid", "name") | Format-Table LogicalName, DisplayName, AttributeType

    Displays a formatted table of key column properties for specific columns.
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory)]
        [String]
        $Table,

        [parameter()]
        [String[]]
        $ColumnName
    )

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }

    # Build the base URI for the attributes endpoint
    $baseUri = $Global:DATAVERSEORGURL + "api/data/v9.2/EntityDefinitions(LogicalName='$Table')/Attributes"
    
    # If specific column names are provided, build a filter expression
    if ($ColumnName -and $ColumnName.Count -gt 0) {
        $filterConditions = @()
        foreach ($column in $ColumnName) {
            $filterConditions += "LogicalName eq '$column'"
        }
        $filterExpression = $filterConditions -join ' or '
        $webResponse = Invoke-PSDVWebRequest -Method Get -WebUri $baseUri -Filter $filterExpression
    }
    else {
        $webResponse = Invoke-PSDVWebRequest -Method Get -WebUri $baseUri
    }

    foreach ($tableColumn in $webResponse) {
        [PSCustomObject]@{
            LogicalName = $tableColumn.LogicalName
            DisplayName = $tableColumn.DisplayName.LocalizedLabels[0].Label
            AttributeType = $tableColumn.AttributeType
            IsValidForCreate = $tableColumn.IsValidForCreate
            IsValidForUpdate = $tableColumn.IsValidForUpdate
            IsValidForRead = $tableColumn.IsValidForRead
            RequiredLevel = $tableColumn.RequiredLevel.Value
            MaxLength = $tableColumn.MaxLength
            Precision = $tableColumn.Precision
            Targets = $tableColumn.Targets -join ', '
        }
    }
}

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
            throw "Cannot find table $Table in Dataverse Environment. $($_.InvocationInfo.MyCommand.Name),  $($_.InvocationInfo.InvocationName) , $($_.ToString())"
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

    return (Invoke-PSDVWebRequest -WebUri  $($dvRequestUri.Uri.AbsoluteUri) -Headers $requestHeaders)
}


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



function Get-PSDVTableItemChangeHistory {
    <#
    .SYNOPSIS
    Retrieves detailed change history for a specific Dataverse record.

    .DESCRIPTION
    Get-PSDVTableItemChangeHistory uses the RetrieveRecordChangeHistory API to fetch comprehensive
    change details for a specific record. Unlike audit history, this function provides detailed
    information about what specific field values were changed, including before and after values.
    This function requires auditing to be enabled and provides more granular change tracking.

    .PARAMETER Table
    The logical name of the Dataverse table containing the record.

    .PARAMETER EntitySet
    The entity set name of the Dataverse table (alternative to Table parameter).

    .PARAMETER ItemID
    The unique identifier (GUID) of the record to retrieve change history for.

    .EXAMPLE
    Get-PSDVTableItemChangeHistory -Table "account" -ItemID "12345678-1234-1234-1234-123456789012"

    Retrieves detailed change history for a specific account record.

    .EXAMPLE
    Get-PSDVTableItemChangeHistory -EntitySet "contacts" -ItemID "87654321-4321-4321-4321-210987654321"

    Retrieves change history using entity set name instead of logical name.
    #>

    [CmdletBinding()]
    param(
        [parameter(Mandatory, ParameterSetName = 'TableLogicalName')]
        [String]
        $Table,

        [parameter(Mandatory, ParameterSetName = 'TableEntitySetName')]
        [string]
        $EntitySet,

        [parameter(Mandatory)]
        [String]
        $ItemID
    )

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }

    if (($PSCmdlet.ParameterSetName).StartsWith('TableLogicalName')) {
        try {
            $EntitySet = (Invoke-PSDVWebRequest -WebUri "EntityDefinitions(LogicalName='$Table')" -Select 'EntitySetName').EntitySetName
        }
        catch {
            throw "Cannot find table $Table in Dataverse Environment. $($_.InvocationInfo.MyCommand.Name),  $($_.InvocationInfo.InvocationName) , $($_.ToString())"
        }
    }


    $requestHeaders = @{'Prefer' = 'odata.include-annotations="*"' }

    $dvRequestUri = $Global:DATAVERSEORGURL + "api/data/v9.2/RetrieveRecordChangeHistory(Target=@target)?@target={'@odata.id':'$EntitySet($ItemID)'}"

    $webResponse = Invoke-PSDVWebRequest -WebUri  $dvRequestUri -Headers $requestHeaders -Method 'Get'

    if ($webResponse.AuditDetailCollection.count -gt 0) {
        return $webResponse.AuditDetailCollection
    }
    else {
        return $webResponse
    }
}


function New-PSDVTableItem {
    <#
    .SYNOPSIS
    Creates a new record in a Dataverse table.

    .DESCRIPTION
    New-PSDVTableItem creates a new record in the specified Dataverse table using the provided data.
    It supports automatic field validation to ensure all provided fields exist in the target table.
    The function can optionally parse lookup relationships and convert them to the proper OData format.
    When ReturnItem is specified, it returns the created record with all server-generated values.

    .PARAMETER Table
    The logical name of the Dataverse table to create the record in.

    .PARAMETER EntitySet
    The entity set name of the Dataverse table (alternative to Table parameter).

    .PARAMETER ItemData
    Hashtable containing the field names and values for the new record.

    .PARAMETER ParseItemData
    When specified, automatically parses lookup field values and converts them to OData format.

    .PARAMETER ReturnItem
    When specified, returns the created record with server-generated values like ID and timestamps.

    .EXAMPLE
    $data = @{
        name = "Contoso Corporation"
        accountnumber = "ACC001"
        telephone1 = "555-123-4567"
    }
    New-PSDVTableItem -Table "account" -ItemData $data

    Creates a new account record with the specified data.

    .EXAMPLE
    $contactData = @{
        firstname = "John"
        lastname = "Doe"
        emailaddress1 = "john.doe@contoso.com"
        parentcustomerid = "12345678-1234-1234-1234-123456789012"
    }
    New-PSDVTableItem -Table "contact" -ItemData $contactData -ParseItemData -ReturnItem

    Creates a new contact with a lookup relationship, parses the lookup, and returns the created record.
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

    #lookup table relationships require setting the Microsoft.Dynamics.CRM.associatednavigationproperty odata.bind = /entitysetname(item ID)
    # ex, "cr33a_MACOM@odata.bind" = "/cr33a_macoms(b7322079-55d2-ee11-9078-000d3a33b5cf)"

    if (($PSCmdlet.ParameterSetName).StartsWith('TableLogicalName')) {
        try {
            $EntitySet = (Invoke-PSDVWebRequest -WebUri "EntityDefinitions(LogicalName='$Table')" -Select 'EntitySetName').EntitySetName
        }
        catch {
            throw "Cannot find table $Table in Dataverse Environment. $($_.InvocationInfo.MyCommand.Name),  $($_.InvocationInfo.InvocationName) , $($_.ToString())"
        }
    }


    $requestHeaders = @{
        'Prefer'       = 'odata.include-annotations="*"'
    }

    if ($ReturnItem.IsPresent) {
        $requestHeaders['Prefer'] = 'odata.include-annotations="*",return=representation'
    }

    #verify fields in ItemData are valid for the table
    if ($PSCmdlet.ParameterSetName.StartsWith('TableEntitySetName'))
    {
        $Table = (Invoke-PSDVWebRequest -WebUri "EntityDefinitions?`$filter=EntitySetName eq '$EntitySet'&`$select=LogicalName").LogicalName
    }
    $tableColumns = Invoke-PSDVWebRequest -WebUri "EntityDefinitions(LogicalName='$Table')/Attributes"
    $attributeDetails = @{}
    $invalidAttributes = @()

    foreach ($attribute in $ItemData.GetEnumerator().name ) {
        if (! $tableColumns.LogicalName -contains $attribute) {
            $invalidAttributes += $attribute
        }else {
            $attributeDetails.Add($attribute, ($tableColumns | Where-Object { $_.LogicalName -eq $attribute } | Select-Object -Property AttributeType,SchemaName,Targets))
        }
    }
    if ($invalidAttributes.Count -gt 0) {
        throw "Invalid attributes not present in $Table : $($invalidAttributes -join ', ')"
    }
    


    if ($ParseItemData.IsPresent) {
        $ParsedItemData = @{}

        foreach ($attribute in $attributeDetails.GetEnumerator().name ) {
           if ($attributeDetails[$attribute].AttributeType -eq 'Lookup') {
                $navProperty = $attributeDetails[$attribute].SchemaName
                $targetTable = $attributeDetails[$attribute].Targets[0]
                $targetTableSet = (Invoke-PSDVWebRequest -WebUri "EntityDefinitions(LogicalName='$targetTable')" -Select 'EntitySetName').EntitySetName
                $targetItemID = $ItemData[$attribute]
                $ParsedItemData.Add("$navProperty@odata.bind", "/$targetTableSet($targetItemID)")
            }
            else {
                $ParsedItemData.Add($attribute, $ItemData[$attribute])
            }
        }

        $ItemData2Process = $ParsedItemData
    }
    else {
        $ItemData2Process = $ItemData
    }


    $dvRequestUri = $Global:DATAVERSEORGURL + "api/data/v9.2/$EntitySet"

    if ($PSCmdlet.ShouldProcess($EntitySet, "Create new item")) {
        return (Invoke-PSDVWebRequest -WebUri  $dvRequestUri -Headers $requestHeaders -Body $ItemData2Process)
    }

}


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

        [parameter()]
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

    #lookup table relationships require setting the Microsoft.Dynamics.CRM.associatednavigationproperty odata.bind = /entitysetname(item ID)
    # ex, "cr33a_MACOM@odata.bind" = "/cr33a_macoms(b7322079-55d2-ee11-9078-000d3a33b5cf)"

    if (($PSCmdlet.ParameterSetName).StartsWith('TableLogicalName')) {
        try {
            $EntitySet = (Invoke-PSDVWebRequest -WebUri "EntityDefinitions(LogicalName='$Table')" -Select 'EntitySetName').EntitySetName
        }
        catch {
            throw "Cannot find table $Table in Dataverse Environment. $($_.InvocationInfo.MyCommand.Name),  $($_.InvocationInfo.InvocationName) , $($_.ToString())"
        }
    }


    $requestHeaders = @{
        'Prefer'       = 'odata.include-annotations="*"'
    }

    if ($ReturnItem.IsPresent) {
        $requestHeaders['Prefer'] = 'odata.include-annotations="*",return=representation'
    }

    #verify fields in ItemData are valid for the table
    if ($PSCmdlet.ParameterSetName.StartsWith('TableEntitySetName'))
    {
        $Table = (Invoke-PSDVWebRequest -WebUri "EntityDefinitions?`$filter=EntitySetName eq '$EntitySet'&`$select=LogicalName").LogicalName
    }
    $tableColumns = Invoke-PSDVWebRequest -WebUri "EntityDefinitions(LogicalName='$Table')/Attributes"
    $attributeDetails = @{}
    $invalidAttributes = @()

    foreach ($attribute in $ItemData.GetEnumerator().name ) {
        if (! $tableColumns.LogicalName -contains $attribute) {
            $invalidAttributes += $attribute
        }else {
        $attributeDetails.Add($attribute, ($tableColumns | Where-Object { $_.LogicalName -eq $attribute } | Select-Object -Property AttributeType,SchemaName,Targets))
    }
    }
    if ($invalidAttributes.Count -gt 0) {
        throw "Invalid attributes not present in $Table : $($invalidAttributes -join ', ')"
    }
    


    if ($ParseItemData.IsPresent) {
        $ParsedItemData = @{}

        foreach ($attribute in $attributeDetails.GetEnumerator().name ) {
           if ($attributeDetails[$attribute].AttributeType -eq 'Lookup') {
                $navProperty = $attributeDetails[$attribute].SchemaName
                $targetTable = $attributeDetails[$attribute].Targets[0]
                $targetTableSet = (Invoke-PSDVWebRequest -WebUri "EntityDefinitions(LogicalName='$targetTable')" -Select 'EntitySetName').EntitySetName
                $targetItemID = $ItemData[$attribute]
                $ParsedItemData.Add("$navProperty@odata.bind", "/$targetTableSet($targetItemID)")
            }
            else {
                $ParsedItemData.Add($attribute, $ItemData[$attribute])
            }
        }

        $ItemData2Process = $ParsedItemData
    }
    else {
        $ItemData2Process = $ItemData
    }


    $dvRequestUri = $Global:DATAVERSEORGURL + "api/data/v9.2/$EntitySet($ItemID)"

    if ($PSCmdlet.ShouldProcess("$EntitySet($ItemID)", "Update item")) {
        return (Invoke-PSDVWebRequest -WebUri  $dvRequestUri -Headers $requestHeaders -Body $ItemData2Process -Method 'Patch' )
    }

}


function Remove-PSDVTableItem {
    <#
    .SYNOPSIS
    Deletes a record from a Dataverse table.

    .DESCRIPTION
    Remove-PSDVTableItem removes a specific record from the specified Dataverse table using the record's
    unique identifier. The function supports both logical name and entity set name parameter sets for
    table identification. Once deleted, the record cannot be recovered unless it's restored from a backup
    or the Dataverse recycle bin (if available and not expired).

    .PARAMETER Table
    The logical name of the Dataverse table containing the record to delete.

    .PARAMETER EntitySet
    The entity set name of the Dataverse table (alternative to Table parameter).

    .PARAMETER ItemID
    The unique identifier (GUID) of the record to delete.

    .EXAMPLE
    Remove-PSDVTableItem -Table "account" -ItemID "12345678-1234-1234-1234-123456789012"

    Deletes a specific account record by its ID.

    .EXAMPLE
    Remove-PSDVTableItem -EntitySet "contacts" -ItemID "87654321-4321-4321-4321-210987654321"

    Deletes a contact record using entity set name instead of logical name.

    .EXAMPLE
    Get-PSDVTableItem -Table "account" -Filter "name eq 'Test Account'" | ForEach-Object {
        Remove-PSDVTableItem -Table "account" -ItemID $_.accountid
    }

    Finds and deletes all accounts named "Test Account".
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
        [String]
        $ItemID
    )

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }


    if (($PSCmdlet.ParameterSetName).StartsWith('TableLogicalName')) {
        try {
            $EntitySet = (Invoke-PSDVWebRequest -WebUri "EntityDefinitions(LogicalName='$Table')" -Select 'EntitySetName').EntitySetName
        }
        catch {
            throw "Cannot find table $Table in Dataverse Environment. $($_.InvocationInfo.MyCommand.Name),  $($_.InvocationInfo.InvocationName) , $($_.ToString())"
        }
    }


    $requestHeaders = @{'Prefer' = 'odata.include-annotations="*"' }


    #build the dv web query
    $dvRequestUri = $Global:DATAVERSEORGURL + "api/data/v9.2/$EntitySet($ItemID)"

    if ($PSCmdlet.ShouldProcess("$EntitySet($ItemID)", "Delete item")) {
        return (Invoke-PSDVWebRequest -WebUri  $dvRequestUri -Headers $requestHeaders -Method 'Delete' )
    }
}

# Create aliases for backward compatibility
New-Alias -Name Delete-PSDVTableItem -Value Remove-PSDVTableItem -Force


function New-PSDVTableWebHook {
    <#
    .SYNOPSIS
    Creates a new webhook registration for a Dataverse table.

    .DESCRIPTION
    New-PSDVTableWebHook registers a webhook endpoint to be triggered when specified operations occur on a Dataverse table.
    The function creates a service endpoint, retrieves the necessary SDK message and filter IDs, and then creates the 
    webhook step registration. This enables real-time notifications to external systems when data changes occur.

    .PARAMETER Table
    The logical name of the Dataverse table to monitor for webhook triggers.

    .PARAMETER WebHookName
    The display name for the webhook registration.

    .PARAMETER TriggerUri
    The HTTP endpoint URL that will receive webhook notifications when the trigger events occur.

    .PARAMETER Operation
    The SDK message operation to monitor. Valid values are Create, Update, Delete, or Retrieve. Default is Create.

    .PARAMETER AuthSecret
    The optional authentication secret for webhook security. This will be passed in the x-dv-webhook-secret header.

    .PARAMETER Stage
    The execution stage for the webhook. Valid values are PreValidation (10), PreOperation (20), MainOperation (30), or PostOperation (40). Default is PostOperation.

    .PARAMETER Rank
    The execution order rank within the stage. Lower numbers execute first. Default is 1.

    .PARAMETER Mode
    The execution mode. Valid values are Synchronous (0) or Asynchronous (1). Default is Asynchronous.

    .PARAMETER SupportedDeployment
    The deployment scope. Valid values are ServerOnly (0), ClientOnly (1), or Both (2). Default is ServerOnly.

    .PARAMETER FilteringAttributes
    An optional array of column logical names to filter on. When specified, the webhook will only trigger when one or more of these columns are modified. This is only applicable for Update operations. If not specified, the webhook triggers for all column changes.

    .PARAMETER PreImage
    When specified, registers a pre-image on the webhook step. A pre-image captures a snapshot of the entity record's values before the operation is executed. This is useful for comparing old and new values during Update or Delete operations.

    .PARAMETER PreImageAttributes
    An optional array of column logical names to include in the pre-image. When specified, only these columns will be captured in the pre-image snapshot. If not specified, all columns are included. Only used when -PreImage is specified.

    .PARAMETER PostImage
    When specified, registers a post-image on the webhook step. A post-image captures a snapshot of the entity record's values after the operation is executed. This is useful for accessing the final state of the record after Create or Update operations.

    .PARAMETER PostImageAttributes
    An optional array of column logical names to include in the post-image. When specified, only these columns will be captured in the post-image snapshot. If not specified, all columns are included. Only used when -PostImage is specified.

    .EXAMPLE
    New-PSDVTableWebHook -Table "account" -WebHookName "Account Changes Monitor" -TriggerUri "https://myapp.azurewebsites.net/api/DataverseTrigger" -Operation "Create"

    Creates a webhook to monitor account creation events.

    .EXAMPLE
    New-PSDVTableWebHook -Table "spork_sporkuserrequest" -WebHookName "SPORK Users New Record WebHook" -TriggerUri "https://sporkapps.azurewebsites.net/api/DataverseTrigger" -Operation "Create" -AuthSecret "DontTell"

    Creates a webhook with authentication secret for a custom table.

    .EXAMPLE
    New-PSDVTableWebHook -Table "contact" -WebHookName "Contact Update Monitor" -TriggerUri "https://myapp.com/webhook" -Operation "Update" -Stage "PreOperation" -Mode "Synchronous"

    Creates a synchronous webhook that fires before contact updates are processed.

    .EXAMPLE
    New-PSDVTableWebHook -Table "account" -WebHookName "Account Name Monitor" -TriggerUri "https://myapp.com/webhook" -Operation "Update" -FilteringAttributes @("name", "accountcategorycode")

    Creates a webhook that only triggers when the account name or category code fields are updated.

    .EXAMPLE
    New-PSDVTableWebHook -Table "contact" -WebHookName "Contact Update With PreImage" -TriggerUri "https://myapp.com/webhook" -Operation "Update" -PreImage -PreImageAttributes @("firstname", "lastname", "emailaddress1")

    Creates a webhook that captures a pre-image of the firstname, lastname, and emailaddress1 fields before contact updates.

    .EXAMPLE
    New-PSDVTableWebHook -Table "account" -WebHookName "Account Create With PostImage" -TriggerUri "https://myapp.com/webhook" -Operation "Create" -PostImage -PostImageAttributes @("name", "accountnumber")

    Creates a webhook that captures a post-image of the name and accountnumber fields after account creation.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [String]
        $Table,

        [Parameter(Mandatory)]
        [String]
        $WebHookName,

        [Parameter(Mandatory)]
        [String]
        $TriggerUri,

        [Parameter()]
        [ValidateSet('Create', 'Update', 'Delete', 'Retrieve')]
        [String]
        $Operation = 'Create',

        [Parameter()]
        [String]
        $AuthSecret,

        [Parameter()]
        [ValidateSet('PreValidation', 'PreOperation', 'MainOperation', 'PostOperation')]
        [String]
        $Stage = 'PostOperation',

        [Parameter()]
        [ValidateRange(1, 2147483647)]
        [Int32]
        $Rank = 1,

        [Parameter()]
        [ValidateSet('Synchronous', 'Asynchronous')]
        [String]
        $Mode = 'Asynchronous',

        [Parameter()]
        [ValidateSet('ServerOnly', 'ClientOnly', 'Both')]
        [String]
        $SupportedDeployment = 'ServerOnly',

        [Parameter()]
        [String[]]
        $FilteringAttributes,

        [Parameter()]
        [Switch]
        $PreImage,

        [Parameter()]
        [String[]]
        $PreImageAttributes,

        [Parameter()]
        [Switch]
        $PostImage,

        [Parameter()]
        [String[]]
        $PostImageAttributes
    )

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }

    # Validate filtering attributes are only used with Update operations
    if ($FilteringAttributes -and $Operation -ne 'Update') {
        throw "FilteringAttributes parameter can only be used with Update operations. Current operation: $Operation"
    }

    # Validate PreImageAttributes are only used with PreImage
    if ($PreImageAttributes -and -not $PreImage) {
        throw "PreImageAttributes parameter can only be used when -PreImage is specified"
    }

    # Validate PreImage is only used with Update or Delete operations
    if ($PreImage -and $Operation -notin @('Update', 'Delete')) {
        throw "PreImage parameter can only be used with Update or Delete operations. Current operation: $Operation"
    }

    # Validate PostImageAttributes are only used with PostImage
    if ($PostImageAttributes -and -not $PostImage) {
        throw "PostImageAttributes parameter can only be used when -PostImage is specified"
    }

    # Validate PostImage is only used with Create or Update operations
    if ($PostImage -and $Operation -notin @('Create', 'Update')) {
        throw "PostImage parameter can only be used with Create or Update operations. Current operation: $Operation"
    }

    # Convert stage names to numeric values
    $stageMap = @{
        'PreValidation' = 10
        'PreOperation' = 20
        'MainOperation' = 30
        'PostOperation' = 40
    }

    # Convert mode names to numeric values  
    $modeMap = @{
        'Synchronous' = 0
        'Asynchronous' = 1
    }

    # Convert deployment names to numeric values
    $deploymentMap = @{
        'ServerOnly' = 0
        'ClientOnly' = 1
        'Both' = 2
    }

    # Check for existing webhook with same table, operation, and URL
    Write-Verbose "Checking for existing webhook with same table ($Table), operation ($Operation), and URL ($TriggerUri)"
    try {
        $existingWebhookQuery = "eventhandler_serviceendpoint ne null and eventhandler_serviceendpoint/serviceendpointid ne null and sdkmessagefilterid/primaryobjecttypecode eq '$Table' and sdkmessageid/name eq '$Operation' and eventhandler_serviceendpoint/url eq '$TriggerUri'"
        $existingWebhook = Invoke-PSDVWebRequest -WebUri "api/data/v9.2/sdkmessageprocessingsteps" -Select "sdkmessageprocessingstepid,name" -Expand "eventhandler_serviceendpoint(`$select=serviceendpointid,name,url)" -Filter $existingWebhookQuery
        
        if ($existingWebhook -and $existingWebhook.Count -gt 0) {
            $existingWebhookName = if ($existingWebhook[0].eventhandler_serviceendpoint.name) { $existingWebhook[0].eventhandler_serviceendpoint.name } else { "Unknown" }
            throw "A webhook already exists for table '$Table', operation '$Operation', and URL '$TriggerUri'. Existing webhook: $existingWebhookName"
        }
        
        Write-Verbose "No duplicate webhook found. Proceeding with webhook creation."
    }
    catch {
        if ($_.Exception.Message -like "*webhook already exists*") {
            throw
        }
        Write-Verbose "Error checking for duplicates (proceeding anyway): $($_.Exception.Message)"
    }

    try {
        # Step 1: Create service endpoint
        Write-Verbose "Creating service endpoint for webhook: $WebHookName"
        
        $serviceEndPointSetup = @{
            "name" = $WebHookName
            "url" = $TriggerUri
            "contract" = 8  # WebHook contract type
            "authtype" = 5  # HttpHeader authentication
        }

        if ($PSBoundParameters.ContainsKey('AuthSecret')) {
            $serviceEndPointSetup["authvalue"] = "<settings><setting name=""x-dv-webhook-secret"" value=""$AuthSecret""/></settings>"
        } else {
            $serviceEndPointSetup["authvalue"] = "<settings></settings>"
        }

        if ($PSCmdlet.ShouldProcess($WebHookName, "Create service endpoint")) {
            $serviceEndpointHeaders = @{
                'Prefer' = 'odata.include-annotations="*",return=representation'
            }
            $serviceEndpoint = Invoke-PSDVWebRequest -WebUri "api/data/v9.2/serviceendpoints" -Method Post -Body $serviceEndPointSetup -Headers $serviceEndpointHeaders
            Write-Verbose "Service endpoint created with ID: $($serviceEndpoint.serviceendpointid)"
        } else {
            Write-Verbose "Would create service endpoint for: $WebHookName"
            return
        }

        # Step 2: Get SDK message ID
        Write-Verbose "Retrieving SDK message ID for operation: $Operation"
        $sdkMessage = Invoke-PSDVWebRequest -WebUri "api/data/v9.2/sdkmessages" -Select "sdkmessageid,name" -Filter "name eq '$Operation'"
        
        if (-not $sdkMessage -or $sdkMessage.Count -eq 0) {
            throw "SDK message '$Operation' not found"
        }
        
        $sdkMessageId = $sdkMessage.sdkmessageid
        Write-Verbose "SDK message ID: $sdkMessageId"

        # Step 3: Get SDK message filter ID
        Write-Verbose "Retrieving SDK message filter for table '$Table' and operation '$Operation'"
        $sdkMessageFilter = Invoke-PSDVWebRequest -WebUri "api/data/v9.2/sdkmessagefilters" -Select "sdkmessagefilterid,primaryobjecttypecode" -Filter "primaryobjecttypecode eq '$Table' and sdkmessageid/name eq '$Operation'"
        
        if (-not $sdkMessageFilter -or $sdkMessageFilter.Count -eq 0) {
            throw "SDK message filter for table '$Table' and operation '$Operation' not found"
        }
        
        $sdkMessageFilterId = $sdkMessageFilter.sdkmessagefilterid
        Write-Verbose "SDK message filter ID: $sdkMessageFilterId"

        # Step 4: Create webhook step
        Write-Verbose "Creating webhook step registration"
        $webhookStepName = "$($WebHookName.ToLower().Replace(' ', '.')).$Table.$($Operation.ToLower())"
        
        $webhookStep = @{
            "name" = $webhookStepName
            "description" = "$WebHookName - $Table - $Operation"
            "stage" = $stageMap[$Stage]
            "rank" = $Rank
            "mode" = $modeMap[$Mode]
            "supporteddeployment" = $deploymentMap[$SupportedDeployment]
            "eventhandler_serviceendpoint@odata.bind" = "/serviceendpoints($($serviceEndpoint.serviceendpointid))"
            "sdkmessageid@odata.bind" = "/sdkmessages($sdkMessageId)"
            "sdkmessagefilterid@odata.bind" = "/sdkmessagefilters($sdkMessageFilterId)"
        }

        # Add filtering attributes if specified
        if ($FilteringAttributes -and $FilteringAttributes.Count -gt 0) {
            $webhookStep["filteringattributes"] = ($FilteringAttributes -join ",")
            Write-Verbose "Adding filtering attributes: $($FilteringAttributes -join ', ')"
        }

        if ($PSCmdlet.ShouldProcess($webhookStepName, "Create webhook step")) {
            $webhookStepHeaders = @{
                'Prefer' = 'odata.include-annotations="*",return=representation'
            }
            $webhookStepResult = Invoke-PSDVWebRequest -WebUri "api/data/v9.2/sdkmessageprocessingsteps" -Method Post -Body $webhookStep -Headers $webhookStepHeaders
            Write-Verbose "Webhook step created with ID: $($webhookStepResult.sdkmessageprocessingstepid)"

            # Step 5: Register pre-image if requested
            $preImageId = $null
            if ($PreImage) {
                Write-Verbose "Registering pre-image on webhook step"
                $preImageBody = @{
                    "sdkmessageprocessingstepid@odata.bind" = "/sdkmessageprocessingsteps($($webhookStepResult.sdkmessageprocessingstepid))"
                    "imagetype" = 0  # PreImage
                    "name" = "PreImage"
                    "entityalias" = "PreImage"
                    "messagepropertyname" = "Target"
                }

                if ($PreImageAttributes -and $PreImageAttributes.Count -gt 0) {
                    $preImageBody["attributes"] = ($PreImageAttributes -join ",")
                    Write-Verbose "Pre-image attributes: $($PreImageAttributes -join ', ')"
                }

                $preImageHeaders = @{
                    'Prefer' = 'odata.include-annotations="*",return=representation'
                }
                $preImageResult = Invoke-PSDVWebRequest -WebUri "api/data/v9.2/sdkmessageprocessingstepimages" -Method Post -Body $preImageBody -Headers $preImageHeaders
                $preImageId = $preImageResult.sdkmessageprocessingstepimageid
                Write-Verbose "Pre-image registered with ID: $preImageId"
            }

            # Step 6: Register post-image if requested
            $postImageId = $null
            if ($PostImage) {
                Write-Verbose "Registering post-image on webhook step"
                $postImageBody = @{
                    "sdkmessageprocessingstepid@odata.bind" = "/sdkmessageprocessingsteps($($webhookStepResult.sdkmessageprocessingstepid))"
                    "imagetype" = 1  # PostImage
                    "name" = "PostImage"
                    "entityalias" = "PostImage"
                    "messagepropertyname" = "Target"
                }

                if ($PostImageAttributes -and $PostImageAttributes.Count -gt 0) {
                    $postImageBody["attributes"] = ($PostImageAttributes -join ",")
                    Write-Verbose "Post-image attributes: $($PostImageAttributes -join ', ')"
                }

                $postImageHeaders = @{
                    'Prefer' = 'odata.include-annotations="*",return=representation'
                }
                $postImageResult = Invoke-PSDVWebRequest -WebUri "api/data/v9.2/sdkmessageprocessingstepimages" -Method Post -Body $postImageBody -Headers $postImageHeaders
                $postImageId = $postImageResult.sdkmessageprocessingstepimageid
                Write-Verbose "Post-image registered with ID: $postImageId"
            }
            
            # Return webhook registration details
            return [PSCustomObject]@{
                WebHookName = $WebHookName
                ServiceEndpointId = $serviceEndpoint.serviceendpointid
                WebHookStepId = $webhookStepResult.sdkmessageprocessingstepid
                Table = $Table
                Operation = $Operation
                TriggerUri = $TriggerUri
                Stage = $Stage
                Mode = $Mode
                Rank = $Rank
                SupportedDeployment = $SupportedDeployment
                FilteringAttributes = if ($FilteringAttributes) { $FilteringAttributes } else { $null }
                PreImageId = $preImageId
                PreImageAttributes = if ($PreImageAttributes) { $PreImageAttributes } else { $null }
                PostImageId = $postImageId
                PostImageAttributes = if ($PostImageAttributes) { $PostImageAttributes } else { $null }
            }
        }
    }
    catch {
        throw "Error creating webhook '$WebHookName': $($_.Exception.Message)"
    }
}


function Get-PSDVTableWebHook {
    <#
    .SYNOPSIS
    Retrieves registered webhooks for a Dataverse table.

    .DESCRIPTION
    Get-PSDVTableWebHook queries the Dataverse environment to find webhook registrations for a specified table.
    It returns detailed information about each webhook including the service endpoint details, execution settings,
    and associated SDK message information. By default, system and hidden webhooks are filtered out to show only
    user-created webhooks. This function is useful for auditing webhook configurations and troubleshooting issues.

    .PARAMETER Table
    The logical name of the Dataverse table to retrieve webhook registrations for.

    .PARAMETER Operation
    Optional filter to return webhooks for a specific operation only. Valid values are Create, Update, Delete, or Retrieve.

    .PARAMETER Url
    Optional filter to return webhooks for a specific endpoint URL only.

    .PARAMETER Stage
    Optional filter to return webhooks for a specific execution stage only. Valid values are PreValidation, PreOperation, MainOperation, or PostOperation.

    .PARAMETER Name
    Optional filter to return webhooks with names containing the specified text (case-insensitive partial match).

    .PARAMETER IncludeSystemWebHooks
    When specified, includes system-level and hidden webhooks in the results. By default, these are filtered out.

    .EXAMPLE
    Get-PSDVTableWebHook -Table "account"

    Retrieves user-created webhook registrations for the Account table (excludes system webhooks).

    .EXAMPLE
    Get-PSDVTableWebHook -Table "contact" -Operation "Create"

    Retrieves only user-created webhooks that trigger on Contact creation.

    .EXAMPLE
    Get-PSDVTableWebHook -Table "account" -Url "https://myapp.azurewebsites.net/api/webhook"

    Retrieves webhooks for the Account table that target a specific URL.

    .EXAMPLE
    Get-PSDVTableWebHook -Table "contact" -Stage "PreOperation" -Name "validation"

    Retrieves webhooks for the Contact table that run in PreOperation stage and have 'validation' in their name.

    .EXAMPLE
    Get-PSDVTableWebHook -Table "account" -IncludeSystemWebHooks

    Retrieves all webhook registrations for the Account table, including system-level webhooks.

    .EXAMPLE
    Get-PSDVTableWebHook -Table "spork_sporkuserrequest" | Select-Object Name, Url, Stage, Mode

    Retrieves webhooks for a custom table and displays specific properties.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]
        $Table,

        [Parameter()]
        [ValidateSet('Create', 'Update', 'Delete', 'Retrieve')]
        [String]
        $Operation,

        [Parameter()]
        [String]
        $Url,

        [Parameter()]
        [ValidateSet('PreValidation', 'PreOperation', 'MainOperation', 'PostOperation')]
        [String]
        $Stage,

        [Parameter()]
        [String]
        $Name,

        [Parameter()]
        [Switch]
        $IncludeSystemWebHooks
    )

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }

    try {
        Write-Verbose "Retrieving webhook registrations for table: $Table"
        
        # Build the query to get SDK message processing steps with webhook service endpoints
        $select = "sdkmessageprocessingstepid,name,description,stage,rank,mode,statuscode,supporteddeployment"
        $expand = "eventhandler_serviceendpoint(`$select=serviceendpointid,name,url,authtype,iscustomizable),sdkmessagefilterid(`$select=sdkmessagefilterid,primaryobjecttypecode),sdkmessageid(`$select=sdkmessageid,name)"
        
        # Filter for webhook steps (eventhandler_serviceendpoint exists) and specific table
        $filter = "eventhandler_serviceendpoint ne null and eventhandler_serviceendpoint/serviceendpointid ne null and sdkmessagefilterid/primaryobjecttypecode eq '$Table'"
        
        # Add operation filter if specified
        if ($PSBoundParameters.ContainsKey('Operation')) {
            $filter += " and sdkmessageid/name eq '$Operation'"
        }

        # Add URL filter if specified
        if ($PSBoundParameters.ContainsKey('Url')) {
            $filter += " and eventhandler_serviceendpoint/url eq '$Url'"
        }

        # Add stage filter if specified
        if ($PSBoundParameters.ContainsKey('Stage')) {
            $stageValue = switch ($Stage) {
                'PreValidation' { 10 }
                'PreOperation' { 20 }
                'MainOperation' { 30 }
                'PostOperation' { 40 }
            }
            $filter += " and stage eq $stageValue"
        }

        # Add name filter if specified (use 'contains' for partial matching)
        if ($PSBoundParameters.ContainsKey('Name')) {
            $filter += " and contains(name,'$Name')"
        }

        # Filter out system webhooks by default (more efficient than filtering locally)
        if (-not $IncludeSystemWebHooks.IsPresent) {
            $filter += " and eventhandler_serviceendpoint/iscustomizable/Value eq true"
        }

        $webhookSteps = Invoke-PSDVWebRequest -WebUri "api/data/v9.2/sdkmessageprocessingsteps" -Select $select -Expand $expand -Filter $filter
        
        if (-not $webhookSteps -or $webhookSteps.Count -eq 0) {
            Write-Verbose "No webhook registrations found for table '$Table'"
            return $null
        }

        Write-Verbose "Found $($webhookSteps.Count) webhook registration(s) for table '$Table'"

        # Convert to more user-friendly objects
        $results = foreach ($step in $webhookSteps) {
            [PSCustomObject]@{
                WebHookStepId = $step.sdkmessageprocessingstepid
                Name = $step.name
                Description = $step.description
                Table = $step.sdkmessagefilterid.primaryobjecttypecode
                Operation = $step.sdkmessageid.name
                Url = $step.eventhandler_serviceendpoint.url
                ServiceEndpointName = $step.eventhandler_serviceendpoint.name
                ServiceEndpointId = $step.eventhandler_serviceendpoint.serviceendpointid
                Stage = switch ($step.stage) {
                    10 { 'PreValidation' }
                    20 { 'PreOperation' }  
                    30 { 'MainOperation' }
                    40 { 'PostOperation' }
                    default { $step.stage }
                }
                Rank = $step.rank
                Mode = switch ($step.mode) {
                    0 { 'Synchronous' }
                    1 { 'Asynchronous' }
                    default { $step.mode }
                }
                Status = switch ($step.statuscode) {
                    1 { 'Enabled' }
                    2 { 'Disabled' }
                    default { $step.statuscode }
                }
                SupportedDeployment = switch ($step.supporteddeployment) {
                    0 { 'ServerOnly' }
                    1 { 'ClientOnly' }
                    2 { 'Both' }
                    default { $step.supporteddeployment }
                }
                AuthType = $step.eventhandler_serviceendpoint.authtype
                IsSystemWebHook = $step.eventhandler_serviceendpoint.iscustomizable.Value -eq $false
                IsCustomizable = $step.eventhandler_serviceendpoint.iscustomizable.Value -eq $true
                #HasAuthSecret = if ($step.eventhandler_serviceendpoint.authvalue -and $step.eventhandler_serviceendpoint.authvalue.Contains('x-dv-webhook-secret')) { $true } else { $false }
            }
        }

        # Update verbose message to reflect filtering
        if (-not $IncludeSystemWebHooks.IsPresent) {
            Write-Verbose "Returning $(@($results).Count) user webhook(s) (system webhooks filtered at API level)"
        } else {
            Write-Verbose "Returning $(@($results).Count) webhook(s) (including system webhooks)"
        }

        return $results
    }
    catch {
        throw "Error retrieving webhooks for table '$Table': $($_.Exception.Message)"
    }
}


function Remove-PSDVTableWebHook {
    <#
    .SYNOPSIS
    Removes a webhook registration from Dataverse by deleting its service endpoint.

    .DESCRIPTION
    Remove-PSDVTableWebHook removes a webhook registration by deleting the associated service endpoint from Dataverse.
    This will also automatically remove all associated SDK message processing steps (webhook steps) that reference
    this service endpoint. Use this function with caution as the deletion cannot be undone.

    .PARAMETER ServiceEndpointId
    The unique identifier (GUID) of the service endpoint to delete.

    .EXAMPLE
    Remove-PSDVTableWebHook -ServiceEndpointId "12345678-1234-1234-1234-123456789012"

    Removes the webhook by deleting the service endpoint with the specified ID.

    .EXAMPLE
    Get-PSDVTableWebHook -Table "account" | Where-Object Name -eq "My Account Webhook" | ForEach-Object {
        Remove-PSDVTableWebHook -ServiceEndpointId $_.ServiceEndpointId
    }

    Finds a specific webhook by name and removes it.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [String]
        $ServiceEndpointId
    )

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }

    try {
        # Get service endpoint details for confirmation
        Write-Verbose "Retrieving service endpoint details: $ServiceEndpointId"
        $serviceEndpoint = Invoke-PSDVWebRequest -WebUri "api/data/v9.2/serviceendpoints($ServiceEndpointId)" -Select "serviceendpointid,name,url"
        
        if (-not $serviceEndpoint) {
            throw "Service endpoint '$ServiceEndpointId' not found"
        }
        
        $endpointName = $serviceEndpoint.name
        Write-Verbose "Found service endpoint: $ServiceEndpointId ($endpointName)"

        # First, find and delete all associated SDK message processing steps
        Write-Verbose "Finding associated webhook steps for service endpoint: $ServiceEndpointId"
        $associatedSteps = Invoke-PSDVWebRequest -WebUri "api/data/v9.2/sdkmessageprocessingsteps" -Select "sdkmessageprocessingstepid,name" -Filter "eventhandler_serviceendpoint/serviceendpointid eq $ServiceEndpointId"
        
        if ($associatedSteps -and $associatedSteps.Count -gt 0) {
            Write-Verbose "Found $($associatedSteps.Count) associated webhook step(s) to delete"
            
            foreach ($step in $associatedSteps) {
                if ($PSCmdlet.ShouldProcess("Webhook Step '$($step.name)' ($($step.sdkmessageprocessingstepid))", "Delete associated webhook step")) {
                    Write-Verbose "Deleting webhook step: $($step.sdkmessageprocessingstepid) - $($step.name)"
                    $stepUri = $Global:DATAVERSEORGURL + "api/data/v9.2/sdkmessageprocessingsteps($($step.sdkmessageprocessingstepid))"
                    Invoke-PSDVWebRequest -WebUri $stepUri -Method 'Delete'
                    Write-Verbose "Successfully deleted webhook step: $($step.name)"
                } else {
                    Write-Verbose "Would delete webhook step: $($step.name)"
                }
            }
        } else {
            Write-Verbose "No associated webhook steps found for service endpoint: $ServiceEndpointId"
        }

        $requestHeaders = @{'Prefer' = 'odata.include-annotations="*"' }
        $dvRequestUri = $Global:DATAVERSEORGURL + "api/data/v9.2/serviceendpoints($ServiceEndpointId)"

        if ($PSCmdlet.ShouldProcess("Service Endpoint '$endpointName' ($ServiceEndpointId)", "Delete webhook")) {
            Write-Verbose "Deleting service endpoint: $ServiceEndpointId"
            $result = Invoke-PSDVWebRequest -WebUri $dvRequestUri -Headers $requestHeaders -Method 'Delete'
            
            Write-Verbose "Successfully deleted webhook service endpoint: $endpointName"
            return [PSCustomObject]@{
                Message = "Webhook service endpoint deleted successfully"
                ServiceEndpointId = $ServiceEndpointId
                Name = $endpointName
                AssociatedStepsDeleted = if ($associatedSteps) { $associatedSteps.Count } else { 0 }
                Deleted = $true
            }
        }
    }
    catch {
        throw "Error removing webhook service endpoint '$ServiceEndpointId': $($_.Exception.Message)"
    }
}


function Update-PSDVTableWebHookAuthSecret {
    <#
    .SYNOPSIS
    Updates the authentication secret for an existing Dataverse table webhook.

    .DESCRIPTION
    Update-PSDVTableWebHookAuthSecret modifies the authentication secret for an existing webhook registration.
    The function can find the webhook by table and name, or by the specific webhook step ID for more precise
    identification. It then updates the service endpoint's auth configuration with the new secret value.
    The secret will be passed in the x-dv-webhook-secret header when the webhook is triggered.
    If no secret is provided, the auth configuration is cleared.

    .PARAMETER Table
    The logical name of the Dataverse table that the webhook is registered for.

    .PARAMETER WebHookName
    The name of the webhook registration to update. Use when webhook names are unique for the table.

    .PARAMETER WebHookStepId
    The unique identifier (GUID) of the webhook step to update. Use when webhook names might not be unique or for precise identification.

    .PARAMETER AuthSecret
    The new authentication secret value. If not provided or empty, the auth configuration will be cleared.

    .EXAMPLE
    Update-PSDVTableWebHookAuthSecret -Table "account" -WebHookName "Account Changes Monitor" -AuthSecret "NewSecretValue123"

    Updates the authentication secret for the "Account Changes Monitor" webhook using name-based lookup.

    .EXAMPLE
    Update-PSDVTableWebHookAuthSecret -Table "contact" -WebHookStepId "12345678-1234-1234-1234-123456789012" -AuthSecret "NewSecretValue123"

    Updates the authentication secret for a specific webhook using its step ID.

    .EXAMPLE
    Update-PSDVTableWebHookAuthSecret -Table "contact" -WebHookName "Contact Sync Webhook" -AuthSecret ""

    Clears the authentication secret for the specified webhook.

    .EXAMPLE
    Get-PSDVTableWebHook -Table "account" | Where-Object Name -eq "My Webhook" | ForEach-Object {
        Update-PSDVTableWebHookAuthSecret -Table "account" -WebHookStepId $_.WebHookStepId -AuthSecret "UpdatedSecret"
    }

    Updates the auth secret for a webhook found via Get-PSDVTableWebHook using step ID for precise identification.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [Parameter(Mandatory, ParameterSetName = 'ByStepId')]
        [String]
        $Table,

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [String]
        $WebHookName,

        [Parameter(Mandatory, ParameterSetName = 'ByStepId')]
        [String]
        $WebHookStepId,

        [Parameter(ParameterSetName = 'ByName')]
        [Parameter(ParameterSetName = 'ByStepId')]
        [String]
        $AuthSecret
    )

    if ($null -eq $Global:DATAVERSEACCESSTOKEN) {
        throw 'No existing connection to Dataverse Environment, run Connect-PSDVOrg before executing other PSDV cmdlets'
    }

    try {
        $serviceEndpointId = $null
        $webhookInfo = $null

        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            Write-Verbose "Finding webhook '$WebHookName' for table '$Table' using name-based lookup"
            
            # Find the webhook by table and name
            $existingWebhook = Get-PSDVTableWebHook -Table $Table -Name $WebHookName
            
            if (-not $existingWebhook) {
                throw "Webhook '$WebHookName' not found for table '$Table'"
            }

            # Handle case where multiple webhooks match the name filter
            if ($existingWebhook.Count -gt 1) {
                # Try exact name match
                $exactMatch = $existingWebhook | Where-Object { $_.Name -eq $WebHookName }
                if ($exactMatch.Count -eq 1) {
                    $existingWebhook = $exactMatch
                } elseif ($exactMatch.Count -gt 1) {
                    throw "Multiple webhooks found with exact name '$WebHookName' for table '$Table'. Please use -WebHookStepId parameter for precise identification. Found step IDs: $($exactMatch.WebHookStepId -join ', ')"
                } else {
                    throw "Multiple webhooks found containing name '$WebHookName' for table '$Table'. Found: $($existingWebhook.Name -join ', '). Please use -WebHookStepId parameter for precise identification."
                }
            }

            $serviceEndpointId = $existingWebhook.ServiceEndpointId
            $webhookInfo = $existingWebhook
            Write-Verbose "Found webhook '$WebHookName' with service endpoint ID: $serviceEndpointId"
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'ByStepId') {
            Write-Verbose "Finding webhook with step ID '$WebHookStepId' for table '$Table' using step ID lookup"
            
            # Get webhook step details directly by ID and validate table
            $webhookStep = Invoke-PSDVWebRequest -WebUri "api/data/v9.2/sdkmessageprocessingsteps($WebHookStepId)" -Select "sdkmessageprocessingstepid,name,description" -Expand "eventhandler_serviceendpoint(`$select=serviceendpointid,name,url),sdkmessagefilterid(`$select=sdkmessagefilterid,primaryobjecttypecode)"
            
            if (-not $webhookStep) {
                throw "Webhook step '$WebHookStepId' not found"
            }

            # Validate that the webhook is for the specified table
            if ($webhookStep.sdkmessagefilterid.primaryobjecttypecode -ne $Table) {
                throw "Webhook step '$WebHookStepId' is not configured for table '$Table'. It is configured for table '$($webhookStep.sdkmessagefilterid.primaryobjecttypecode)'"
            }

            # Validate that it has a service endpoint (is actually a webhook)
            if (-not $webhookStep.eventhandler_serviceendpoint -or -not $webhookStep.eventhandler_serviceendpoint.serviceendpointid) {
                throw "Step '$WebHookStepId' is not a webhook step (no service endpoint found)"
            }

            $serviceEndpointId = $webhookStep.eventhandler_serviceendpoint.serviceendpointid
            $webhookInfo = [PSCustomObject]@{
                WebHookStepId = $webhookStep.sdkmessageprocessingstepid
                Name = $webhookStep.name
                ServiceEndpointId = $webhookStep.eventhandler_serviceendpoint.serviceendpointid
                Url = $webhookStep.eventhandler_serviceendpoint.url
                ServiceEndpointName = $webhookStep.eventhandler_serviceendpoint.name
            }
            Write-Verbose "Found webhook step '$($webhookStep.name)' with service endpoint ID: $serviceEndpointId"
        }

        # Prepare the auth value based on whether a secret is provided
        if ($PSBoundParameters.ContainsKey('AuthSecret') -and -not [string]::IsNullOrEmpty($AuthSecret)) {
            $authValue = "<settings><setting name=""x-dv-webhook-secret"" value=""$AuthSecret""/></settings>"
            $actionDescription = "Update authentication secret"
        } else {
            $authValue = "<settings></settings>"
            $actionDescription = "Clear authentication secret"
        }

        # Update the service endpoint
        $updateData = @{
            "authvalue" = $authValue
        }

        $targetDescription = if ($PSCmdlet.ParameterSetName -eq 'ByName') { 
            "$WebHookName (Service Endpoint: $serviceEndpointId)" 
        } else { 
            "$($webhookInfo.Name) (Step ID: $WebHookStepId, Service Endpoint: $serviceEndpointId)" 
        }

        if ($PSCmdlet.ShouldProcess($targetDescription, $actionDescription)) {
            $requestHeaders = @{
                'Prefer' = 'odata.include-annotations="*",return=representation'
            }
            
            Write-Verbose "$actionDescription for webhook '$($webhookInfo.Name)'"
            $result = Invoke-PSDVWebRequest -WebUri "api/data/v9.2/serviceendpoints($serviceEndpointId)" -Method Patch -Body $updateData -Headers $requestHeaders
            
            Write-Verbose "Successfully updated webhook authentication secret"
            
            # Return updated webhook information
            return [PSCustomObject]@{
                WebHookName = $webhookInfo.Name
                WebHookStepId = $webhookInfo.WebHookStepId
                Table = $Table
                ServiceEndpointId = $serviceEndpointId
                Url = $webhookInfo.Url
                ParameterSetUsed = $PSCmdlet.ParameterSetName
                AuthSecretUpdated = if ($PSBoundParameters.ContainsKey('AuthSecret') -and -not [string]::IsNullOrEmpty($AuthSecret)) { $true } else { $false }
                AuthSecretCleared = if (-not $PSBoundParameters.ContainsKey('AuthSecret') -or [string]::IsNullOrEmpty($AuthSecret)) { $true } else { $false }
                UpdatedOn = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        } else {
            $whatIfTarget = if ($PSCmdlet.ParameterSetName -eq 'ByName') { $WebHookName } else { "$($webhookInfo.Name) (Step ID: $WebHookStepId)" }
            Write-Verbose "Would $($actionDescription.ToLower()) for webhook: $whatIfTarget"
            return
        }
    }
    catch {
        $errorTarget = if ($PSCmdlet.ParameterSetName -eq 'ByName') { 
            "'$WebHookName' in table '$Table'" 
        } else { 
            "step ID '$WebHookStepId' in table '$Table'" 
        }
        throw "Error updating webhook auth secret for $errorTarget`: $($_.Exception.Message)"
    }
}