# OCS 刷客代理 - 自动答题服务

配合 OCS 插件使用的自动答题代理服务，支持对接 **DeepSeek 网页版** 和 **本地 Ollama** 两种后端。

---

## 功能

- 自动解析题目并调用 AI 获取答案
- 支持 DeepSeek 网页版（通过 Playwright 自动化浏览器）
- 支持本地 Ollama 模型
- 在线查看日志和切换后端模式
- 一键启动，即开即用

---

## 环境要求

- **Windows 10/11**
- **Microsoft Edge 浏览器**（已安装）
- **Python 3.10+**（如无可从下方下载）

> 如果使用 DeepSeek 后端，需要拥有 DeepSeek 网页版账号并已登录。

---

## 快速开始

### 1. 下载项目

```bash
git clone https://github.com/guanxi-513/ocsshuakedaili.git
cd ocsshuakedaili
```

### 2. 安装依赖

```bash
pip install playwright
playwright install chromium
```

> 如果安装慢，可以使用国内镜像：
> ```bash
> pip install playwright -i https://pypi.tuna.tsinghua.edu.cn/simple
> playwright install chromium
> ```

### 3. 登录 DeepSeek（首次使用）

首次使用 DeepSeek 后端需要先登录账号：

1. 打开 `d:\appppp\ocs\edge_profile` 目录（如果没有，会自动创建）
2. 手动启动 Edge 浏览器并登录 DeepSeek：
   ```bash
   "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" --user-data-dir="d:\appppp\ocs\edge_profile" --no-first-run
   ```
3. 在打开的浏览器中访问 `https://chat.deepseek.com` 并登录你的账号
4. 登录成功后关闭浏览器

### 4. 启动服务

双击 **`start.bat** 或在命令行运行：

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

在 OCS 插件中添加题库配置：

| 字段 | 值 |
|------|-----|
| **名称** | AI 自动答题 |
| **URL** | `http://localhost:8080/search?title=${title}&type=${type}&options=${options}` |
| **方法** | `GET` |
| **内容类型** | `json` |
| **Handler** | `return (res)=> [undefined, res[1]]` |
| **类型** | `GM_xmlhttpRequest` |

也可以从 URL 自动加载配置：
```
http://localhost:8080/config
```

---

## 接口说明

### 答题接口

```
GET /search?title={题目}&type={题型}&options={选项}
```

返回格式：
```json
[null, "答案"]
```

### 查看日志

```
http://localhost:8080/logs
```

### 切换后端

```
http://localhost:8080/set_mode?mode=deepseek   # 切换为 DeepSeek
http://localhost:8080/set_mode?mode=ollama     # 切换为 Ollama
```

### 查看状态

```
http://localhost:8080/status
```

---

## 使用 Ollama 后端

如果你有本地 Ollama 模型，也可以使用 Ollama 作为后端：

1. 确保 Ollama 已安装并运行
2. 打开 `http://localhost:8080/set_mode?mode=ollama` 切换模式
3. 默认使用 `qwen2.5:7b` 模型，可在 `app.py` 中修改 `MODEL_NAME`

---

## 项目结构

```
ocsshuakedaili/
├── app.py                  # 主服务器程序
├── deepseek_backend.py     # DeepSeek 后端（持久会话模式）
├── _deepseek_worker.py     # DeepSeek 工作进程（备用独立进程模式）
├── start.bat              # 启动脚本
├── 题库配置.json           # OCS 插件配置示例
├── edge_profile/          # Edge 浏览器用户数据（登录态）
└── README.md              # 本文件
```

---

## 常见问题

**Q: 启动后访问接口超时？**
A: 首次启动时 Playwright 需要加载浏览器，请等待 15-30 秒。后续请求会很快。

**Q: DeepSeek 返回答案错误？**
A: 可以在题目中加更明确的说明，如"请直接给出答案字母，不要解释"。

**Q: 如何切换回同一个对话窗口？**
A: 默认每次刷新页面开新对话。如需复用同一对话，可修改 `deepseek_backend.py` 中的 `_do_ask` 函数，去掉 `page.reload()` 即可。

**Q: 端口被占用？**
A: 修改 `app.py` 中的 `PORT` 变量（默认 8080）。