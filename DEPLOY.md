# CustomerService 部署与运行

本文覆盖本地运行、服务配置和验证。GitHub 仓库保存源码；应用需要在具备 Python 与依赖服务的主机运行。

## 环境与配置

需要 Python 3.12+、uv、Docker Compose、Bash / GNU Make，以及可用的聊天、嵌入和重排服务。完整流程推荐 Linux、macOS 或 Windows WSL。原生 Windows 可手动启动主应用；后台作业的启动和停止依赖 Make、Bash 与 Unix 进程组。

在项目根目录执行：

```bash
uv sync --locked
cp .env.example .env
```

PowerShell 复制文件使用 `Copy-Item .env.example .env`。编辑 `.env`：

| 变量 | 含义 |
| --- | --- |
| `CHAT_BASE_URL` | 聊天服务的 OpenAI 兼容地址 |
| `CHAT_MODEL` | 上游真实模型名，需要工具调用能力 |
| `CHAT_API_KEY` | 聊天服务凭据 |
| `EMBED_BASE_URL` / `EMBED_API_KEY` | 嵌入服务地址与凭据 |
| `RERANK_BASE_URL` / `RERANK_API_KEY` | 重排服务地址与凭据 |
| `DATABASE_URL` | 应用 MySQL 连接串，默认库 `CustomerService` |
| `TEST_DATABASE_URL` | 专用测试库，默认 `CustomerService_test` |
| `MCP_LOGISTICS_URL` / `MCP_AFTERSALES_URL` | 两个业务 MCP 地址 |

聊天、嵌入和重排分别连接对应服务。重排使用 `/rerank` 形式，不能替换成只支持聊天的接口；思考相关参数是否生效取决于上游模型。`.env` 及本地运行产物由 `.gitignore` 排除。

## 数据服务和初始化

```bash
docker compose up -d
docker compose ps
```

等待 MySQL 与 Milvus 健康检查通过。Milvus 使用 Standalone 部署，etcd 和 MinIO 是其依赖。

| 文件 | 用途 |
| --- | --- |
| `sql/001_schema.sql` | 完整业务表、索引、约束与最终字段定义 |
| `sql/002_seed.sql` | FAQ 和历史会话样例 |

空 MySQL 数据卷首次启动时自动按序执行两份 SQL。已有数据卷不会重新初始化；`001_schema.sql` 用于新库，不能代替任意旧数据库的升级迁移。旧库变更应先备份并核对实际结构。

手动初始化入口为 `make init-db`。重灌样例使用 `make seed`，会替换相应样例记录；`make seed-conv` 从同一 SQL 文件中仅执行历史会话部分。执行前确认数据库与样例记录符合预期。

检查 FAQ：

```bash
docker compose exec -T mysql mysql --default-character-set=utf8mb4 -uroot -proot CustomerService -e "SELECT COUNT(*) FROM faq;"
```

订单与物流由 `app/tools/business.py` 按用户标识生成模拟数据，无需 orders 表。默认提供订单 1001 和 2002；退款提交记录为工单。

## 建立知识库

```bash
make kb-preview
make kb-build
make kb-vectorize
```

`kb-build` 将 `data/kb/` 文档切块写入 MySQL，`kb-vectorize` 调用嵌入服务并 upsert 到 Milvus，成功后回写状态。源文档修改后使用 `make kb-repatch` 再向量化。`make kb-reset` 会清空知识相关表和向量集合，只用于明确需要重建的环境。

## 启动应用

Bash / WSL 中执行：

```bash
make dev
```

该命令启动依赖容器、等待 Milvus，并启动物流 MCP（8101）、售后 MCP（8102）和主应用（8000）。主应用以前台方式运行；结束后可用 `make dev-down` 清理应用与 MCP 进程。`docker compose stop` 停止依赖容器并保留数据卷。

原生 PowerShell 先启动 Docker 依赖，在每个 Python 终端设置：

```powershell
$env:PYTHONUTF8 = '1'
$env:PYTHONPATH = '.'
```

依次构建知识库：

```powershell
uv run python scripts/build_kb.py
uv run python scripts/vectorize_kb.py
```

然后在三个终端分别运行以下命令，保持进程运行：

```powershell
uv run python mcp_servers/logistics_server.py
```

```powershell
uv run python mcp_servers/aftersales_server.py
```

```powershell
uv run uvicorn app.main:app --port 8000
```

浏览器内作业管理仍建议使用 WSL 环境。

## 验证

打开 [聊天页](http://localhost:8000) 与 [后台](http://localhost:8000/admin)。发送“订单 1001 的物流到哪了”，检查工具调用包含 `query_order` 和 `query_logistics` 且结果有效。商品政策问题应带有知识引用，信息不足时应追问或兜底。

`POST /api/agent` 接受以下 JSON：

```json
{"user_id":"u1","message":"订单 1001 的物流到哪了"}
```

响应包含 `conversation_id`、`answer`、`tool_calls` 和 `tool_results`，需要交互时 `interrupt` 携带订单选择或工单确认信息。接口详情见 [OpenAPI 文档](http://localhost:8000/docs)。

完整测试前配置独立 `TEST_DATABASE_URL`，启动 MySQL 与 Milvus，再执行 `make test`。数据库 fixture 会重建测试表，不能指向应用数据库；模型调用在相关测试中使用替身，Milvus 集成测试会创建临时集合。在线评估命令需要真实上游及已向量化知识库。

## 可选观测

```bash
make langfuse-up
```

等待 [Langfuse](http://localhost:3000) 就绪，按命令输出与 `.env.example` 配置 `LANGFUSE_PUBLIC_KEY`、`LANGFUSE_SECRET_KEY`、`LANGFUSE_BASE_URL` 并重启主应用。三项齐全才启用回调，留空不影响主业务。

```bash
make cost-report
make calibrate-confidence
make eval-flywheel
```

报告生成在 `data/observability/reports/`，页面为 `/observability`。观测栈使用独立 Compose 项目 `customer-service-langfuse`。

## 可选分类器

```bash
make classifier-golden
make classifier-corpus
make classifier-dataset
make classifier-train
make classifier-eval
make classifier-export
make classifier-up
make classifier-threshold-scan
make classify-pool FORCE=1
```

先检查语料抽审文件及数据划分，再进行训练。相关命令按需安装 `ml` 依赖，首次还需下载基础模型。数据、权重、ONNX 和报告在 `data/topic_classifier/` 本地生成，不随源码分发。推理服务监听 8110，只用于离线问题归类。

`/acceptance` 展示数据、模型、评测与服务状态。产物缺失时提示生成入口，未运行评测不表示达到质量要求。训练和推理入口位于 `scripts/topic_classifier/`。

## 常见问题

| 现象 | 检查方向 |
| --- | --- |
| 配置字段缺失 | 当前目录是否为项目根目录，.env 是否填写完整 |
| MySQL 无法启动 | 3306 占用、镜像与数据卷版本兼容情况 |
| Milvus 不健康 | `docker compose logs milvus-standalone etcd minio` |
| 模型返回 401 / 404 | 接口地址、密钥、权限、模型名 |
| 知识问答没有结果 | 切块是否完成、pending 是否向量化、Milvus 是否可检索 |
| 工具调用异常 | 模型能力、MCP 服务及 `log/app.log` |
| 后台作业失败 | `log/acceptance/` 中的日志、Make/Bash 和任务依赖 |
| Windows 中文读取失败 | 在 Python 启动前设置 `PYTHONUTF8=1` |

默认配置面向本地单人开发。管理后台没有完整身份认证，Compose 包含本地默认凭据；公网部署需要认证、访问控制、独立凭据和持久化备份。
