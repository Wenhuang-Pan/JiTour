import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jitu/services/category_inference_service.dart';
import 'package:jitu/services/category_service.dart';
import 'package:jitu/services/database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CategoryInferenceService', () {
    late Directory tmpDir;

    setUp(() async {
      tmpDir = await Directory.systemTemp.createTemp('hive_infer_');
      Hive.init(tmpDir.path);
      await DatabaseService.init();
      await DatabaseService.merchantCategoryMap.clear();
      // WHY: infer 末尾会校验分类是否存在，需先初始化默认分类
      await DatabaseService.categories.clear();
      await CategoryService.init();
    });

    tearDown(() async {
      try {
        await Hive.close();
        tmpDir.delete(recursive: true);
      } catch (_) {}
    });

    group('infer', () {
      test('商户名为 null 返回 null 分类，置信度 0.0', () async {
        final result = await CategoryInferenceService.infer(null);
        expect(result.categoryName, isNull);
        expect(result.confidence, 0.0);
      });

      test('商户名为空字符串返回 null 分类，置信度 0.0', () async {
        final result = await CategoryInferenceService.infer('');
        expect(result.categoryName, isNull);
        expect(result.confidence, 0.0);
      });

      test('命中学习表返回分类，置信度 0.95', () async {
        // WHY: 用默认分类「餐饮」，确保存在性校验通过
        await DatabaseService.merchantCategoryMap.put('楼下超市', '餐饮');
        final result = await CategoryInferenceService.infer('楼下超市');
        expect(result.categoryName, '餐饮');
        expect(result.confidence, 0.95);
      });

      test('未命中学习表时命中关键词，置信度 0.8', () async {
        final result = await CategoryInferenceService.infer('星巴克咖啡');
        expect(result.categoryName, '餐饮');
        expect(result.confidence, 0.8);
      });

      test('学习表优先级高于关键词', () async {
        // WHY: 「星巴克」关键词默认映射到「餐饮」，但用户学习为「交通」后应返回「交通」
        await DatabaseService.merchantCategoryMap.put('星巴克', '交通');
        final result = await CategoryInferenceService.infer('星巴克');
        expect(result.categoryName, '交通');
        expect(result.confidence, 0.95);
      });

      test('完全未命中返回 null 分类，置信度 0.3', () async {
        final result = await CategoryInferenceService.infer('某某不知名商户');
        expect(result.categoryName, isNull);
        expect(result.confidence, 0.3);
      });

      test('关键词命中但分类不存在时降级为 null', () async {
        // WHY: 「电影」映射到「娱乐」，默认分类无「娱乐」，应降级返回 null
        final result = await CategoryInferenceService.infer('电影院');
        expect(result.categoryName, isNull);
        expect(result.confidence, 0.3);
      });

      test('学习表分类被删除后降级为 null', () async {
        // WHY: 学习了一个不存在的分类名，模拟用户删除分类的场景
        await DatabaseService.merchantCategoryMap.put('某商户', '不存在的分类');
        final result = await CategoryInferenceService.infer('某商户');
        expect(result.categoryName, isNull);
      });
    });

    group('learn / forget', () {
      test('learn 后相同商户命中学习表', () async {
        await CategoryInferenceService.learn('瑞幸咖啡', '餐饮');
        final result = await CategoryInferenceService.infer('瑞幸咖啡');
        expect(result.categoryName, '餐饮');
        expect(result.confidence, 0.95);
      });

      test('forget 后不再命中学习表', () async {
        await CategoryInferenceService.learn('瑞幸咖啡', '餐饮');
        await CategoryInferenceService.forget('瑞幸咖啡');
        final result = await CategoryInferenceService.infer('瑞幸咖啡');
        // WHY: 学习记录删除后应回退到关键词匹配（「瑞幸」→ 餐饮，置信度 0.8）
        expect(result.categoryName, '餐饮');
        expect(result.confidence, 0.8);
      });
    });

    group('getAllLearned', () {
      test('返回所有已学习商户映射', () async {
        await CategoryInferenceService.learn('商户A', '餐饮');
        await CategoryInferenceService.learn('商户B', '交通');

        final learned = CategoryInferenceService.getAllLearned();
        expect(learned.length, 2);
        expect(learned['商户A'], '餐饮');
        expect(learned['商户B'], '交通');
      });

      test('无学习记录返回空 map', () {
        expect(CategoryInferenceService.getAllLearned(), isEmpty);
      });
    });
  });
}
