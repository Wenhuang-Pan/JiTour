import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';
import '../models/account.dart';
import '../models/pending_transaction.dart';
import '../models/transaction.dart';
import 'account_service.dart';
import 'database_service.dart';

/// 账户余额历史补扣迁移服务（v2.3.0 一次性迁移）
///
/// WHY: v2.2.1 及更早版本中，自动记账 confirm 转正只落正式交易、不扣减账户余额，
/// 导致经该路径入账的支出未反映在账户余额上。v2.3.0 修复入账逻辑后，
/// 需对历史已确认记录做一次性精确补扣。
///
/// 迁移范围与安全性：
/// - 仅追溯 pending 表中 [PendingStatus.confirmed] 且关联正式交易仍存在、未软删除的记录；
/// - 自动记账固定为支出，按交易金额从对应账户（交易存账户名）补扣；
/// - 幂等：完成后在 autoAccountingPrefs 写入标志，正常情况下重复启动不会二次扣减；
/// - 金额先按账户聚合、校验通过后再统一保存，最大限度降低半截扣减概率；
///   若在账户保存阶段进程被强杀（极低概率），标志未写入会触发重跑，
///   已保存账户可能被重复扣减，需用户在账户页手动修正；
/// - 定期交易的历史执行记录无来源字段无法区分，不在本次迁移范围内。
class BalanceMigrationService {
  BalanceMigrationService._();

  /// 幂等标志存储 key
  static const String _migrationFlagKey = 'balance_migration_v230_done';

  /// 重置迁移完成标志
  ///
  /// WHY: 备份恢复（BackupService.restoreBackup）会把账户余额与交易整体替换为
  /// 备份时的快照，但不包含 pending 表与迁移标志。恢复旧版本备份后需重置标志，
  /// 让下次启动基于现存 pending 记录重新评估补扣；
  /// 关联交易已不存在的记录会在迁移中自动跳过，换机恢复场景同样安全。
  static Future<void> resetMigrationFlag() async {
    await DatabaseService.autoAccountingPrefs.delete(_migrationFlagKey);
  }

  /// 执行历史余额补扣迁移（已执行过则直接返回）
  ///
  /// @return 实际补扣的交易笔数；已迁移或无待处理记录返回 0
  static Future<int> runIfNeeded() async {
    try {
      final alreadyDone = DatabaseService.autoAccountingPrefs
          .get(_migrationFlagKey, defaultValue: false) as bool;
      if (alreadyDone) {
        return 0;
      }

      // WHY: 先按账户名聚合全部应扣金额，确认所有账户均可解析后再统一落库，
      // 避免部分账户缺失时产生半截扣减、重跑又无法幂等的问题
      final Map<String, Decimal> deductionByAccount = <String, Decimal>{};
      int matchedCount = 0;
      int missingTxCount = 0;
      int missingAccountCount = 0;
      final Set<String> missingAccountNames = <String>{};

      for (final PendingTransaction pending
          in DatabaseService.pendingTransactions.values) {
        if (pending.status != PendingStatus.confirmed) continue;

        final String? txId = pending.confirmedTransactionId;
        if (txId == null || txId.isEmpty) continue;

        final Transaction? tx = DatabaseService.getTransactionById(txId);
        if (tx == null || tx.isDeleted) {
          // WHY: 关联交易已被物理删除或软删除，补扣无对应流水，跳过
          missingTxCount++;
          continue;
        }

        final Account? account = AccountService.getAccountByName(tx.account);
        if (account == null) {
          missingAccountCount++;
          missingAccountNames.add(tx.account);
          continue;
        }

        // WHY: 自动记账历史交易全部为支出（confirm 中 isIncome 固定 false）
        deductionByAccount.update(
          tx.account,
          (Decimal sum) => sum + tx.amount,
          ifAbsent: () => tx.amount,
        );
        matchedCount++;
      }

      // WHY: 提前校验聚合中所有账户仍可解析（上面循环已保证），统一保存变更
      for (final MapEntry<String, Decimal> entry in deductionByAccount.entries) {
        final Account? account = AccountService.getAccountByName(entry.key);
        if (account == null) continue;
        account.currentBalance -= entry.value;
        await AccountService.updateAccount(account);
        debugPrint(
            '[BalanceMigration] 账户 "${entry.key}" 补扣 ¥${entry.value.toStringAsFixed(2)}，补扣后余额 ¥${account.currentBalance.toStringAsFixed(2)}');
      }

      await DatabaseService.autoAccountingPrefs.put(_migrationFlagKey, true);

      debugPrint('[BalanceMigration] 迁移完成: 补扣 $matchedCount 笔, '
          '缺失交易跳过 $missingTxCount 笔, 缺失账户跳过 $missingAccountCount 笔'
          '${missingAccountNames.isEmpty ? '' : ' (账户: ${missingAccountNames.join(', ')})'}');

      return matchedCount;
    } catch (e) {
      // WHY: 迁移失败不写完成标志、不阻断应用启动，下次启动自动重试
      debugPrint('[BalanceMigration] 迁移失败，将在下次启动重试: $e');
      return 0;
    }
  }
}
