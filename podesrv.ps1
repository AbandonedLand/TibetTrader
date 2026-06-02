Start-PodeServer {
    # Open an HTTP endpoint on port 8080
    Add-PodeEndpoint -Address * -Port 8080 -Protocol Http

    # Define a POST route
    Add-PodeRoute -Method Post -Path '/offer' -ScriptBlock {
        # 1. Access parsed JSON properties directly from $WebEvent.Data
        $WebEvent.Data.offer | nats publish chia.all
    }
}