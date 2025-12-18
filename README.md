# Caddycus

基于 [xcaddy](https://github.com/caddyserver/xcaddy) 自动构建带自定义插件的 Caddy Docker 镜像。通过 GitHub Actions 实现自动化版本检查、构建和发布。

## 📦 项目特点

- **🔄 自动更新** - 每日检查 Caddy 和插件更新，自动触发构建
- **🔌 灵活插件** - 通过简单文本文件管理插件列表
- **🏷️ 版本追踪** - 精确追踪 Caddy 版本和所有插件的 commit
- **📋 版本透明** - 镜像描述包含完整版本信息
- **🚀 多标签** - 提供 latest、版本号、版本+指纹等多种标签

## 🔧 自定义插件

### 修改插件列表

编辑 [`plugins.txt`](plugins.txt) 文件，每行一个插件的 GitHub 路径：

```text
# Cloudflare DNS 验证
github.com/caddy-dns/cloudflare

# Cloudflare IP
github.com/WeidiDeng/caddy-cloudflare-ip

# 添加更多插件...
# github.com/xxx/xxx
```

- 支持 `#` 开头的注释
- 支持空行
- 插件路径格式：`github.com/owner/repo`

### 应用更改

修改 `plugins.txt` 后：

1. **方式 1：自动构建**
   - 提交并推送到 `main` 分支
   - 下次自动检查（每日 00:00 UTC）会检测到变化并触发构建

2. **方式 2：手动触发**
   - 前往仓库的 [Actions](../../actions) 页面
   - 选择 `Check Version` workflow
   - 点击 `Run workflow` → `Run workflow`
   - 检测到变化后会自动触发构建

## 🚀 使用方法

### 拉取镜像

> 可从项目的[Packages](../../pkgs/container/caddycus)中查看所有构建镜像

```bash
# 使用 latest（始终指向最新构建）
docker pull ghcr.io/<YourUsername>/caddycus:latest

# 推荐：使用完整版本标签（Caddy 版本 + 插件指纹）
docker pull ghcr.io/<YourUsername>/caddycus:v2.10.2-bff7357aaa86e68e

# 或使用 Caddy 版本号（注意：插件版本可能不同）
docker pull ghcr.io/<YourUsername>/caddycus:v2.10.2
```

**标签说明**：
- `latest` - 最新构建（可能随时更新）
- `v2.10.2` - Caddy 版本号（插件可能有多个版本）
- `v2.10.2-bff7357aaa86e68e` - **Caddy 版本 + 插件指纹**（推荐生产环境使用，精确锁定版本）
- `a1b2c3d` - Git commit SHA

### 运行容器

```bash
docker run -d \
  --name caddy \
  -p 80:80 \
  -p 443:443 \
  -p 443:443/udp \
  -v $PWD/Caddyfile:/etc/caddy/Caddyfile \
  -v caddy_data:/data \
  -v caddy_config:/config \
  ghcr.io/<YourUsername>/caddycus:latest
```

### 使用 Docker Compose

```yaml
version: '3.8'

services:
  caddy:
    image: ghcr.io/<YourUsername>/caddycus:latest
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - caddy_data:/data
      - caddy_config:/config
    restart: unless-stopped

volumes:
  caddy_data:
  caddy_config:
```

## 📅 自动更新机制

### 版本追踪

项目使用 [`.cache-version`](.cache-version) 文件追踪当前构建版本：

```
caddy@v2.10.2
github.com/caddy-dns/cloudflare@6dc1fbb
github.com/WeidiDeng/caddy-cloudflare-ip@f53b62a
```

每行记录一个组件和其对应的版本/commit SHA。

### 自动检查

- **触发时间**：每天 UTC 00:00（北京时间 08:00）
- **检查内容**：
  - ✅ Caddy 是否有新版本发布
  - ✅ 所有插件是否有新 commit
  - ✅ `plugins.txt` 是否有变化

- **触发条件**：满足**任意一项**即触发重新构建

### 工作流程

```
定时任务 → 检查版本 → 计算指纹 → 对比差异 → 触发构建 → 推送镜像 → 更新版本文件
```

## 🏗️ 构建产物

### 镜像仓库

所有构建的镜像发布到：
- **GitHub Container Registry**: `ghcr.io/<YourUsername>/caddycus`
- **包页面**: [github.com/\<YourUsername\>/caddycus/pkgs/container/caddycus](../../pkgs/container/caddycus)

