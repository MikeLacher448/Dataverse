function ConvertTo-PSDVXmlAttributeValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [String]
        $Value
    )

    return [System.Security.SecurityElement]::Escape($Value)
}
