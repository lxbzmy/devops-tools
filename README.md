# DevOps 环境脚本集

一组面向 DevOps 环境准备与维护的脚本，聚焦离线场景与可重复操作。所有脚本均可独立使用。

## 脚本一览

| 脚本 | 作用 | 适用场景 |
| --- | --- | --- |
| [clean-m2-dirty.pl](clean-m2-dirty.pl) | 清理本地 Maven 仓库中的垃圾目录 | 构建环境长期使用后仓库膨胀 |
| [download-vscode-server.sh](download-vscode-server.sh) | 下载 vscode-server 与 CLI，生成离线安装包 | 离线或受限网络环境部署 VS Code Server |


## clean-m2-dirty.pl

### 目标与原理

清理本地 Maven 仓库（默认 `~/.m2/repository`）中无效目录。判定规则:

- 叶子目录没有 `.pom`，也没有 `.jar`/`.war`/`.zip`/`.gz`
- 非叶子目录的所有子目录都是垃圾目录且自身也缺少制品文件

### 运行流程

1. 递归扫描 Maven 仓库
2. 识别垃圾目录
3. 仅移动最顶层垃圾目录到临时目录
4. 使用 `find` 清理残留空目录

### 安全提示

- 建议先执行 `--dry-run` 查看影响范围
- 脚本不直接删除，但临时目录可能被系统清理
- 担心差错请先备份

## download-vscode-server.sh

### 目标与输入参数

用于下载 vscode-server 与 CLI 包，并生成离线安装脚本。

```
用法: ./download-vscode-server.sh <version> [server_os_arch] [cli_os_arch]
示例: ./download-vscode-server.sh 1.108.2 linux-x64 alpine-x64
```

参数说明:

- `version`: VS Code 版本号，脚本会解析为对应提交 ID
- `server_os_arch`: server 包目标平台，默认 `linux-x64`
- `cli_os_arch`: CLI 包目标平台，默认 `alpine-x64`

### 下载与文件布局

下载完成后，目录结构示例:

```
<commit_id>/
├── server-<os-arch>.tar.gz
├── cli-<os-arch>.tar.gz
└── install.sh
```

### 离线安装步骤

1. 将下载目录拷贝到目标机器
2. 进入提交 ID 目录，执行安装脚本

```bash
cd <commit_id>
./install.sh
```

3. 默认安装到 `~/.vscode-server`，也可指定目录:

```bash
./install.sh /custom/path/.vscode-server
```

### 常见问题

- 如果提示找不到匹配的压缩包，请确认下载的 OS/ARCH 与目标机器一致
- CLI 的 `alpine` 参数会自动转换为 `linux` 文件名以匹配安装逻辑

## 许可证

本项目采用 GNU Affero General Public License v3.0 (AGPL-3.0) 许可证。详见 [LICENSE](LICENSE)。
