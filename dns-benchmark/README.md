### DNS 解析速度基准测试 (dns-benchmark)

这个目录包含一个用于测试常见公共 DNS 解析速度的 PowerShell 脚本 `dns-benchmark.ps1`。

工作原理：
- 脚本在顶部定义了待测的 DNS 服务器列表（名字 -> IP）。
- 对每个 DNS 服务器，脚本使用 `Resolve-DnsName` 指定 `-Server` 参数向该 DNS 发送解析请求（默认测试域名为 `www.baidu.com`）。
- 每个 DNS 进行多次（脚本中为 5 次）解析，记录每次的耗时（毫秒），并计算平均耗时。
- 为提高效率，脚本使用 PowerShell 的 `RunspacePool` 并发执行多个解析任务（由 `$maxParallel` 控制）。
- 最终按平均耗时排序并展示结果，同时列出推荐的前三个 DNS。

运行要求：
- Windows PowerShell（包含 `Resolve-DnsName` 命令的版本，例如 Windows PowerShell 4.0 及以上）。在非 Windows 平台或较旧环境下如无 `Resolve-DnsName`，脚本会报错或需要替换为 `nslookup` 等工具。
- 需要网络访问权限以向外部 DNS 服务器发送查询。

快速使用说明：
1. 打开 PowerShell（以普通或管理员身份均可）。
2. 进入本目录并运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\dns-benchmark.ps1
```

可选项（手动修改脚本中的变量）：
- 修改 `$testDomain` 来测试其他域名（例如 `google.com`）。
- 修改 `$maxParallel` 来调整并发测试线程数（默认 `5`）。
- 修改 `$dnsServers` 列表以增删想要测试的 DNS 条目。

输出示例：
- 脚本将在控制台打印每个 DNS 的平均解析耗时并按耗时排序，随后列出 `Recommended DNS`（平均耗时最低的前 3 个）。

注意事项：
- 网络状况会影响测试结果，建议在稳定网络环境下重复测试以获得更可靠的排序。
- 对于无法解析或超时的查询，脚本会将该次耗时视为较大值（脚本中为 `9999` ms），从而影响平均值。

如果你想让脚本支持命令行参数（例如传入测试域或并发数），我可以帮你修改脚本以支持 `-Domain` / `-Parallel` 参数并更新 README 示例。
