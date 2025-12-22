# Podman Cheatsheet

适用于 Podman 的常用命令速查表。  


## 安装 Podman

- 使用 `apt` 命令安装：  
    ```sh
    apt install podman
    ```

- 安装完成后可以执行以下命令查看版本信息：  
    ```sh
    podman --version
    ```


## 镜像管理

- 在镜像仓库中搜索镜像：  
    ```sh
    podman search nginx
    ```

- 拉取镜像到本地：  
    ```sh
    podman pull docker.io/library/nginx:latest
    ```
    > 拉取镜像需要使用镜像完整名称，例如以 `docker.io` 或 `ghcr.io` 等镜像站开头  

- 列出已拉取到本地的镜像列表：  
    ```sh
    podman images
    ```

- 删除指定镜像：  
    ```sh
    podman rmi <id_1> <id_2>
    ```

- 删除未被任何容器使用的所有镜像：  
    ```sh
    podman image prune -a
    ```

- 将镜像导出为 tar 包：  
    ```sh
    podman save -o my-image-backup.tar <id>
    ```

- 从 tar 包导入镜像：  
    ```sh
    podman load -i my-image-backup.tar
    ```


## 容器管理

- 后台运行一个容器：  
    ```sh
    podman run -d --name my-web -p 8080:80 nginx
    ```
    - 参数 `-d` : 后台运行容器  
    - 参数 `--name` : 设置容器名称  
    - 参数 `-p` : 映射端口（主机端口:容器端口）  

- 列出所有容器（已创建、已退出、正在运行等）：  
    ```sh
    podman ps -a
    ```

- 查看所有容器消耗的实时资源：  
    ```sh
    podman stats
    ```

- 查看容器日志：  
    ```sh
    podman logs -l
    ```
    - 参数 `-l` 指定最新创建的容器，也可以使用容器 ID 或容器名称指定其他容器  
    - 命令 `logs` 后添加参数 `-f` 可以实时查看容器输出日志  

- 查看容器内进程：  
    ```sh
    podman top -l
    ```

- 停止/启动/重启 容器：  
    ```sh
    podman stop -l      # 停止容器
    podman start -l     # 启动容器
    podman restart -l   # 重启容器
    ```

- 删除容器：  
    ```sh
    podman rm -l
    ```
    > 命令 `rm` 后添加参数 `-f` 可以强制删除正在运行的容器  

- 删除所有已停止的容器：  
    ```sh
    podman container prune
    ```


## 命名卷管理

- 创建命名卷：  
    ```sh
    podman volume create my_data
    ```

- 列出所有本地命名卷：  
    ```sh
    podman volume ls
    ```

- 查看命名卷所在路径：  
    ```sh
    podman volume inspect my_data
    ```

- 删除命名卷：  
    ```sh
    podman volume rm my_data
    ```

- 删除所有未被使用的命名卷：  
    ```sh
    podman volume prune
    ```

- 运行容器时指定命名卷：  
    ```sh
    # 将命名卷 my_data 挂载到容器内的 /app/data 目录
    podman run -d \
      --name app_server \
      -v my_data:/app/data \
      nginx
    ```
    > 如果参数 `-v` 后以 `/` 、 `./` 、 `../` 等路径开头则使用本地目录，否则使用命名卷  
    > 例如： `./my_data` 使用本地目录， `my_data` 使用命名卷  

- 导出命名卷为 tar 包：  
    ```sh
    podman volume export my_data --output my_data_backup.tar
    ```

- 从 tar 包导入命名卷：  
    ```sh
    podman volume import new_data_volume my_data_backup.tar
    ```


## Quadlet 容器管理

- 默认 Quadlet 文件存放位置：  
    - Rootless 模式： `~/.config/containers/systemd/`  
    - Root 模式： `/etc/containers/systemd/`  

- 编写一个 `.container` 文件，文件名称为 `my-web.container` ：  
    ```sh
    [Unit]
    Description=Production Nginx Web Service
    # 确保网络在线后再启动容器
    Wants=network-online.target
    After=network-online.target
    # 也可以在这里添加对其他容器服务的依赖（例如数据库）
    # After=container-mysql.service

    [Container]
    # 镜像：推荐使用带具体版本的镜像，避免 latest 带来的不确定性
    Image=docker.io/library/nginx:1.25-alpine

    # 容器名称：方便在 podman ps 中查看
    ContainerName=nginx-prod-server

    # 端口映射：主机 80 映射容器 80
    # 如果是 Rootless 模式，主机端口建议 > 1024 (如 8080)
    PublishPort=80:80

    # 数据卷挂载：使用 :Z 自动处理 SELinux 标签
    # 建议将配置文件和网页数据分开挂载
    Volume=/srv/nginx/html:/usr/share/nginx/html:Z
    Volume=/srv/nginx/conf.d:/etc/nginx/conf.d:Z

    # 权限管理：在 Rootless 模式下，保持主机用户 ID 映射到容器内
    # 这能有效解决挂载卷后的权限拒绝问题
    UserNS=keep-id

    # 环境变量
    Environment=TZ=Asia/Shanghai

    # 自动更新：允许通过 podman auto-update 更新此镜像
    AutoUpdate=registry

    # 健康检查：确保容器内部服务真正可用
    HealthCmd=curl -f http://localhost/ || exit 1
    HealthInterval=30s
    HealthRetries=3

    [Service]
    # 重启策略：非正常退出时始终重启
    Restart=always
    # 停止容器的超时时间
    TimeoutStopSec=30

    # 资源限制
    MemoryMax=256M

    [Install]
    # 允许随系统或用户登录自动启动
    WantedBy=default.target multi-user.target
    ```

- 使 `.container` 文件生效：  
    ```sh
    # 1. 重新加载 Systemd 管理器
    systemctl --user daemon-reload

    # 2. 启动服务（服务名：文件名 + .service）
    systemctl --user start my-web.service

    # 3. 设置开机自启
    systemctl --user enable my-web.service

    # 4. 检查状态
    systemctl --user status my-web.service
    ```

- 设置 Linger 状态 (Rootless 模式) ：  
    ```sh
    # 允许普通用户在没有登录时也能运行进程
    loginctl enable-linger <用户名>
    ```

> Quadlet 需要 Podman 版本大于等于 4.4  


## 其他配置

- 生成容器创建命令：  
    ```sh
    # 查看重建该容器所需的完整命令
    podman container inspect --format "{{.generate_command}}" <id>
    ```

- 设置镜像加速：  
    ```sh
    # 全局配置文件： /etc/containers/registries.conf
    # 用户配置文件： ~/.config/containers/registries.conf
    # 示例：添加镜像加速器
    unqualified-search-registries = ["docker.io", "quay.io"]

    [[registry]]
    prefix = "docker.io"
    location = "your-mirror-address.com"
    ```

- 镜像自动更新：  
    ```sh
    # 运行此命令即可拉取新镜像并重启相关服务
    podman auto-update

    # 查看哪些容器有更新可用（不立即更新）
    podman auto-update --dry-run
    ```

- Pod 容器组：  
    ```sh
    # 创建一个 Pod
    podman pod create --name my-stack -p 8080:80

    # 将两个容器塞进同一个 Pod
    # 它们在 Pod 内部通过 localhost 即可互相访问，非常高效
    podman run -d --pod my-stack --name db redis
    podman run -d --pod my-stack --name app my-app
    ```

- 一键系统清理：  
    ```sh
    # 删除所有停止的容器、未使用的卷、未使用的网络和虚悬镜像
    podman system prune -f
    ```

