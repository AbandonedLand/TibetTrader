function ConvertFrom-DexieStream {
    param(
        $stream
    )

    try{
        
        $data = $stream | ConvertFrom-Json

        if($data.type -eq "market"){
            $subject = "chia.v1.dexie.market.$($data.data.id)"
            Publish-StreamData -subject $subject -message_object $($data.data)
        }
        if($data.type -eq "offer"){
            $subject = "chia.v1.dexie.offer_id.$($data.data.id)"
            $payload = @{
                status = $($data.data.status)
            }
            
            Publish-StreamData -subject $subject -message_object $payload
            
            
            $offered = $data.data.offered[0].id
            $requested = $data.data.requested[0].id
            $subject = "chia.v1.dexie.offered.$offered.requested.$requested"
            Publish-StreamData -subject $subject -message_object $($data.data)
        }


    } catch {

    }
}

function Publish-StreamData{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$subject,
        [Parameter(Mandatory)]
        [pscustomobject]$message_object
    )
    try{
        $msg = $message_object | ConvertTo-Json -Compress -Depth 20
        nats pub $subject $msg
    } catch {
        Write-Error "Coult not publish to message to subject."
    }
    
}

function Invoke-ConsumeStreamcoinset {
   while($true){
        try{
            nats consumer next Firehose coinsetws --raw | ForEach-Object {
                $data = $_ | ConvertFrom-Json
                if($data.message.data.tx){
                    # Post Block info
                    $height = ($data.message.data.height)
                    $response = Get-CoinSetBlockRecordbyHeight -height $height
                    Publish-StreamData -subject "chia.v1.blocks" -message_object $response

                    # Post Additions and removals
                    $hash = $response.block_record.header_hash
                    $adds = Get-CoinSetBlockSpend -header_hash $hash
                    Publish-StreamData -subject "chia.v1.block.$($height)" -message_object ($adds.block_spends)

                    $adds.block_spends | ForEach-Object {
                        Publish-StreamData -subject "chia.v1.coin.$($_.coin.parent_coin_info)" -message_object $_
                    }
                    
                }
            }
        } catch {}
    }
}

function Get-CoinSetBlockRecordbyHeight {
    param(
        [uint]$height
    )

    $json = @{
        height = $height
    }
    Invoke-RestMethod -Method Post -Uri "https://api.coinset.org/get_block_record_by_height" -ContentType 'application/json' -Body ($json | ConvertTo-Json)
}

function Invoke-ConsumeDexiews {

    while($true){
        nats consumer next Firehose fhdexie --raw | ForEach-Object {ConvertFrom-DexieStream -stream $_}
    }
}