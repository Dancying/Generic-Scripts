# Shell Cheatsheet

适用于 Debian 系统的 Shell 命令速查表。  


## 创建命令别名 (Custom Aliases)

1. 安装 vim 编辑器：  
    ```sh
    apt install vim
    ```
2. 创建并编辑别名脚本文件：  
    ```sh
    vim /etc/profile.d/99-custom-aliases.sh
    ```
3. 粘贴以下内容到别名脚本文件：  
    ```sh
    #!/bin/bash

    # =================================================
    #                Custom Aliases 配置
    # =================================================

    # --- 文本编辑器别名 ---
    alias vi='vim'        # 映射 vi 到功能更强大的 Vim
    alias svi='sudo vi'   # 使用 sudo 权限启动 Vi/Vim

    # --- 文本搜索着色别名 ---
    alias grep='grep --color=auto'    # 对匹配文本自动着色
    alias egrep='egrep --color=auto'  # egrep 自动着色
    alias fgrep='fgrep --color=auto'  # fgrep 自动着色

    # --- 目录列表 (ls) 别名 ---
    alias ls='ls --color=auto'    # 显示彩色输出
    alias l='ls -lh'              # 详细信息 (可读大小)
    alias ll='ls -lha'            # 所有文件 (包括隐藏文件) 详细信息
    alias la='ls -A'              # 所有文件 (不包括 . 和 ..)
    alias lt='ls -ltrh'           # 按修改时间倒序显示所有文件 (最新的在底部)

    # --- 操作安全增强别名 ---
    alias rm='rm -i'    # 删除文件时要求确认
    alias cp='cp -i'    # 复制文件时要求确认覆盖
    alias mv='mv -i'    # 移动/重命名文件时要求确认覆盖

    # --- 常用效率和信息查询别名 ---
    alias ..='cd ..'      # 快速返回上级目录
    alias ...='cd ../..'  # 快速返回上两级目录
    alias cls='clear'     # 清空终端屏幕
    alias df='df -h'      # 可读格式显示磁盘空间 (Disk Free)

    # --- 系统维护别名 (Debian/Ubuntu) ---
    alias update='sudo apt update && sudo apt upgrade -y'   # 更新软件列表并升级已安装软件包
    alias install='sudo apt install'                        # 简化软件包安装命令
    alias remove='sudo apt autoremove'                      # 自动移除不再需要的依赖包
    alias search='apt search'                               # 简化软件包搜索命令
    ```
4. 为别名脚本添加执行权限：  
    ```sh
    chmod +x /etc/profile.d/99-custom-aliases.sh
    ```
5. 在当前会话中立即生效命令别名：  
    ```sh
    source /etc/profile.d/99-custom-aliases.sh
    ```


## 配置密钥登录 (SSH Key-Based Login)

1. 生成 Ed25519 密钥:  
    ```sh
    ssh-keygen -t ed25519
    ```
2. 创建 `.ssh` 文件夹：  
    ```sh
    mkdir -p ~/.ssh
    ```
3. 创建并编辑 `authorized_keys` 文件：  
    ```sh
    vi ~/.ssh/authorized_keys
    ```
    > 需要粘贴 `.pub` 文件中的内容  
4. 修改 `.ssh` 文件夹权限：  
    ```sh
    chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
    ```


## 修改 SSH 登录 (Disable Password Login)

1. 编辑 SSH 配置文件：  
    ```sh
    vi /etc/ssh/sshd_config
    ```
2. 查找以下配置项并修改为如下值：  
    ```sh
    ...
    Port 12345                      # 更改 SSH 默认端口
    ...
    PubkeyAuthentication yes        # 启用密钥登录
    ...
    PasswordAuthentication no       # 禁用密码登录
    ...
    PermitRootLogin no              # 禁止 root 用户直接登录
    ...
    ```
3. 重启 SSH 服务：  
    ```sh
    systemctl restart ssh
    ```

> 重启 SSH 服务后先不要退出当前连接，而是另起一个新的连接验证登录。  


## 启用 UFW 防火墙 (Enable UFW Firewall)

1. 安装 UFW 防火墙：  
    ```sh
    apt install ufw
    ```
2. 拒绝所有进站连接：  
    ```sh
    ufw default deny incoming
    ```
3. 允许所有出站连接：  
    ```sh
    ufw default allow outgoing
    ```
4. 放行 SSH 端口：  
    ```sh
    ufw allow 12345/tcp
    ```
5. 激活 UFW 规则：  
    ```sh
    ufw enable
    ```
6. 启动 UFW 服务：  
    ```sh
    systemctl start ufw
    ```
7. 设置 UFW 开机自启：  
    ```sh
    systemctl enable ufw
    ```
8. 检查 UFW 状态：  
    ```sh
    ufw status verbose
    ```

