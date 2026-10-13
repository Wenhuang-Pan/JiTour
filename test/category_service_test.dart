import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jitu/services/category_service.dart';
import 'package:jitu/services/database_service.dart';
import 'package:jitu/models/category.dart';

void main() {
  group('CategoryService', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('hive_test_');
      Hive.init(tmpDir.path);
      // WHY: 必须先由 DatabaseService 打开 box 并注册适配器，CategoryService 才能访问
      await DatabaseService.init();
      await DatabaseService.categories.clear();
    });

    tearDown(() async {
      await DatabaseService.categories.clear();
      try {
        await Hive.close();
        tmpDir.delete(recursive: true);
      } catch (_) {}
    });

    group('addCategory', () {
      test('添加收入分类', () async {
        final category = Category.createIncome(
          id: 'test-income-1',
          name: '测试收入',
          iconName: '工资',
          color: '#10B981',
        );

        await CategoryService.addCategory(category);

        final found = CategoryService.getCategoryById('test-income-1');
        expect(found, isNotNull);
        expect(found?.name, '测试收入');
        expect(found?.isIncome, true);
      });

      test('添加支出分类', () async {
        final category = Category.createExpense(
          id: 'test-expense-1',
          name: '测试支出',
          iconName: '餐饮',
          color: '#F59E0B',
        );

        await CategoryService.addCategory(category);

        final found = CategoryService.getCategoryById('test-expense-1');
        expect(found, isNotNull);
        expect(found?.name, '测试支出');
        expect(found?.isIncome, false);
      });
    });

    group('getIncomeCategories', () {
      test('获取所有收入分类', () async {
        await CategoryService.addCategory(Category.createIncome(
          id: 'income-1',
          name: '工资',
          iconName: '工资',
          color: '#10B981',
        ));
        await CategoryService.addCategory(Category.createIncome(
          id: 'income-2',
          name: '奖金',
          iconName: '奖金',
          color: '#10B981',
        ));
        await CategoryService.addCategory(Category.createExpense(
          id: 'expense-1',
          name: '餐饮',
          iconName: '餐饮',
          color: '#F59E0B',
        ));

        final incomeCategories = CategoryService.getIncomeCategories();
        expect(incomeCategories.length, 2);
        expect(incomeCategories[0].name, '工资');
        expect(incomeCategories[1].name, '奖金');
      });

      test('不包含已删除的分类', () async {
        final category = Category.createIncome(
          id: 'income-deleted',
          name: '已删除收入',
          iconName: '工资',
          color: '#10B981',
        );
        await CategoryService.addCategory(category);
        await CategoryService.deleteCategory('income-deleted');

        final incomeCategories = CategoryService.getIncomeCategories();
        expect(incomeCategories.where((c) => c.name == '已删除收入').isEmpty, true);
      });
    });

    group('getExpenseCategories', () {
      test('获取所有支出分类', () async {
        await CategoryService.addCategory(Category.createExpense(
          id: 'expense-1',
          name: '餐饮',
          iconName: '餐饮',
          color: '#F59E0B',
        ));
        await CategoryService.addCategory(Category.createExpense(
          id: 'expense-2',
          name: '交通',
          iconName: '交通',
          color: '#3B82F6',
        ));
        await CategoryService.addCategory(Category.createIncome(
          id: 'income-1',
          name: '工资',
          iconName: '工资',
          color: '#10B981',
        ));

        final expenseCategories = CategoryService.getExpenseCategories();
        expect(expenseCategories.length, 2);
        expect(expenseCategories[0].name, '餐饮');
        expect(expenseCategories[1].name, '交通');
      });

      test('不包含已删除的分类', () async {
        final category = Category.createExpense(
          id: 'expense-deleted',
          name: '已删除支出',
          iconName: '餐饮',
          color: '#F59E0B',
        );
        await CategoryService.addCategory(category);
        await CategoryService.deleteCategory('expense-deleted');

        final expenseCategories = CategoryService.getExpenseCategories();
        expect(expenseCategories.where((c) => c.name == '已删除支出').isEmpty, true);
      });
    });

    group('getCategoryById', () {
      test('根据ID获取分类', () async {
        await CategoryService.addCategory(Category.createExpense(
          id: 'test-category',
          name: '测试分类',
          iconName: '测试',
          color: '#6B7280',
        ));

        final found = CategoryService.getCategoryById('test-category');
        expect(found, isNotNull);
        expect(found?.name, '测试分类');
      });

      test('获取不存在的分类返回null', () {
        final found = CategoryService.getCategoryById('nonexistent-id');
        expect(found, isNull);
      });
    });

    group('getCategoryByName', () {
      test('根据名称获取收入分类', () async {
        await CategoryService.addCategory(Category.createIncome(
          id: 'income-test',
          name: '工资',
          iconName: '工资',
          color: '#10B981',
        ));

        final found = CategoryService.getCategoryByName('工资', true);
        expect(found, isNotNull);
        expect(found?.isIncome, true);
      });

      test('根据名称获取支出分类', () async {
        await CategoryService.addCategory(Category.createExpense(
          id: 'expense-test',
          name: '餐饮',
          iconName: '餐饮',
          color: '#F59E0B',
        ));

        final found = CategoryService.getCategoryByName('餐饮', false);
        expect(found, isNotNull);
        expect(found?.isIncome, false);
      });

      test('获取不存在的分类返回null', () {
        final found = CategoryService.getCategoryByName('不存在', true);
        expect(found, isNull);
      });

      test('区分收入和支出分类', () async {
        await CategoryService.addCategory(Category.createIncome(
          id: 'income-same',
          name: '相同名称',
          iconName: '工资',
          color: '#10B981',
        ));
        await CategoryService.addCategory(Category.createExpense(
          id: 'expense-same',
          name: '相同名称',
          iconName: '餐饮',
          color: '#F59E0B',
        ));

        final incomeFound = CategoryService.getCategoryByName('相同名称', true);
        final expenseFound = CategoryService.getCategoryByName('相同名称', false);

        expect(incomeFound?.id, 'income-same');
        expect(expenseFound?.id, 'expense-same');
      });
    });

    group('updateCategory', () {
      test('更新分类信息', () async {
        await CategoryService.addCategory(Category.createExpense(
          id: 'update-test',
          name: '旧名称',
          iconName: '餐饮',
          color: '#F59E0B',
        ));

        final category = CategoryService.getCategoryById('update-test')!;
        category.name = '新名称';
        category.color = '#EF4444';
        await CategoryService.updateCategory(category);

        final updated = CategoryService.getCategoryById('update-test');
        expect(updated?.name, '新名称');
        expect(updated?.color, '#EF4444');
      });
    });

    group('deleteCategory', () {
      test('软删除分类', () async {
        await CategoryService.addCategory(Category.createExpense(
          id: 'delete-test',
          name: '待删除',
          iconName: '餐饮',
          color: '#F59E0B',
        ));

        await CategoryService.deleteCategory('delete-test');

        final category = CategoryService.getCategoryById('delete-test');
        expect(category?.isDeleted, true);
        expect(category?.deletedAt, isNotNull);
      });
    });

    group('restoreCategory', () {
      test('恢复已删除的分类', () async {
        await CategoryService.addCategory(Category.createExpense(
          id: 'restore-test',
          name: '待恢复',
          iconName: '餐饮',
          color: '#F59E0B',
        ));
        await CategoryService.deleteCategory('restore-test');

        await CategoryService.restoreCategory('restore-test');

        final category = CategoryService.getCategoryById('restore-test');
        expect(category?.isDeleted, false);
        expect(category?.deletedAt, isNull);
      });
    });

    group('permanentlyDeleteCategory', () {
      test('永久删除分类', () async {
        await CategoryService.addCategory(Category.createExpense(
          id: 'permanent-delete',
          name: '永久删除',
          iconName: '餐饮',
          color: '#F59E0B',
        ));

        await CategoryService.permanentlyDeleteCategory('permanent-delete');

        final category = CategoryService.getCategoryById('permanent-delete');
        expect(category, isNull);
      });
    });

    group('getDeletedCategories', () {
      test('获取已删除的分类', () async {
        await CategoryService.addCategory(Category.createExpense(
          id: 'deleted-1',
          name: '已删除1',
          iconName: '餐饮',
          color: '#F59E0B',
        ));
        await CategoryService.addCategory(Category.createExpense(
          id: 'deleted-2',
          name: '已删除2',
          iconName: '交通',
          color: '#3B82F6',
        ));
        await CategoryService.addCategory(Category.createExpense(
          id: 'active',
          name: '活跃',
          iconName: '购物',
          color: '#8B5CF6',
        ));

        await CategoryService.deleteCategory('deleted-1');
        await CategoryService.deleteCategory('deleted-2');

        final deleted = CategoryService.getDeletedCategories();
        expect(deleted.length, 2);
        expect(deleted.any((c) => c.name == '活跃'), false);
      });
    });

    group('isCategoryNameExists', () {
      test('检查分类名称是否存在', () async {
        await CategoryService.addCategory(Category.createExpense(
          id: 'exists-test',
          name: '餐饮',
          iconName: '餐饮',
          color: '#F59E0B',
        ));

        expect(CategoryService.isCategoryNameExists('餐饮', false), true);
        expect(CategoryService.isCategoryNameExists('不存在', false), false);
      });

      test('区分收入和支出分类', () async {
        await CategoryService.addCategory(Category.createIncome(
          id: 'income-exists',
          name: '工资',
          iconName: '工资',
          color: '#10B981',
        ));

        expect(CategoryService.isCategoryNameExists('工资', true), true);
        expect(CategoryService.isCategoryNameExists('工资', false), false);
      });

      test('排除指定ID检查', () async {
        await CategoryService.addCategory(Category.createExpense(
          id: 'exclude-test',
          name: '餐饮',
          iconName: '餐饮',
          color: '#F59E0B',
        ));

        expect(
            CategoryService.isCategoryNameExists('餐饮', false,
                excludeId: 'exclude-test'),
            false);
      });
    });

    group('exportCategories', () {
      test('导出所有非删除分类', () async {
        await CategoryService.addCategory(Category.createExpense(
          id: 'export-test',
          name: '餐饮',
          iconName: '餐饮',
          color: '#F59E0B',
        ));
        await CategoryService.addCategory(Category.createExpense(
          id: 'export-deleted',
          name: '已删除',
          iconName: '交通',
          color: '#3B82F6',
        ));
        await CategoryService.deleteCategory('export-deleted');

        final exported = CategoryService.exportCategories();
        expect(exported.length, 1);
        expect(exported[0]['name'], '餐饮');
      });
    });

    group('importCategories', () {
      test('导入新分类', () async {
        final data = [
          {
            'id': 'import-test',
            'name': '导入分类',
            'iconName': '测试',
            'isIncome': false,
            'color': '#6B7280',
            'createdAt': DateTime.now().toIso8601String(),
            'deletedAt': null,
          }
        ];

        await CategoryService.importCategories(data);

        final imported = CategoryService.getCategoryByName('导入分类', false);
        expect(imported, isNotNull);
      });

      test('跳过已存在的分类', () async {
        await CategoryService.addCategory(Category.createExpense(
          id: 'exists-import',
          name: '餐饮',
          iconName: '餐饮',
          color: '#F59E0B',
        ));

        final data = [
          {
            'id': 'new-id',
            'name': '餐饮',
            'iconName': '餐饮',
            'isIncome': false,
            'color': '#EF4444',
            'createdAt': DateTime.now().toIso8601String(),
            'deletedAt': null,
          }
        ];

        await CategoryService.importCategories(data);

        final categories = CategoryService.getExpenseCategories();
        expect(categories.length, 1);
        expect(categories[0].color, '#F59E0B');
      });
    });

    group('getCategoryStatistics', () {
      test('获取分类统计信息', () async {
        await CategoryService.addCategory(Category.createIncome(
          id: 'stat-income',
          name: '工资',
          iconName: '工资',
          color: '#10B981',
        ));
        await CategoryService.addCategory(Category.createExpense(
          id: 'stat-expense',
          name: '餐饮',
          iconName: '餐饮',
          color: '#F59E0B',
        ));
        await CategoryService.addCategory(Category.createExpense(
          id: 'stat-deleted',
          name: '已删除',
          iconName: '交通',
          color: '#3B82F6',
        ));
        await CategoryService.deleteCategory('stat-deleted');

        final stats = CategoryService.getCategoryStatistics();
        expect(stats['totalIncomeCategories'], 1);
        expect(stats['totalExpenseCategories'], 1);
        expect(stats['totalCategories'], 2);
        expect(stats['deletedCategories'], 1);
      });
    });

    group('reorderCategories', () {
      test('向下拖动后顺序正确且 sortOrder 已持久化', () async {
        await CategoryService.addCategory(Category.createExpense(
            id: 'exp-a', name: '餐饮', iconName: '餐饮', color: '#F59E0B'));
        await CategoryService.addCategory(Category.createExpense(
            id: 'exp-b', name: '交通', iconName: '交通', color: '#3B82F6'));
        await CategoryService.addCategory(Category.createExpense(
            id: 'exp-c', name: '购物', iconName: '购物', color: '#8B5CF6'));

        // 将第 1 项拖到末尾（ReorderableListView 语义 newIndex=3）
        await CategoryService.reorderCategories(false, 0, 3);

        final categories = CategoryService.getExpenseCategories();
        expect(
            categories.map((c) => c.id).toList(), ['exp-b', 'exp-c', 'exp-a']);
        expect(CategoryService.getCategoryById('exp-b')?.sortOrder, 0);
        expect(CategoryService.getCategoryById('exp-c')?.sortOrder, 1);
        expect(CategoryService.getCategoryById('exp-a')?.sortOrder, 2);
      });

      test('向上拖动后顺序正确', () async {
        await CategoryService.addCategory(Category.createExpense(
            id: 'exp-a', name: '餐饮', iconName: '餐饮', color: '#F59E0B'));
        await CategoryService.addCategory(Category.createExpense(
            id: 'exp-b', name: '交通', iconName: '交通', color: '#3B82F6'));
        await CategoryService.addCategory(Category.createExpense(
            id: 'exp-c', name: '购物', iconName: '购物', color: '#8B5CF6'));

        // 将最后 1 项拖到最前
        await CategoryService.reorderCategories(false, 2, 0);

        final categories = CategoryService.getExpenseCategories();
        expect(
            categories.map((c) => c.id).toList(), ['exp-c', 'exp-a', 'exp-b']);
        expect(CategoryService.getCategoryById('exp-c')?.sortOrder, 0);
        expect(CategoryService.getCategoryById('exp-a')?.sortOrder, 1);
        expect(CategoryService.getCategoryById('exp-b')?.sortOrder, 2);
      });

      test('收入和支出排序互不影响', () async {
        await CategoryService.addCategory(Category.createIncome(
            id: 'inc-1', name: '工资', iconName: '工资', color: '#10B981'));
        await CategoryService.addCategory(Category.createIncome(
            id: 'inc-2', name: '奖金', iconName: '奖金', color: '#F59E0B'));
        await CategoryService.addCategory(Category.createExpense(
            id: 'exp-1', name: '餐饮', iconName: '餐饮', color: '#F59E0B'));
        await CategoryService.addCategory(Category.createExpense(
            id: 'exp-2', name: '交通', iconName: '交通', color: '#3B82F6'));

        await CategoryService.reorderCategories(false, 0, 2);

        expect(CategoryService.getExpenseCategories().map((c) => c.id).toList(),
            ['exp-2', 'exp-1']);
        expect(CategoryService.getIncomeCategories().map((c) => c.id).toList(),
            ['inc-1', 'inc-2']);
        expect(CategoryService.getCategoryById('inc-1')?.sortOrder, 0);
        expect(CategoryService.getCategoryById('inc-2')?.sortOrder, 1);
      });

      test('新增分类自动排到末尾', () async {
        await CategoryService.addCategory(Category.createExpense(
            id: 'exp-a', name: '餐饮', iconName: '餐饮', color: '#F59E0B'));
        await CategoryService.addCategory(Category.createExpense(
            id: 'exp-b', name: '交通', iconName: '交通', color: '#3B82F6'));
        await CategoryService.reorderCategories(false, 1, 0);

        await CategoryService.addCategory(Category.createExpense(
            id: 'exp-c', name: '购物', iconName: '购物', color: '#8B5CF6'));

        final categories = CategoryService.getExpenseCategories();
        expect(
            categories.map((c) => c.id).toList(), ['exp-b', 'exp-a', 'exp-c']);
        expect(CategoryService.getCategoryById('exp-c')?.sortOrder, 2);
      });

      test('越界索引静默忽略', () async {
        await CategoryService.addCategory(Category.createExpense(
            id: 'exp-a', name: '餐饮', iconName: '餐饮', color: '#F59E0B'));

        await CategoryService.reorderCategories(false, 5, 0);
        await CategoryService.reorderCategories(false, 0, 5);

        expect(CategoryService.getExpenseCategories().single.id, 'exp-a');
      });
    });

    group('sortOrder 迁移', () {
      test('旧数据全为 0 时按 createdAt 初始化排序', () async {
        // WHY: 直接 put 模拟旧版本数据（无 sortOrder，读取补 0），
        // 绕过 addCategory 的自动排序赋值
        final box = DatabaseService.categories;
        await box.put(
            'old-1',
            Category(
                id: 'old-1',
                name: '旧分类一',
                iconName: '旧分类一',
                isIncome: false,
                color: '#111111',
                createdAt: DateTime(2023, 1, 1)));
        await box.put(
            'old-2',
            Category(
                id: 'old-2',
                name: '旧分类二',
                iconName: '旧分类二',
                isIncome: false,
                color: '#222222',
                createdAt: DateTime(2023, 1, 2)));

        await CategoryService.init();

        expect(CategoryService.getCategoryById('old-1')?.sortOrder, 0);
        expect(CategoryService.getCategoryById('old-2')?.sortOrder, 1);
        final ids =
            CategoryService.getExpenseCategories().map((c) => c.id).toList();
        expect(ids.indexOf('old-1') < ids.indexOf('old-2'), true);
      });
    });
  });
}
