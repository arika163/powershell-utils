# 1. 初始化 UDP Client 并启用端口复用 (避免与系统自带 DHCP 客户端冲突)
$client = New-Object System.Net.Sockets.UdpClient
$client.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
$client.EnableBroadcast = $true

# 绑定到正确的 DHCP 客户端端口 68
$localEP = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 68)
$client.Client.Bind($localEP)

# 2. 生成 Transaction ID
$transactionId = [uint32](Get-Random)
$b1 = ($transactionId -shr 24) -band 0xFF
$b2 = ($transactionId -shr 16) -band 0xFF
$b3 = ($transactionId -shr 8)  -band 0xFF
$b4 = $transactionId -band 0xFF

# 3. 构造 DHCP Discover 报文 (增加到 244 字节以容纳 Options)
$buffer = New-Object byte[] 244

# BOOTP Header (0-27)
$buffer[0] = 0x01 # Message Type: BootRequest
$buffer[1] = 0x01 # Hardware Type: Ethernet
$buffer[2] = 0x06 # Hardware Address Length: 6
$buffer[3] = 0x00 # Hops
$buffer[4] = $b1; $buffer[5] = $b2; $buffer[6] = $b3; $buffer[7] = $b4 # Transaction ID

# CHADDR (Client Hardware Address, 偏移量 28-33) - 填入一个伪造的 MAC 地址
$buffer[28] = 0x00; $buffer[29] = 0x11; $buffer[30] = 0x22
$buffer[31] = 0x33; $buffer[32] = 0x44; $buffer[33] = 0x55

# Magic Cookie (偏移量 236-239)
$buffer[236] = 0x63; $buffer[237] = 0x82; $buffer[238] = 0x53; $buffer[239] = 0x63

# Option 53: DHCP Message Type (偏移量 240-242)
$buffer[240] = 53   # Option Code: 53
$buffer[241] = 1    # Length: 1
$buffer[242] = 1    # Value: 1 (Discover)

# Option 255: End (偏移量 243)
$buffer[243] = 255  # 0xFF

# 4. 发送广播包到 DHCP 服务器端口 67
$remoteEP = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Broadcast, 67)
$client.Send($buffer, $buffer.Length, $remoteEP) | Out-Null

Write-Host "DHCP Discover sent, waiting for response..."

# 5. 监听与接收
$client.Client.ReceiveTimeout = 5000
$servers = @{}

try {
    while ($true) {
        $remote = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $response = $client.Receive([ref]$remote)
        
        $ip = $remote.Address.ToString()

        if (-not $servers.ContainsKey($ip)) {
            $servers[$ip] = $true
            Write-Host "DHCP Server found: $ip"
            # 进阶：可以在这里解析 $response 字节数组来提取 DHCP Offer 的详情
        }
    }
}
catch [System.Net.Sockets.SocketException] {
    # 只捕获 SocketException，避免掩盖其他意外的语法错误
    Write-Host "Receiving finished (timeout)"
}
finally {
    # 确保释放 Socket 资源
    if ($client) {
        $client.Close()
        $client.Dispose()
    }
}

Write-Host "`n==============================="
Write-Host "Total DHCP Servers found: $($servers.Count)"
Write-Host "==============================="