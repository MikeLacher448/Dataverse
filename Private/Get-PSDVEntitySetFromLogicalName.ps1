function Get-PSDVEntitySetFromLogicalName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]
        $Table
    )

    try {
        $tableLiteral = ConvertTo-PSDVODataStringLiteral -Value $Table
        return (Invoke-PSDVWebRequest -WebUri "EntityDefinitions(LogicalName=$tableLiteral)" -Select 'EntitySetName').EntitySetName
    }
    catch {
        throw "Cannot find table $Table in Dataverse Environment. $($_.InvocationInfo.MyCommand.Name),  $($_.InvocationInfo.InvocationName) , $($_ | Out-String)"
    }
}
