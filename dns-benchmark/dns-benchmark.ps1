# 最大并发数
$maxParallel = 5

# DNS 列表
$dnsServers = @{
    # --- 国内主流公共 DNS ---
    "AliDNS-1"       = "223.5.5.5"
    "AliDNS-2"       = "223.6.6.6"
    "Tencent-1"      = "119.29.29.29"
    "Tencent-2"      = "119.28.28.28"
    "114DNS-1"       = "114.114.114.114"
    "114DNS-2"       = "114.114.115.115"
    "ByteDance-1"    = "180.184.1.1"
    "ByteDance-2"    = "180.184.2.2"
    "BaiduDNS"       = "180.76.76.76"
    "360DNS-1"       = "101.226.4.6"
    "360DNS-2"       = "218.30.118.6"
    "CNNIC-SDNS"     = "1.2.4.8"

    # --- 国际知名 DNS (国内访问可能波动) ---
    "Google-1"       = "8.8.8.8"
    "Google-2"       = "8.8.4.4"
    "Cloudflare-1"   = "1.1.1.1"
    "Cloudflare-2"   = "1.0.0.1"
    "Quad9"          = "9.9.9.9"
}

$testDomain = "www.baidu.com"

Write-Host ""
Write-Host "Starting DNS resolve benchmark (RunspacePool)..." -ForegroundColor Cyan
Write-Host "Max parallel: $maxParallel"
Write-Host ""

$total = $dnsServers.Count
$completed = 0
$results = @()

# 创建线程池
$pool = [runspacefactory]::CreateRunspacePool(1, $maxParallel)
$pool.Open()

$tasks = New-Object System.Collections.ArrayList

foreach ($entry in $dnsServers.GetEnumerator()) {

    $ps = [powershell]::Create()
    $ps.RunspacePool = $pool

    $script = {
        param($name,$ip,$domain)

        $times = @()

        for ($i=0; $i -lt 5; $i++) {
            try {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                Resolve-DnsName $domain -Server $ip -ErrorAction Stop | Out-Null
                $sw.Stop()
                $times += $sw.ElapsedMilliseconds
            }
            catch {
                $times += 9999
            }
        }

        $avg = ($times | Measure-Object -Average).Average

        [PSCustomObject]@{
            DNS = $name
            IP = $ip
            AvgResolve_ms = [math]::Round($avg,2)
        }
    }

    $null = $ps.AddScript($script).
        AddArgument($entry.Key).
        AddArgument($entry.Value).
        AddArgument($testDomain)

    $handle = $ps.BeginInvoke()

    $tasks.Add([PSCustomObject]@{
        PowerShell = $ps
        Handle     = $handle
    }) | Out-Null
}

# 等待任务完成
while ($tasks.Count -gt 0) {

    foreach ($task in @($tasks)) {

        if ($task.Handle.IsCompleted) {

            $result = $task.PowerShell.EndInvoke($task.Handle)

            $results += $result

            $task.PowerShell.Dispose()

            $tasks.Remove($task)

            $completed++

            Write-Host "Testing progress: $completed/$total"
        }
    }

    Start-Sleep -Milliseconds 100
}

$pool.Close()
$pool.Dispose()

# 排序
$sorted = $results | Sort-Object AvgResolve_ms

Write-Host ""
Write-Host "Test Result:" -ForegroundColor Yellow
$sorted | Format-Table -AutoSize

Write-Host ""
Write-Host "Recommended DNS:" -ForegroundColor Green

$top = $sorted | Select-Object -First 3

$i = 1
foreach ($item in $top) {
    Write-Host "$i. $($item.IP)  AvgResolve:$($item.AvgResolve_ms)ms"
    $i++
}

Write-Host ""
Write-Host "Best DNS -> $($top[0].IP)" -ForegroundColor Cyan