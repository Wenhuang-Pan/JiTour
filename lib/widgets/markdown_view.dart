import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 轻量 Markdown 渲染组件
///
/// WHY: AI 分析结果返回的是 Markdown 文本，直接用 Text 展示会把 `##`、`**`
/// 等标记符号原样暴露给用户；本场景只需要覆盖大模型常见输出（标题、段落、
/// 粗体、斜体、行内代码、有序/无序列表、引用、分割线、代码块），
/// 为此引入三方 Markdown 依赖不划算，故在此实现零依赖的轻量渲染。
class MarkdownView extends StatefulWidget {
  /// 构造 Markdown 渲染组件
  ///
  /// @param data 原始 Markdown 文本
  /// @param baseStyle 正文字体样式，默认取主题 bodyMedium
  const MarkdownView({super.key, required this.data, this.baseStyle});

  /// 原始 Markdown 文本
  final String data;

  /// 正文字体样式（不传则使用主题正文样式）
  final TextStyle? baseStyle;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

/// Markdown 块类型
enum _BlockType {
  /// 标题（# 的个数即层级）
  heading,

  /// 普通段落
  paragraph,

  /// 无序列表项
  bullet,

  /// 有序列表项
  ordered,

  /// 引用块
  quote,

  /// 代码块
  code,

  /// 分割线
  divider,
}

/// 解析后的 Markdown 区块
class _MdBlock {
  /// 构造区块
  ///
  /// @param type 区块类型
  /// @param text 区块文本
  /// @param level 标题层级（仅 heading 使用）
  /// @param index 有序列表序号（仅 ordered 使用）
  const _MdBlock(this.type, this.text, {this.level = 1, this.index = ''});

  /// 区块类型
  final _BlockType type;

  /// 区块文本
  final String text;

  /// 标题层级
  final int level;

  /// 有序列表序号
  final String index;
}

class _MarkdownViewState extends State<MarkdownView> {
  /// 分割线正则（预编译，避免解析时重复创建）
  static final RegExp _dividerPattern = RegExp(r'^(---+|\*\*\*+|___+)$');

  /// 标题正则
  static final RegExp _headingPattern = RegExp(r'^(#{1,6})\s+(.*)$');

  /// 无序列表正则
  static final RegExp _bulletPattern = RegExp(r'^[-*+]\s+(.*)$');

  /// 有序列表正则
  static final RegExp _orderedPattern = RegExp(r'^(\d+)[.)]\s+(.*)$');

  /// 引用前缀正则
  static final RegExp _quotePrefixPattern = RegExp(r'^>\s*');

  /// 解析后的区块缓存
  ///
  /// WHY: 解析结果在 initState / didUpdateWidget 中计算，避免每帧 build 重复解析
  late List<_MdBlock> _blocks = _parse(widget.data);

  @override
  void didUpdateWidget(covariant MarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _blocks = _parse(widget.data);
    }
  }

  /// 解析 Markdown 文本为区块列表。
  ///
  /// @param data 原始 Markdown 文本
  /// @return 区块列表
  /// O(n)，n 为文本行数
  static List<_MdBlock> _parse(String data) {
    final List<_MdBlock> blocks = <_MdBlock>[];
    final List<String> paragraphs = <String>[];
    final List<String> codeLines = <String>[];
    bool inCodeBlock = false;

    /// 输出并清空段落缓冲
    void flushParagraph() {
      if (paragraphs.isEmpty) return;
      blocks.add(_MdBlock(_BlockType.paragraph, paragraphs.join('\n')));
      paragraphs.clear();
    }

    final List<String> lines = data.replaceAll('\r\n', '\n').split('\n');
    for (final String rawLine in lines) {
      final String line = rawLine.trim();
      if (line.startsWith('```')) {
        if (inCodeBlock) {
          blocks.add(_MdBlock(_BlockType.code, codeLines.join('\n')));
          codeLines.clear();
          inCodeBlock = false;
        } else {
          flushParagraph();
          inCodeBlock = true;
        }
        continue;
      }
      if (inCodeBlock) {
        codeLines.add(rawLine);
        continue;
      }
      if (line.isEmpty) {
        flushParagraph();
        continue;
      }
      if (_dividerPattern.hasMatch(line)) {
        flushParagraph();
        blocks.add(const _MdBlock(_BlockType.divider, ''));
        continue;
      }
      final RegExpMatch? heading = _headingPattern.firstMatch(line);
      if (heading != null) {
        flushParagraph();
        final String marks = heading.group(1) ?? '#';
        blocks.add(_MdBlock(
          _BlockType.heading,
          heading.group(2) ?? '',
          level: marks.length,
        ));
        continue;
      }
      final RegExpMatch? bullet = _bulletPattern.firstMatch(line);
      if (bullet != null) {
        flushParagraph();
        blocks.add(_MdBlock(_BlockType.bullet, bullet.group(1) ?? ''));
        continue;
      }
      final RegExpMatch? ordered = _orderedPattern.firstMatch(line);
      if (ordered != null) {
        flushParagraph();
        blocks.add(_MdBlock(
          _BlockType.ordered,
          ordered.group(2) ?? '',
          index: ordered.group(1) ?? '',
        ));
        continue;
      }
      if (line.startsWith('>')) {
        flushParagraph();
        blocks.add(_MdBlock(
          _BlockType.quote,
          line.replaceFirst(_quotePrefixPattern, ''),
        ));
        continue;
      }
      paragraphs.add(line);
    }
    if (codeLines.isNotEmpty) {
      blocks.add(_MdBlock(_BlockType.code, codeLines.join('\n')));
    }
    flushParagraph();
    return blocks;
  }

