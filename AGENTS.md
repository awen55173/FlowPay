# 项目编码约定

- 每个阶段使用 workflows/sN.py 独立文件，包含本阶段编排、提示词和专有状态；不继承或调用其他阶段的 run，只注册已实现阶段。
- workflows 只展示阶段编排、手写 Agent Loop、提示词与业务决策，通过类型明确的能力接口调用下层。
- workflows 不创建 SDK/数据库客户端，不实现 HTTP/SSE/SQL/文件读取、追踪落库、模型原生协议解析或样例工具。不得把整个检索阶段循环藏进下层实现。
- 通用能力及其实现放 core；发布文档导入、模拟服务与验收放 scripts；具体对象装配放 flowpay/bootstrap.py，阶段注册与选择放 flowpay/router.py。core 不依赖 workflows、router、bootstrap 或 scripts。
- 公共方法声明清楚输入和返回类型，动作使用有意义的动词。已知结构不要退回 dict[str, Any]；供应商扩展和阶段状态可保留 JSON 边界。
- __init__.py 仅作公共导出。先改善名称和结构，再写中文注释解释约束、原因、事务及取消行为；不以注释数量或短文件作为质量标准。
- 前端组件声明实际所需 props；事件解释集中在投影层，订阅、运行操作与本地草稿分别有明确所有者。
