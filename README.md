# OCS AI 答题助手

配合 OCS（答题辅助插件）使用的自动答题代理服务，启动后在你本地运行一个 HTTP 服务，自动调用 AI 帮你答题。

支持 **DeepSeek 网页版**、**豆包网页版**、**本地 Ollama** 三种后端，切换自如；支持**多开**（每个实例独立端口），可在一台机器上跑多个答题服务。

***

## 功能

- 自动解析题目，调用 AI 获取答案
- 三种后端：
  - DeepSeek 网页版（无需 API Key，有账号即可）
  - 豆包网页版（需登录，免费）
  - 本地 Ollama（支持任何 Ollama 模型）
- 支持多开，每个实例可指定不同端口（8080/8081/8082...）
- 服务启动后自动生成 OCS 配置文件（`ocs_config.json`），自动探测本机 IP + 端口
- 实时查看日志，随时切换后端模式
- 即开即用，一键启动

***

## 环境要求

- **Windows 10/11**
- **Microsoft Edge 浏览器**（系统自带）
- **Python 3.8+**（[点击下载](https://www.python.org/downloads/)）

> 使用 DeepSeek/豆包后端需要拥有对应网页版账号并已登录。

***

## 快速开始

### 1. 下载项目

```bash
git clone https://github.com/guanxi-513/ocsshuakedaili.git
cd ocsshuakedaili
```

或者直接点击页面上的 **Code → Download ZIP**，解压到任意文件夹。

### 2. 启动服务

**双击 `start.bat`**，按提示操作即可：

```
[1/4] Python Path Setup...      ← 自动检测或手动输入 Python 路径
[2/4] Checking dependencies...  ← 缺失时自动安装 playwright/requests
[3/4] Choose answer backend:
    1 - DeepSeek Web
    2 - Ollama Local
    3 - Doubao Web

Enter service port (default 8080):   ← 多开时填不同端口
```

- 选 **1** → 自动检测 DeepSeek 登录状态，未登录会引导你登录
- 选 **2** → 自动检测 Ollama 是否运行，未运行会提示
- 选 **3** → 自动检测豆包登录状态，未登录会引导你登录
- 依赖缺失时会自动安装
- 多开时给每个实例填不同端口（如 8080、8081、8082）

### 3. 配置 OCS 插件

服务启动后，在项目目录会自动生成 **`ocs_config.json`**，里面已经填好本机所有 IP + 当前端口。

**方法一（推荐）：直接用生成的配置文件**

打开 `ocs_config.json`，挑一个能访问的地址（本机用 `localhost`，虚拟机/局域网用对应 IP），把对应的配置项填到 OCS 插件里。

**方法二：手动填写**

在 OCS 插件中添加题库配置：

| 参数       | 值                                                                                                      |
| -------- | ------------------------------------------------------------------------------------------------------ |
| **名称**   | AI 自动答题                                                                                                |
| **请求地址** | `http://<IP>:<端口>/search?title=${title}&type=${type}&options=${options}`                            |
| **请求方式** | `GET`                                                                                                  |
| **返回类型** | `json`                                                                                                 |
| **处理函数** | `return (res)=> [undefined, res[1]]`                                                                   |
| **请求库**  | `GM_xmlhttpRequest`（重要：用这个可跨域）                                                                    |

> `<IP>` 是运行服务那台机器的 IP（本机用 `localhost`），`<端口>` 是启动时填的端口（默认 8080）。

也可以使用自动加载配置，设置题库配置 URL 为：

```
http://<IP>:<端口>/config
```

***

## 多开说明

可以在同一台机器或多个虚拟机里，同时跑多个答题服务（每个用不同后端或不同题库）：

1. 每个实例打开 `start.bat`，启动时输入不同端口（如 `8080`、`8081`、`8082`）
2. 每个实例会自动生成对应端口的 `ocs_config.json`
3. OCS 里配置多个题库项，分别指向不同实例的端口

> 虚拟机里 OCS 访问主机服务时，`<IP>` 填主机的局域网 IP（虚拟机用桥接网络可互相访问）。

***

## 接口说明

### 答题接口

```
GET /search?title={题目}&type={题型}&options={选项}
```

参数说明：

- `title` - 题目内容（URL 编码）
- `type` - 题型：single(单选)、multiple(多选)、judgement(判断)、completion(填空)
- `options` - 选项，用换行符 `\n` 分隔

返回格式：

```json
[null, "答案"]
```

**多选题**答案用 `===` 分隔多个选项（如 `A===C`）。

### 其他接口

| 接口                                               | 说明              |
| ------------------------------------------------ | --------------- |
| `http://localhost:8080/logs`                     | 查看实时日志          |
| `http://localhost:8080/status`                   | 查看当前服务状态        |
| `http://localhost:8080/config`                   | 获取 OCS 插件配置     |
| `http://localhost:8080/set_mode?mode=deepseek`   | 切换到 DeepSeek 后端 |
| `http://localhost:8080/set_mode?mode=ollama`     | 切换到 Ollama 后端   |
| `http://localhost:8080/set_mode?mode=doubao`     | 切换到豆包后端         |

***

## 项目结构

```
ocsshuakedaili/
├── app.py                   # 主服务器程序（入口）
├── deepseek_backend.py      # DeepSeek 后端
├── doubao_backend.py        # 豆包后端
├── start.bat                # 一键启动脚本
├── 题库配置.json            # OCS 插件配置（单机版）
├── 题库配置_多开版.json      # OCS 插件配置（多端口示例）
├── ocs_config.json          # 启动后自动生成（含本机 IP + 端口）
├── edge_profile/            # 浏览器登录数据（首次登录后自动生成）
└── README.md                # 本文件
```

***

## 常见问题

**Q: 启动后请求超时？**

首次启动需要加载浏览器，等待 15-30 秒即可。如果仍然超时，检查 Edge 浏览器是否已登录对应 AI 账号。

**Q: 答案不对怎么办？**

程序会要求 AI 只输出答案字母（单选）或字母组合（多选）。如果某题仍不对，可能是 AI 知识问题，可尝试切换后端或模型。

**Q: 多开时提示端口被占用？**

每个实例必须用不同端口。启动时输入不同端口即可，默认 8080、8081、8082... 依次递开。

**Q: 虚拟机里 OCS 连不上主机服务？**

1. 检查网络：虚拟机与主机用**桥接网络**在同一网段，能互相 ping 通
2. OCS 里 `<IP>` 填**主机的局域网 IP**，不是 `localhost`
3. 主机防火墙放行对应端口

**Q: 如何更新程序？**

```bash
git pull
```

如果直接下载的 ZIP，重新下载覆盖即可。

**Q: 这个会封号吗？**

本项目仅模拟浏览器操作，频率与手动使用一致。建议合理使用，不要高频请求。