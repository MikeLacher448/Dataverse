function ConvertTo-PSDVODataStringLiteral {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String]
        $Value
    )

    return "'$($Value -replace "'", "''")'"
}