  /// 把行内 Markdown 解析为富文本片段。
  ///
  /// @param text 单行文本
  /// @param style 基础样式
  /// @param codeColor 行内代码背景色
  /// @return 富文本片段列表
  /// O(n)，n 为字符数
  static List<InlineSpan> _inlineSpans(
    String text,
    TextStyle style,
    Color codeColor,
  ) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final StringBuffer buffer = StringBuffer();

    /// 输出并清空普通文本缓冲
    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString(), style: style));
      buffer.clear();
    }

    int i = 0;
    while (i < text.length) {
      if (text.startsWith('**', i)) {
        final int end = text.indexOf('**', i + 2);
        if (end > i + 2) {
          flush();
          spans.add(TextSpan(
            text: text.substring(i + 2, end),
            style: style.copyWith(fontWeight: FontWeight.w700),
          ));
          i = end + 2;
          continue;
        }
      }
      if (text[i] == '`') {
        final int end = text.indexOf('`', i + 1);
        if (end > i + 1) {
          flush();
          spans.add(TextSpan(
            text: text.substring(i + 1, end),
            style: style.copyWith(
              fontFamily: 'monospace',
              backgroundColor: codeColor,
            ),
          ));
          i = end + 1;
          continue;
        }
      }
      if (text[i] == '*' || text[i] == '_') {
        final int end = text.indexOf(text[i], i + 1);
        if (end > i + 1) {
          flush();
          spans.add(TextSpan(
            text: text.substring(i + 1, end),
            style: style.copyWith(fontStyle: FontStyle.italic),
          ));
          i = end + 1;
          continue;
        }
      }
      buffer.write(text[i]);
      i++;
    }
    flush();
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle base = widget.baseStyle ??
        textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);
    final TextStyle body = base.copyWith(height: 1.6);
    final Color primary = Theme.of(context).colorScheme.primary;
    final Color codeColor = primary.withValues(alpha: 0.08);
    final Color subtle =
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.9);

    final List<Widget> children = <Widget>[];
    for (int i = 0; i < _blocks.length; i++) {
      final _MdBlock block = _blocks[i];
      switch (block.type) {
        case _BlockType.heading:
          final double size = switch (block.level) {
            1 => 19,
            2 => 17,
            3 => 15.5,
            _ => 14.5,
          };
          children.add(Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? 0 : AppTheme.spaceSmall,
              bottom: AppTheme.spaceXSmall,
            ),
            child: SelectableText.rich(
              TextSpan(
                children: _inlineSpans(block.text, body, codeColor),
                style: body.copyWith(
                  fontSize: size,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ));
        case _BlockType.paragraph:
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spaceXSmall),
            child: SelectableText.rich(
              TextSpan(
                children: _inlineSpans(block.text, body, codeColor),
                style: body,
              ),
            ),
          ));
        case _BlockType.bullet:
          children.add(_buildListItem(
            context,
            prefix: '•',
            text: block.text,
            body: body,
            codeColor: codeColor,
          ));
        case _BlockType.ordered:
          children.add(_buildListItem(
            context,
            prefix: '${block.index}.',
            text: block.text,
            body: body,
            codeColor: codeColor,
          ));
        case _BlockType.quote:
          children.add(Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spaceXSmall),
            padding: const EdgeInsets.only(left: AppTheme.spaceMedium),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: primary.withValues(alpha: 0.4), width: 3),
              ),
            ),
            child: SelectableText.rich(
              TextSpan(
                children: _inlineSpans(block.text, body, codeColor),
                style: body.copyWith(color: subtle, fontStyle: FontStyle.italic),
              ),
            ),
          ));
        case _BlockType.code:
          children.add(Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: AppTheme.spaceSmall),
            padding: const EdgeInsets.all(AppTheme.spaceSmall),
            decoration: BoxDecoration(
              color: codeColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                block.text,
                style: body.copyWith(fontFamily: 'monospace', fontSize: 12.5),
              ),
            ),
          ));
        case _BlockType.divider:
          children.add(const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.spaceSmall),
            child: Divider(height: 1),
          ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// 构建列表项。
  ///
  /// @param context 构建上下文
  /// @param prefix 序号或圆点
  /// @param text 列表项文本
  /// @param body 正文样式
  /// @param codeColor 行内代码背景色
  /// @return 列表项 Widget
  Widget _buildListItem(
    BuildContext context, {
    required String prefix,
    required String text,
    required TextStyle body,
    required Color codeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 22,
            child: Text(
              prefix,
              style: body.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText.rich(
              TextSpan(
                children: _inlineSpans(text, body, codeColor),
                style: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
