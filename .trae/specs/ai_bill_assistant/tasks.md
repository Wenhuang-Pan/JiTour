# 任务：账单 AI 助手

## Task 1: API Key 配置服务与存储
- **Status**: completed
- **Completion Evidence**: ai_config_service.dart + settings_screen.dart 配置弹窗，flutter analyze 通过
- **Priority**: high
- **对应 AC**: AC-1, AC-4
- **实现内容**:
  - 新建 `lib/services/ai_config_service.dart`，封装 API Key 的读写（Hive box: `ai_config`）
  - 方法：`getApiKey()`、`setApiKey(String)`、`clearApiKey()`、`isConfigured()`
  - 设置页新增「AI 助手」入口项，点击进入配置弹窗（输入框 + 保存/清除按钮）
- **Test Requirements**:
  - TR-1.1（rule）：setApiKey 后 getApiKey 返回相同值
  - TR-1.2（rule）：clearApiKey 后 getApiKey 返回 null，isConfigured 返回 false
  - TR-1.3（rule）：未配置时 isConfigured 返回 false

## Task 2: AiAnalysisService 核心服务
- **Status**: completed
- **Completion Evidence**: ai_analysis_service.dart 实现完成；test/ai_analysis_service_test.dart 6 个测试全通过（含 MockClient 注入、401/5xx 异常、脱敏断言、模板差异断言）
- **Priority**: high
- **对应 AC**: AC-2, AC-3
- **实现内容**:
  - 新建 `lib/services/ai_analysis_service.dart`
  - `analyzeBill(String period, ...)` 方法：组装脱敏数据 + Prompt，调用智谱 API
  - API 端点：`https://open.bigmodel.cn/api/paas/v4/chat/completions`，模型 `glm-4-flash`
  - Headers: `Authorization: Bearer <apiKey>`, `Content-Type: application/json`
  - 数据脱敏：从 TransactionService 聚合分类汇总，不包含商户/账户
  - 异常处理：网络异常、401（Key 无效）、超时（30s）
- **Test Requirements**:
  - TR-2.1（rule）：mock http 返回成功响应时，返回 AI 文本
  - TR-2.2（rule）：mock http 返回 401 时，抛出明确异常
  - TR-2.3（rule）：发送的数据中不含商户名/账户名（检查 Prompt 内容）
  - TR-2.4（rule）：未配置 Key 时直接返回不发起请求

## Task 3: AI 分析 UI
- **Status**: completed
- **Completion Evidence**: ai_analysis_screen.dart（3 模板卡片 + 隐私提示 + 加载动画 + 错误容器 + SelectableText 结果）；stats_screen.dart AppBar 新增 AI 入口，未配置 Key 弹窗引导去设置页；flutter analyze 通过
- **Priority**: high
- **对应 AC**: AC-4, AC-6
- **实现内容**:
  - 统计页 AppBar 右上角新增「✨ AI」图标按钮
  - 新建 `lib/screens/ai_analysis_screen.dart`：
    - 3 个预设分析模板卡片（消费结构 / 异常支出 / 储蓄建议）
    - 点击模板后展示加载动画，返回后展示分析文本
    - 支持重新分析
  - 未配置 Key 时点击 AI 按钮，弹窗引导去设置页
- **Test Requirements**:
  - TR-3.1（rule）：未配置 Key 时点击 AI 按钮不发起请求，显示引导
  - TR-3.2（rubric）：加载状态有明确反馈（动画/文案），错误有 SnackBar 提示

## Task 4: 全量验证与文档
- **Status**: completed
- **Completion Evidence**: flutter analyze 0 issue；flutter test 215/215 通过；Obsidian 文档 `v3.4.1 - 开发日志.md` 已输出
- **Priority**: medium
- **对应 AC**: AC-5
- **实现内容**:
  - `flutter analyze` 0 issue
  - `flutter test` 全通过
  - 更新开发文档（Obsidian 路径）
- **Test Requirements**:
  - TR-4.1（rule）：flutter analyze 无 issue
  - TR-4.2（rule）：flutter test 全通过
