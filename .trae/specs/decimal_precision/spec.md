# 规格：金额精度改造（double → Decimal）

## 问题

当前所有金额字段以 `double` 存储与运算。二进制浮点数存在精度误差（如 `0.1 + 0.2 = 0.30000000000000004`、多次累加后分位漂移），在优惠、手续费、余额累积等场景会导致账目对不上。作为记账软件这是立身之本的缺陷。

## 用户与目标

- **用户**：所有记账用户，尤其是频繁使用优惠/手续费、定期交易、自动记账的用户
- **目标**：所有金额运算使用十进制精确类型，消除浮点误差，存储、计算、显示全链路精度一致
- **非目标**：
  - 不改非金额的 double 字段：坐标（latitude/longitude）、利率（interestRate，百分比）、置信度（confidence，0-1）
  - 不引入多币种换算（currency 字段仅作标记保留）
  - 不改变用户可见的 UI 布局与交互（仅修正显示精度）

## 约束与依赖

- 依赖：`decimal: ^3.0.0`（pub.dev 主流包，基于 BigInt）
- 存储：Hive 2.x，金额字段序列化需自定义 `DecimalAdapter`（存 String）
- 数据安全：旧数据（double）必须零丢失迁移，升级后首启自动完成
- 项目规则：禁止 `dynamic`、泛型显式；Hive adapter 通过 build_runner 生成（金额字段兼容逻辑在生成后手动标注保留）
- 范围：11 个金额字段，分布在 7 个模型中
  - Transaction: amount, fee, coupon
  - Account: initialBalance, currentBalance
  - Budget: amount
  - SavingsGoal: targetAmount, currentAmount
  - Debt: totalAmount, paidAmount
  - RecurringTransaction: amount
  - PendingTransaction: amount

## 功能需求

### FR-1 数据模型与存储
- 金额字段类型由 `double` 改为 `Decimal`
- Hive 通过 `DecimalAdapter`（typeId 100）将 Decimal 序列化为 String 存储
- 反序列化兼容旧数据：读到 `double` 时转为 Decimal，读到 `String` 时 parse，读到 `int` 时 fromInt
- 旧数据惰性迁移：首次读取后触发 save 即转为 String 存储

### FR-2 金额运算
- 所有金额加、减、乘、除、比较改用 Decimal 运算符
- `clamp` 等 double 特有方法用 Decimal 比较实现
- 利率/百分比计算（利息、进度等）保留 double 作为比率输入，与 Decimal 相乘前 `Decimal.parse(rate.toString())` 或用 `Decimal.fromInt` + 除法

### FR-3 UI 显示与输入
- 金额显示统一用 `decimal.toStringAsFixed(2)` 或 NumberFormat（保留现有格式化工具）
- 输入仍走 `num`，提交时 `Decimal.parse(inputString)`
- 不引入新的输入控件

### FR-4 导入导出与 JSON
- CSV/TXT 导出：金额用 `toStringAsFixed(2)` 输出
- CSV 导入：解析为 `Decimal.parse`
- `toJson`/`fromJson`：金额转 String 输出 / String 解析

## 非功能需求

- 性能：Decimal 基于 BigInt，个人记账量级（千~万条）无感知
- 内存：略增，可忽略
- 构建：需重新运行 build_runner 并手动标注 .g.dart 金额兼容代码不可重新生成

## 验收标准

### AC-1（rule）旧数据零丢失迁移
升级后首次启动，所有历史账单、账户余额、预算、储蓄目标、负债、定期交易、待确认交易的金额与升级前数值一致（精度内），无崩溃、无 NaN、无数据缺失。

### AC-2（rule）金额运算无浮点误差
`0.1 + 0.2` 等于 `0.3`（精确）；多笔优惠/手续费累加后与总额完全相等；余额累积无分位漂移。通过单元测试验证至少 3 个边界用例。

### AC-3（rule）Hive 序列化往返一致
任一金额值存入 Hive 再读出，Decimal 值完全相等（`==` 为 true），精度不丢。

### AC-4（rule）全量编译通过
`flutter analyze` 0 error（既有 warning/info 不增加）；`flutter build apk --release` 成功。

### AC-5（rubric）UI 显示精度
维度：金额显示格式。0 分：出现浮点尾巴如 0.3000000004；1 分：两位小数显示正确但内部仍有误差；2 分：显示与内部均精确到分。阈值 ≥ 2。

### AC-6（rule）导入导出金额精度不变
导出 CSV 再导入，金额数值完全一致（字符串级相等）。
