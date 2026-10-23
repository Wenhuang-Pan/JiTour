---
name: flutter-service-test-scaffold
description: 为「记途」Flutter 项目的服务层生成符合项目规范的单元测试脚手架。当用户要求为 lib/services/ 下的服务编写或补充单测时使用。不适用于 Widget 测试、集成测试或非本项目代码。
---

# Flutter 服务层单测脚手架

为「记途」项目（Flutter + Provider + Hive + Decimal）的服务层代码生成单元测试。本 skill 固化了本项目服务层单测的固定模式，避免每次重复搭建 Hive 环境。

## 适用范围

- `lib/services/` 下的 Service 类（如 `account_service.dart`、`pending_transaction_service.dart`）
- 依赖 Hive box 且通过 `DatabaseService` 统一管理的服务
- 涉及金额计算（`Decimal`）、状态机、幂等逻辑的服务

不适用于：Widget 测试、集成测试、非本项目代码。

## 执行流程

1. **阅读目标服务源码**，列出所有 `public` 方法及核心副作用（读写哪些 box、是否联动账户余额、是否调用原生 channel）
2. **确认 box 名称**（见下方对照表），在 `setUp` 中 `clear` 所有相关 box
3. **套用模板**：从 `assets/service_test_template.dart` 复制基础结构，填入业务测试用例
4. **运行单测**：`flutter test test/<service>_test.dart`，根据实际行为修正期望
5. **全量验证**：`flutter analyze` + `flutter test`，确保 0 issue、全通过

## 关键约束（必须遵守）

- 测试文件放 `test/`，命名 `<service_name>_test.dart`（snake_case）
- 文件开头必须 `TestWidgetsFlutterBinding.ensureInitialized()`（服务可能通过 MethodChannel 调用原生，如 `CategoryInferenceService.learn`）
- Hive 初始化用临时目录：`Directory.systemTemp.createTemp('hive_xxx_')`，`tearDown` 中 `Hive.close()` + 删除临时目录
- 金额统一用 `Decimal.parse('...')`，禁止 `double` 字面量直接断言
- 中文注释，关键逻辑附 `// WHY: ...`
- 局部辅助函数禁止下划线开头（lint `no_leading_underscores_for_local_identifiers`）
- 禁止 `dynamic`，泛型显式声明

## 常用 Hive Box 名称对照表

| 业务实体 | 访问方式 |
|---------|---------|
| 正式交易 | `DatabaseService.transactions` |
| 待确认交易 | `DatabaseService.pendingTransactions` |
| 定期交易 | `DatabaseService.recurringTransactions` |
| 商户-分类学习表 | `DatabaseService.merchantCategoryMap` |
| 账户 | `AccountService.box` |
| 分类 | `CategoryService.box` |
| 标签 | `TagService.box` |

> 写测试前先 `Grep` 目标服务中的 `DatabaseService.` 和 `*.box` 调用，确认它实际依赖哪些 box。

## 常见测试模式

### 幂等性测试
对"执行"类操作（confirm、execute），连续调用两次，断言第二次返回 `null` 或不产生副作用（余额不变、交易数不增）。

### 余额联动测试
先 `AccountService.createAccount` 建账户，执行操作后用 `AccountService.getAccountByName` 取余额断言 `Decimal` 差值。

### 状态机测试
覆盖所有状态分支：pending → confirmed / discarded / ignored，以及非法状态转换的保护。

### 空输入边界
null、空字符串、空集合、`Decimal.zero` 等边界值必须有对应用例。

## 模板文件

基础脚手架模板见 [assets/service_test_template.dart](assets/service_test_template.dart)，复制后按需裁剪 `setUp` 中清理的 box。
