function Invoke-PSDVBatchRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]
        $BatchRequest,

        [Parameter()]
        [string]
        $ErrorMessagePrefix = 'Dataverse batch request'
    )

    Set-PSDVAccessToken

    $batchUri = "$($Global:DATAVERSEORGURL.TrimEnd('/'))/api/data/v9.2/`$batch"
    $batchResponse = Invoke-WebRequest `
        -Authentication OAuth `
        -Token $Global:DATAVERSEACCESSTOKEN.Token `
        -Method Post `
        -Uri $batchUri `
        -ContentType "multipart/mixed;boundary=$($BatchRequest.BatchBoundary)" `
        -Body $BatchRequest.BatchBody

    if ($batchResponse.StatusCode -lt 200 -or $batchResponse.StatusCode -ge 300) {
        throw "$ErrorMessagePrefix returned HTTP status $($batchResponse.StatusCode)."
    }

    return ConvertFrom-PSDVBatchResponse -BatchResponse $batchResponse -ExpectedCount $BatchRequest.RequestedCount
}