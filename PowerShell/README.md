# PowerShell Cheatsheet

适用于 Windows 系统的 PowerShell 命令速查表。  


## 系统管理

- 获取精简的 Windows 系统信息：  
    ```sh
    Get-CimInstance -ClassName Win32_ComputerSystem | Select-Object Name, Manufacturer, Model, NumberOfProcessors, NumberOfLogicalProcessors, @{N='TotalPhysicalMemory';E={[math]::Round($_.TotalPhysicalMemory/1GB, 2).ToString() + "GB"}}, @{N='OsName';E={(Get-ComputerInfo -Property OsName).OsName}}, @{N='OsVersion';E={(Get-ComputerInfo -Property OsVersion).OsVersion}}, @{N='OsArchitecture';E={(Get-ComputerInfo -Property OsArchitecture).OsArchitecture}}, @{N='OsInstallDate';E={(Get-ComputerInfo -Property OsInstallDate).OsInstallDate.ToShortDateString()}}
    ```

- 连接远程服务器并进行交互式会话：  
    ```sh
    Enter-PSSession -ComputerName "YourRemoteServerName" -Credential "YourUsername"
    ```


### 账户管理

- 列出所有本地账户名称和启用状态：  
    ```sh
    Get-LocalUser
    ```

- 显示指定账户详细信息：  
    ```sh
    Get-LocalUser -Name "UserName" | Format-List *
    ```

- 启用指定本地账户：  
    ```sh
    Enable-LocalUser -Name "UserName"
    ```

- 禁用指定本地账户：  
    ```sh
    Disable-LocalUser -Name "UserName"
    ```


### 防火墙管理

- 快速创建防火墙入站规则：  
    ```sh
    New-NetFirewallRule `
        -DisplayName "NewDisplayName" `         # 防火墙管理界面中展示的名称
        -Direction Inbound `                    # 指定规则应用于入站流量
        -Protocol TCP `                         # 指定规则应用于 TCP 协议，可选协议： TCP, UDP, ICMPv4, Any
        -LocalPort 12345 `                      # 指定要开放的端口号，示例端口： 80, 443, 1000-2000, Any
        -Action Allow `                         # 指定匹配流量的操作为“允许”，可选操作： Allow, Block
        -Enabled True `                         # 确保规则创建后立即生效
        -DisplayGroup "NewDisplayGroupName" `   # 防火墙管理界面中展示的组名称
        -Profile Any                            # 指定规则适用于所有网络类型（域、专用、公用）
    ```
    - 需要自定义修改 `DisplayName` 、 `LocalPort` 、 `DisplayGroup` 参数的值；  
    - 其他可选参数如下：  
        ```sh
        -Name "NewName"                                             # 唯一标识符，常用于脚本自动化管理
        -Description "NewDescription"                               # 详细描述，说明规则的目的和用途
        -RemoteAddress 0.0.0.0-255.255.255.255                      # 确保仅作用于 IPv4 地址
        -RemoteAddress ::-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff   # 确保仅作用于 IPv6 地址
        ```

- 查询已启用的防火墙入站规则并生成 HTML 结果：  
    ```sh
    $Header = "<style>body{font-family:sans-serif;margin:20px}TABLE{border-collapse:collapse;width:100%}TH{padding:10px;background:#0078D4;color:#fff;text-align:left}TD{padding:8px;border:1px solid #ddd}.Allow{color:green;font-weight:bold}TR:nth-child(even){background:#f9f9f9}</style>"

    $Html = Get-NetFirewallRule -Enabled True -Direction Inbound -Action Allow | ForEach-Object {
        $p = $_ | Get-NetFirewallPortFilter
        $a = $_ | Get-NetFirewallAddressFilter
        [PSCustomObject]@{
            规则名称 = $_.DisplayName
            方向     = $_.Direction
            动作     = $_.Action
            协议     = $p.Protocol
            本地端口 = $p.LocalPort
            远程端口 = $p.RemotePort
            本地IP   = $a.LocalAddress
            远程IP   = $a.RemoteAddress
        }
    } | ConvertTo-Html -Head $Header -PreContent "<h2>允许入站规则报告</h2>" | Out-String

    $Html = $Html -replace "<td>Allow</td>", "<td class='Allow'>Allow</td>"

    $Path = "$env:TEMP\InboundAllow.html"
    $Html | Out-File $Path
    Invoke-Item $Path
    ```


### 可选功能管理

- 安装 Hyper-V 底层组件和服务（不安装 Hyper-V 管理面板）并立即重启：  
    ```sh
    Install-WindowsFeature -Name Hyper-V -Restart
    ```


## 应用配置

### osu!

- 管理员命令，创建 osu! 歌曲文件夹符号链接：  
    ```sh
    Remove-Item -Path "$env:LOCALAPPDATA\osu!\Songs" -Recurse -Force
    New-Item -ItemType SymbolicLink -Path "$env:LOCALAPPDATA\osu!\Songs" -Target "D:\osu!\Songs"
    ```
    > 该命令将会先删除原文件夹，注意备份数据；  
    > 符号链接会把访问原文件夹的文件操作重定向至目标文件夹；  


### Clash

- 获取 Clash 格式的订阅配置文件，需要根据提示输入正确的订阅链接：  
    ```sh
    $L=Read-Host 'Enter the subscription link';(Invoke-WebRequest $L -UserAgent Clash).Content|Out-File -E utf8 config.yaml;Write-Host "File saved successfully at: $(Resolve-Path config.yaml)"
    ```


## 数据生成

- 生成 10000 到 60000 之间的随机端口：  
    ```sh
    Get-Random -Minimum 10000 -Maximum 60001
    ```

- 生成 8 位长度的英文大小写加数字的随机字符串：  
    ```sh
    -join (Get-Random -InputObject ('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'.ToCharArray()) -Count 8)
    ```

- 生成 16 位长度的高强度随机密码：  
    ```sh
    -join (Get-Random -InputObject ('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>?'.ToCharArray()) -Count 16)
    ```

