# CustomerService

面向电商售前、订单查询与售后处理的智能客服项目。以 FastAPI 提供聊天和管理接口，以 LangGraph 编排多轮对话、知识检索、业务工具和人工确认流程，配有知识库维护、质量评估、问题复核与主题分类后台。

## 功能

- **多轮客服**：SSE 流式回复、会话持久化、指代消解、意图分流、滑动窗口与异步摘要。
- **业务处理**：订单与物流查询、退款政策判断、订单选择、工单确认及转人工入口。
- **知识问答**：文档切块、MySQL 与 Milvus 双写、向量与 BM25 混合检索、RRF 融合、重排和引用展示。
- **质量闭环**：证据置信度判断、低置信问题收集、同义问题归并、人工审核补库、检索评估与成本统计。
- **主题分析**：17 类多标签分类器，包含语料处理、训练、评测、ONNX 导出、独立推理服务和批量归类。

订单、物流和部分售后数据由项目内的模拟业务模块提供；退款申请创建工单，不会向支付平台执行真实退款。聊天、嵌入和重排需要自行配置可用的上游接口。

## 技术栈

Python 3.12+、FastAPI、LangGraph / LangChain、SQLAlchemy、MySQL、Milvus、MCP。前端采用 HTML、CSS 和 JavaScript；Langfuse 观测栈与主题分类器按需启用。

## 启动

准备 uv、Docker Compose、Bash 和 GNU Make。Windows 推荐在 WSL 中执行完整流程；原生 PowerShell 的手动启动方式见 [部署文档](DEPLOY.md)。

```bash
uv sync --locked
cp .env.example .env
# 编辑 .env，填写 CHAT_*、EMBED_*、RERANK_* 配置
docker compose up -d
docker compose ps
```

待 MySQL 和 Milvus 健康检查通过后，构建知识库并启动应用：

```bash
make kb-build
make kb-vectorize
make dev
```

空 MySQL 数据卷首次启动时，容器依次执行 `sql/001_schema.sql` 和 `sql/002_seed.sql`，创建完整表结构并装载样例数据。已有数据卷不会自动重新初始化。

打开 [聊天页](http://localhost:8000) 或 [管理后台](http://localhost:8000/admin)。可先发送“订单 1001 的物流到哪了”，检查回答与工具调用结果。安装步骤、配置和故障排查见 [DEPLOY.md](DEPLOY.md)。

## 项目结构

| 目录 | 内容 |
| --- | --- |
| `app/api/` | 聊天、业务动作、知识库、审核、统计和后台作业接口 |
| `app/graph/` | 对话状态、节点、路由与运行时 |
| `app/core/` | 模型调用、检索、意图、上下文、质量控制与观测 |
| `app/tools/` | 工具注册、参数校验、执行引擎与 MCP 客户端 |
| `app/kb/` | 文档解析、切块、双写、知识提取和去重 |
| `app/db/` | 数据模型和仓储 |
| `app/static/` | 聊天页面与管理界面 |
| `mcp_servers/` | 物流和售后 MCP 服务 |
| `sql/` | 统一建表脚本和样例数据脚本 |
| `scripts/` | 知识库维护、评估与运维脚本 |
| `scripts/topic_classifier/` | 分类器的数据、训练、导出和推理流程 |
| `data/kb/` | 业务知识文档 |
| `tests/` | 单元测试与服务集成测试 |

## 常用命令

| 命令 | 用途 |
| --- | --- |
| `make help` | 查看带说明的命令 |
| `make test` | 运行测试，需要独立 MySQL 测试库和 Milvus |
| `make kb-preview` | 查看本地知识文档与切块结果 |
| `make kb-repatch` / `make kb-vectorize` | 更新知识文档改动并重新向量化 |
| `make eval-rag` | 对比向量、BM25、混合检索、混合重排四种策略 |
| `make eval-workflow` / `make eval-intent-workflow` | 评估对话编排与意图分流 |
| `make eval-context` / `make eval-tools` | 评估上下文处理与工具流程 |
| `make flywheel` / `make eval-flywheel` | 问题归并与质量趋势评估 |
| `make langfuse-up` / `make cost-report` | 启动观测栈并生成成本报告 |
| `make classifier-corpus` / `make classifier-train` | 准备分类语料并训练模型 |
| `make classifier-eval` / `make classifier-export` | 评测分类器并导出 ONNX |

在线评估调用实际模型服务；训练与导出需要 `ml` 依赖组及本地数据产物。报告、数据集和模型在本地生成，不随源码分发。

## 页面与服务

| 地址 / 端口 | 用途 |
| --- | --- |
| `/`、`/admin` | 聊天和后台首页 |
| `/kb`、`/review` | 知识库管理与问题复核 |
| `/rag-eval`、`/observability` | 检索评估与观测成本 |
| `/topics`、`/topics/questions` | 主题分布与分类问题列表 |
| `/acceptance` | 分类器产物、评测和运行状态 |
| `/docs` | FastAPI 接口文档 |
| `8000` | 主应用 |
| `8101` / `8102` | 物流 / 售后 MCP |
| `8110` / `3000` | 可选分类器 / Langfuse |
| `3306` / `19530` | MySQL / Milvus |

默认配置面向本地开发；管理后台未实现完整身份认证，公网部署需配置认证、访问控制与独立凭据。
