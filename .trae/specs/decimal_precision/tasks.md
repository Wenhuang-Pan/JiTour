# 任务队列：金额精度改造

## Task 1: 基础设施 — decimal 依赖、DecimalAdapter、解析工具
- **Status**: pending
- **Priority**: high
- **AC 覆盖**: FR-1, AC-3
- **内容**:
  1. `pubspec.yaml` 添加 `decimal: ^3.0.0`，`flutter pub get`
  2. 新建 `lib/utils/decimal_util.dart`：
     - `Decimal parseDecimal(dynamic raw)`：兼容 double/int/String → Decimal（double 用 `Decimal.parse(raw.toString())` 保留精度，不直接 `Decimal.fromDouble`）
     - `String formatMoney(Decimal value)`：统一两位小数字符串
     - `class DecimalAdapter extends TypeAdapter<Decimal>`（typeId 100）：read 用 parseDecimal，write 用 `writer.write(obj.toString())`
  3. `DatabaseService.init()` 中注册 `DecimalAdapter`（`isAdapterRegistered` 检查）
- **TR（rule）**: `Decimal.parse('0.1') + Decimal.parse('0.2') == Decimal.parse('0.3')`
- **TR（rule）**: `parseDecimal(0.1) == Decimal.parse('0.1')`；`parseDecimal('10.50') == Decimal.fromInt(1050) ~/ Decimal.fromInt(100)`

## Task 2: 模型层 — 7 个模型金额字段改为 Decimal
- **Status**: pending
- **Priority**: high
- **Depends on**: Task 1
- **AC 覆盖**: FR-1, AC-1, AC-3
- **内容**（每个模型）:
  1. import `decimal` 与 `decimal_util`
  2. 金额字段 `double` → `Decimal`；默认值 `0.0` → `Decimal.zero`
  3. 构造参数、copyWith、getter/setter 同步改
  4. `toJson` 金额输出 `value.toString()`；`fromJson` 用 `parseDecimal(json[...])`
  5. 涉及模型：Transaction(amount/fee/coupon)、Account(initialBalance/currentBalance)、Budget(amount)、SavingsGoal(targetAmount/currentAmount)、Debt(totalAmount/paidAmount)、RecurringTransaction(amount)、PendingTransaction(amount)
  6. 非金额 double 保留：latitude/longitude、interestRate、confidence
- **TR（rule）**: 7 个模型编译通过；`flutter analyze` 模型目录 0 error

## Task 3: Hive 适配器 — build_runner + 旧数据兼容
- **Status**: pending
- **Priority**: high
- **Depends on**: Task 2
- **AC 覆盖**: AC-1, AC-3
- **内容**:
  1. `dart run build_runner build --delete-conflicting-outputs` 重新生成 7 个 .g.dart
  2. 逐个修改 .g.dart 金额字段的 read：`fields[N] as Decimal` → `parseDecimal(fields[N])`
  3. write 保持 `writer.write(obj.amount)`（DecimalAdapter 存 String）
  4. 每个 .g.dart 顶部加注释：`// 金额字段 read 已手动改为 parseDecimal 兼容旧 double 数据，勿重新 build_runner 覆盖`
- **TR（rule）**: 用旧 Hive 测试数据（double 金额）能正常读取且值正确；保存后再读仍正确
- **TR（rule）**: `flutter analyze` 0 error

## Task 4: Service 层 — 账户与余额
- **Status**: pending
- **Priority**: high
- **Depends on**: Task 3
- **AC 覆盖**: FR-2, AC-2
- **内容**: `account_service.dart`、`balance_migration_service.dart` 中金额运算改为 Decimal；余额加减、转账双边更新、补扣迁移
- **TR（rule）**: 账户存入 100.10，支出 0.10，余额精确等于 100.00

## Task 5: Service 层 — 交易、预算、统计
- **Status**: pending
- **Priority**: high
- **Depends on**: Task 3
- **AC 覆盖**: FR-2, AC-2
- **内容**: `filter_service.dart`(金额比较)、`stats_service.dart`(聚合)、`recurring_transaction_service.dart`(执行扣款)、`pending_transaction_service.dart`(confirm 扣款)、`savings_goal_service.dart`、`debt_service.dart`
- **TR（rule）**: 统计聚合多笔交易金额后无浮点误差；优惠 amount = 原价 - 优惠 + 手续费 精确

## Task 6: UI 层 — 金额显示（批量）
- **Status**: pending
- **Priority**: high
- **Depends on**: Task 4, Task 5
- **AC 覆盖**: FR-3, AC-5
- **内容**: 16 个 screen + 3 个 widget 中所有 `toStringAsFixed`、`clamp`、金额比较、`+/-` 运算改为 Decimal；显示用 `formatMoney` 或 `decimal.toStringAsFixed(2)`
  - 重点：home_screen, stats_screen, accounts_screen, budget_screen, add_transaction_screen, transfer_screen, savings_goals_screen, debt_screen, account_detail_screen, export_screen, pending_transactions_screen, recurring_transaction_screen
- **TR（rule）**: 所有金额显示为两位小数，无浮点尾巴
- **TR（rubric）**: UI 显示精度，阈值 2

## Task 7: 输入与导入导出
- **Status**: pending
- **Priority**: high
- **Depends on**: Task 6
- **AC 覆盖**: FR-3, FR-4, AC-6
- **内容**:
  - 记账/转账输入：`num` → `Decimal.parse(controller.text)`，校验非负
  - `export_service.dart`：金额输出 `toStringAsFixed(2)`
  - `csv_importer.dart`：金额解析 `Decimal.parse`
  - `backup_service.dart`：JSON 序列化金额用 String
- **TR（rule）**: 导出 CSV 再导入，金额字符串完全一致

## Task 8: 综合验证
- **Status**: pending
- **Priority**: high
- **Depends on**: Task 7
- **AC 覆盖**: AC-1 ~ AC-6
- **内容**:
  1. `flutter analyze` 0 error
  2. `flutter build apk --release` 成功
  3. 编写/运行金额精度单元测试（至少 3 个边界用例）
  4. 旧数据迁移验证：用已有 Hive 数据启动，核对金额
  5. 真机回归：记账、编辑、自动记账、定期交易、统计、导出导入
