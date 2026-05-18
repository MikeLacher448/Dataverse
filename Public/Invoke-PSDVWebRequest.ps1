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
         $errorMessage = $_ | Out-String
      
         throw "Error executing web query: $errorMessage"
    }

    if ($ReturnRawResponse) {
        return $webResponse
    }
    else {
        if ($null -eq $webResponse -or [string]::IsNullOrWhiteSpace($webResponse.Content)) {
            return $null
        }

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

