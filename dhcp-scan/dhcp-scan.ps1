# 1. 获取网卡
$itfs = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.InterfaceAlias -notmatch "Loopback|vEthernet|Pseudo|Virtual" -and $_.IPv4Address -ne "127.0.0.1" 
}

if (-not $itfs) { Write-Host "No IPv4 Interface found."; return }

Write-Host "--- Network Interfaces ---"
for ($i = 0; $i -lt $itfs.Count; $i++) {
    Write-Host ("[" + $i + "] " + $itfs[$i].InterfaceAlias + " - " + $itfs[$i].IPv4Address)
}

$choice = Read-Host "Select Index (Default 0)"
if ([string]::IsNullOrWhiteSpace($choice)) { $choice = "0" }
$ip = $itfs[[int]$choice].IPv4Address

# 2. 初始化 Socket
$client = New-Object System.Net.Sockets.UdpClient
$client.Client.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
$client.EnableBroadcast = $true

try {
    $localEP = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Parse($ip), 68)
    $client.Client.Bind($localEP)
} catch {
    Write-Host "Bind failed. Please run as Administrator!" -ForegroundColor Red
    return
}

# 3. 构造 DHCP 报文 (避开切片赋值坑)
$buf = New-Object byte[] 244
$xid = [BitConverter]::GetBytes([uint32](Get-Random))
if ([BitConverter]::IsLittleEndian) { [Array]::Reverse($xid) }

# 基础头部
$buf[0] = 0x01 # BootRequest
$buf[1] = 0x01 # Ethernet
$buf[2] = 0x06 # MAC Len
[Array]::Copy($xid, 0, $buf, 4, 4) # Transaction ID
$buf[10] = 0x80 # Broadcast Flag

# 填充 MAC 地址 (手动赋值避免类型转换错误)
$mac = [byte[]](0x00, 0x15, 0x5D, 0xAA, 0xBB, 0xCC)
for($i=0; $i -lt 6; $i++) { $buf[28 + $i] = $mac[$i] }

# Magic Cookie
$cookie = [byte[]](0x63, 0x82, 0x53, 0x63)
for($i=0; $i -lt 4; $i++) { $buf[236 + $i] = $cookie[$i] }

# Option 53: DHCP Discover (53, 1, 1)
$buf[240] = 53
$buf[241] = 1
$buf[242] = 1

# End Option
$buf[243] = 255

# 4. 发送并监听
$rem = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Broadcast, 67)
$client.Send($buf, $buf.Length, $rem) | Out-Null

$client.Client.ReceiveTimeout = 5000
$srvs = @{}

Write-Host ("Scanning on " + $ip + "...") -ForegroundColor Yellow

try {
    while ($true) {
        $ref = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $raw = $client.Receive([ref]$ref)
        $sIP = $ref.Address.ToString()
        if (-not $srvs.ContainsKey($sIP)) {
            $srvs[$sIP] = $true
            Write-Host "Found DHCP Server: $sIP" -ForegroundColor Green
        }
    }
} catch {
    # Timeout
} finally {
    $client.Close()
    $client.Dispose()
}

Write-Host "--- Done ---"
Write-Host ("Total Servers Found: " + $srvs.Count)