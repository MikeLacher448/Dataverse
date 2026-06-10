function Join-PSDVQueryString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary]
        $QueryParameters
    )

    return ($QueryParameters.GetEnumerator() | Where-Object { $null -ne $_.Value -and -not [string]::IsNullOrWhiteSpace([string]$_.Value) } | ForEach-Object {
        '{0}={1}' -f [System.Uri]::EscapeDataString([string]$_.Key), [System.Uri]::EscapeDataString([string]$_.Value)
    }) -join '&'
}
