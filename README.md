# OCS AI 答题助手

配合 OCS（答题辅助插件）使用的自动答题代理服务，启动后在你本地运行一个 HTTP 服务，自动调用 AI 帮你答题。

支持 **DeepSeek 网页版**（通过浏览器自动化）和 **本地 Ollama** 两种后端，切换自如。

***

## 功能

- 自动解析题目，调用 AI 获取答案

- DeepSeek 网页版后端（无需 API Key，有账号即可）

- 本地 Ollama 后端（支持任何 Ollama 模型）

- 实时查看日志，随时切换后端模式

- 即开即用，一键启动

***

## 环境要求

- **Windows 10/11**

- **Microsoft Edge 浏览器**（系统自带）

- **Python 3.10+**（[点击下载](https://www.python.org/downloads/)）

> 使用 DeepSeek 后端需要拥有 [DeepSeek 网页版](https://chat.deepseek.com) 账号并已登录。

***

## 快速开始

### 1. 下载项目

```bash
git clone https://github.com/guanxi-513/ocsshuakedaili.git
cd ocsshuakedaili
```

或者直接点击页面上的 **Code → Download ZIP**，解压到任意文件夹。

### 2. 安装依赖

```bash
pip install playwright
playwright install chromium
```

如果安装慢，使用国内镜像：

```bash
pip install playwright -i https://pypi.tuna.tsinghua.edu.cn/simple
playwright install chromium
```

### 3. 登录 DeepSeek（首次使用）

首次使用需要先让程序保存你的登录态：

1. 在项目目录下打开命令行，运行以下命令启动 Edge 浏览器：

   ```bash
   "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --user-data-dir="项目完整路径\edge_profile" --no-first-run
   ```

   > 将 `项目完整路径` 替换为你下载的项目文件夹路径，例如 `D:\ocsshuakedaili`
2. 浏览器打开后，访问 `https://chat.deepseek.com` 并登录你的账号
3. 登录成功后关闭浏览器即可

> 这一步只需要做一次，之后 `edge_profile` 文件夹会保存你的登录状态。

### 4. 启动服务

**方式一：双击** **`start.bat`（推荐）**

**方式二：命令行运行**

```bash
python app.py
```

看到以下输出表示启动成功：

```
服务器已启动: http://localhost:8080
[worker] 启动...
[worker] 就绪
```

### 5. 配置 OCS 插件

在 OCS 插件中添加题库配置，填写以下参数：

| 参数       | 值                                                                             |
| -------- | ----------------------------------------------------------------------------- |
| **名称**   | AI 自动答题                                                                       |
| **请求地址** | `http://localhost:8080/search?title=${title}&type=${type}&options=${options}` |
| **请求方式** | `GET`                                                                         |
| **返回类型** | `json`                                                                        |
| **处理函数** | `return (res)=> [undefined, res[1]]`                                          |
| **请求库**  | `GM_xmlhttpRequest`                                                           |

也可以使用自动加载配置，在 OCS 中填入：

```
http://localhost:8080/config
```

***

## 接口说明

### 答题接口

```
GET /search?title={题目}&type={题型}&options={选项}
```

参数说明：

- `title` - 题目内容（URL 编码）

- `type` - 题型：single(单选)、multi(多选)、judge(判断)

- `options` - 选项，用换行符 `\n` 分隔

返回格式：

```json
[null, "答案"]
```

### 其他接口

| 接口                                             | 说明              |
| ---------------------------------------------- | --------------- |
| `http://localhost:8080/logs`                   | 查看实时日志          |
| `http://localhost:8080/status`                 | 查看当前服务状态        |
| `http://localhost:8080/config`                 | 获取 OCS 插件配置     |
| `http://localhost:8080/set_mode?mode=deepseek` | 切换为 DeepSeek 后端 |
| `http://localhost:8080/set_mode?mode=ollama`   | 切换为 Ollama 后端   |

***

## 使用 Ollama 后端

如果你有本地 Ollama 模型，也可以切换为 Ollama 后端：

1. 确保 Ollama 已安装并正在运行
2. 访问 `http://localhost:8080/set_mode?mode=ollama` 切换模式
3. 默认使用 `qwen2.5:7b` 模型，如需修改，编辑 `app.py` 中的 `MODEL_NAME` 变量

***

## 项目结构

```
ocsshuakedaili/
├── app.py                   # 主服务器程序（入口）
├── deepseek_backend.py      # DeepSeek 后端
├── _deepseek_worker.py      # DeepSeek 工作进程
├── start.bat                # 一键启动脚本
├── 题库配置.json            # OCS 插件配置示例
├── edge_profile/            # 浏览器登录数据（首次登录后自动生成）
└── README.md                # 本文件
```

***

## 常见问题

**Q: 启动后请求超时？**

首次启动需要加载浏览器，等待 15-30 秒即可。如果仍然超时，检查 Edge 浏览器是否已登录 DeepSeek 账号。

**Q: 答案不对怎么办？**

可以在题目中增加提示词，例如"请直接给出答案选项字母，不要解释"。如果问题较难，可以尝试切换为 Ollama 后端使用更强的模型。

**Q: 端口被占用了？**

找到 `app.py` 文件，将开头的 `PORT = 8080` 改为其他端口（如 8081），重启服务即可。

**Q: 如何更新程序？**

```bash
git pull
```

如果直接下载的 ZIP，重新下载覆盖即可。

**Q: 这个会封号吗？**

DeepSeek 官方目前允许网页版正常使用，本项目仅模拟浏览器操作，频率与手动使用一致。建议合理使用，不要高频请求。
