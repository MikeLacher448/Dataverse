function New-PSDVBatchRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]
        $EntitySet,

        [Parameter(Mandatory)]
        [ValidateSet('Create', 'Update', 'Upsert')]
        [string]
        $Operation,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]
        $Items,

        [Parameter()]
        [hashtable]
        $AttributeDetails,

        [Parameter()]
        [string]
        $AlternateKeyColumnName,

        [Parameter()]
        [switch]
        $ParseItemData,

        [Parameter()]
        [switch]
        $CreateOnly
    )

    $batchBoundary = "batch_$([guid]::NewGuid().ToString('N'))"
    $bodyLines = [System.Collections.Generic.List[string]]::new()
    $contentId = 1

    foreach ($item in $Items) {
        $itemData = $item.ItemData
        $itemDataForRequest = @{}
        foreach ($key in $itemData.Keys) {
            $itemDataForRequest[$key] = $itemData[$key]
        }

        if ($Operation -eq 'Upsert' -and $CreateOnly.IsPresent -and -not $itemDataForRequest.ContainsKey($AlternateKeyColumnName)) {
            $itemDataForRequest[$AlternateKeyColumnName] = $item.AlternateKeyValue
        }

        $itemDataToProcess = if ($ParseItemData.IsPresent) {
            $itemAttributeDetails = @{}
            foreach ($key in $itemDataForRequest.Keys) {
                $itemAttributeDetails[$key] = $AttributeDetails[$key]
            }

            ConvertTo-PSDVLookupItemData -ItemData $itemDataForRequest -AttributeDetails $itemAttributeDetails
        }
        else {
            $itemDataForRequest
        }

        switch ($Operation) {
            'Create' {
                $method = 'POST'
                $requestUri = $EntitySet
            }
            'Update' {
                $method = 'PATCH'
                $requestUri = "$EntitySet($($item.ItemID))"
            }
            'Upsert' {
                if ($CreateOnly.IsPresent) {
                    $method = 'POST'
                    $requestUri = $EntitySet
                }
                else {
                    $method = 'PATCH'
                    $alternateKeyLiteral = ConvertTo-PSDVODataStringLiteral -Value ([string]$item.AlternateKeyValue)
                    $requestUri = "$EntitySet($AlternateKeyColumnName=$alternateKeyLiteral)"
                }
            }
        }

        $changesetBoundary = "changeset_$([guid]::NewGuid().ToString('N'))"

        $bodyLines.Add("--$batchBoundary")
        $bodyLines.Add("Content-Type: multipart/mixed;boundary=$changesetBoundary")
        $bodyLines.Add('')
        $bodyLines.Add("--$changesetBoundary")
        $bodyLines.Add('Content-Type: application/http')
        $bodyLines.Add('Content-Transfer-Encoding: binary')
        $bodyLines.Add("Content-ID: $contentId")
        $bodyLines.Add('')
        $bodyLines.Add("$method $requestUri HTTP/1.1")
        $bodyLines.Add('Content-Type: application/json;type=entry')

        $bodyLines.Add('')
        $bodyLines.Add(($itemDataToProcess | ConvertTo-Json -Compress -Depth 10))
        $bodyLines.Add("--$changesetBoundary--")
        $contentId++
    }

    $bodyLines.Add("--$batchBoundary--")

    return [pscustomobject]@{
        BatchBoundary = $batchBoundary
        BatchBody     = ($bodyLines -join "`r`n") + "`r`n"
        RequestedCount = @($Items).Count
    }
}