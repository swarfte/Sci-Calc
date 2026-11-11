import '../model/expression/cursor_position.dart';
import '../model/expression/expression_node.dart';
import '../model/expression/node/constant_node.dart';
import '../model/expression/node/fraction_node.dart';
import '../model/expression/node/function_node.dart';
import '../model/expression/node/group_node.dart';
import '../model/expression/node/logarithm_node.dart';
import '../model/expression/node/mixed_fraction_node.dart';
import '../model/expression/node/number_node.dart';
import '../model/expression/node/operator_node.dart';
import '../model/expression/node/power_node.dart';
import '../model/expression/node/root_node.dart';
import '../model/expression/node/scientific_node.dart';
import '../model/expression/node/sequence_node.dart';
import '../model/expression/node_id.dart';
import '../model/expression/tex_serialization_result.dart';
import '../model/expression/tree_expression_document.dart';

/// 將 [TreeExpressionDocument] 序列化為 TeX，並在 cursor 位置插入閃爍游標。
///
/// 直接遍歷 Expression Tree 產生 TeX，不再依賴 `texExpression` 字串或 TeX
/// offset。游標 marker 透過單一 placeholder（[_kCursorPlaceholder]）插入，
/// 最後分別替換成 visible / hidden 版本，確保兩個輸出結構完全等寬。
///
/// 詳細規則見 `EXPRESSION_TREE_REFACTOR_PLAN.md` Phase 3。
class TreeExpressionTexSerializer {
  const TreeExpressionTexSerializer();

  /// 序列化整份 document，回傳 visible / hidden 兩個等寬 TeX 版本。
  ///
  /// `withVisibleCursor` 帶有 visible cursor marker，`withHiddenCursor` 永遠
  /// 使用 hidden marker。兩者由顯示層隨閃爍動畫交替（「游標熄滅」帧使用
  /// hidden 版本，確保版面不位移）。
  TexSerializationResult serialize(TreeExpressionDocument document) {
    final placeholderTex = _serializeDocument(document);

    return TexSerializationResult(
      withVisibleCursor: placeholderTex.replaceAll(
        _kCursorPlaceholder,
        _kVisibleCursor,
      ),
      withHiddenCursor: placeholderTex.replaceAll(
        _kCursorPlaceholder,
        _kHiddenCursor,
      ),
    );
  }

  String _serializeDocument(TreeExpressionDocument document) {
    final cursor = document.cursor;
    return _serializeSequence(
      document.root,
      activeSequenceId: cursor.sequenceId,
      cursor: cursor,
    );
  }

  String _serializeSequence(
    SequenceNode sequence, {
    required NodeId activeSequenceId,
    required CursorPosition cursor,
  }) {
    final isActive = sequence.id == activeSequenceId;

    if (sequence.isEmpty) {
      return isActive ? '$_kCursorPlaceholder$_kMinimumWidth' : _kMinimumWidth;
    }

    final buffer = StringBuffer();
    for (var i = 0; i < sequence.children.length; i++) {
      // 在 cursor 的 node boundary 前插入 marker（gap mode）。
      if (isActive && cursor.textOffset == null && cursor.nodeOffset == i) {
        buffer.write(_kCursorPlaceholder);
      }

      final child = sequence.children[i];
      buffer.write(
        _serializeNode(
          child,
          activeSequenceId: activeSequenceId,
          cursor: cursor,
          isInsideActiveNumber:
              isActive &&
              cursor.textOffset != null &&
              cursor.nodeOffset == i &&
              child is NumberNode,
        ),
      );
    }

    // cursor 位於 sequence 末端（gap mode）。
    if (isActive &&
        cursor.textOffset == null &&
        cursor.nodeOffset >= sequence.children.length) {
      buffer.write(_kCursorPlaceholder);
    }

    return buffer.toString();
  }

  String _serializeNode(
    ExpressionNode node, {
    required NodeId activeSequenceId,
    required CursorPosition cursor,
    required bool isInsideActiveNumber,
  }) {
    switch (node) {
      case NumberNode():
        return _serializeNumber(
          node,
          isInsideActiveNumber: isInsideActiveNumber,
          cursor: cursor,
        );
      case OperatorNode():
        return _operatorTex(node.operator);
      case ConstantNode():
        return _constantTex(node.constant);
      case FunctionNode():
        return _serializeFunction(
          node,
          activeSequenceId: activeSequenceId,
          cursor: cursor,
        );
      case FractionNode():
        return _serializeFraction(
          node,
          activeSequenceId: activeSequenceId,
          cursor: cursor,
        );
      case RootNode():
        return _serializeRoot(
          node,
          activeSequenceId: activeSequenceId,
          cursor: cursor,
        );
      case PowerNode():
        return _serializePower(
          node,
          activeSequenceId: activeSequenceId,
          cursor: cursor,
        );
      case LogarithmNode():
        return _serializeLogarithm(
          node,
          activeSequenceId: activeSequenceId,
          cursor: cursor,
        );
      case MixedFractionNode():
        return _serializeMixedFraction(
          node,
          activeSequenceId: activeSequenceId,
          cursor: cursor,
        );
      case ScientificNode():
        return _serializeScientific(
          node,
          activeSequenceId: activeSequenceId,
          cursor: cursor,
        );
      case GroupNode():
        return _serializeGroup(
          node,
          activeSequenceId: activeSequenceId,
          cursor: cursor,
        );
      case SequenceNode():
        // Sequence 不應作為 child 直接出現；防禦性處理。
        return _serializeSequence(
          node,
          activeSequenceId: activeSequenceId,
          cursor: cursor,
        );
      default:
        // 未來新增的 node 型別預設以空內容呈現，避免 renderer error。
        return _kMinimumWidth;
    }
  }

  String _serializeNumber(
    NumberNode node, {
    required bool isInsideActiveNumber,
    required CursorPosition cursor,
  }) {
    if (!isInsideActiveNumber || node.value.isEmpty) {
      return node.value.isEmpty ? _kMinimumWidth : node.value;
    }

    final offset = (cursor.textOffset ?? 0).clamp(0, node.value.length);
    return '${node.value.substring(0, offset)}'
        '$_kCursorPlaceholder'
        '${node.value.substring(offset)}';
  }

  String _serializeFunction(
    FunctionNode node, {
    required NodeId activeSequenceId,
    required CursorPosition cursor,
  }) {
    final argumentTex = _serializeSequence(
      node.argument,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    return switch (node.function) {
      MathFunction.sin =>
        r'\sin\left('
            '$argumentTex'
            r'\right)',
      MathFunction.cos =>
        r'\cos\left('
            '$argumentTex'
            r'\right)',
      MathFunction.tan =>
        r'\tan\left('
            '$argumentTex'
            r'\right)',
      MathFunction.asin =>
        r'\sin^{-1}\left('
            '$argumentTex'
            r'\right)',
      MathFunction.acos =>
        r'\cos^{-1}\left('
            '$argumentTex'
            r'\right)',
      MathFunction.atan =>
        r'\tan^{-1}\left('
            '$argumentTex'
            r'\right)',
      MathFunction.log10 =>
        r'\log_{10}\left('
            '$argumentTex'
            r'\right)',
      MathFunction.ln =>
        r'\ln\left('
            '$argumentTex'
            r'\right)',
      MathFunction.absolute =>
        r'\left|'
            '$argumentTex'
            r'\right|',
    };
  }

  String _serializeFraction(
    FractionNode node, {
    required NodeId activeSequenceId,
    required CursorPosition cursor,
  }) {
    final numeratorTex = _serializeSequence(
      node.numerator,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    final denominatorTex = _serializeSequence(
      node.denominator,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    return '\\frac{$numeratorTex}{$denominatorTex}';
  }

  String _serializeRoot(
    RootNode node, {
    required NodeId activeSequenceId,
    required CursorPosition cursor,
  }) {
    final radicandTex = _serializeSequence(
      node.radicand,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    final degree = node.degree;
    if (degree == null) {
      return '\\sqrt{$radicandTex}';
    }
    final degreeTex = _serializeSequence(
      degree,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    return '\\sqrt[$degreeTex]{$radicandTex}';
  }

  String _serializePower(
    PowerNode node, {
    required NodeId activeSequenceId,
    required CursorPosition cursor,
  }) {
    final baseTex = _serializeSequence(
      node.base,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    final exponentTex = _serializeSequence(
      node.exponent,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    return '{$baseTex}^{$exponentTex}';
  }

  String _serializeLogarithm(
    LogarithmNode node, {
    required NodeId activeSequenceId,
    required CursorPosition cursor,
  }) {
    final baseTex = _serializeSequence(
      node.base,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    final argumentTex = _serializeSequence(
      node.argument,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    return '\\log_{$baseTex}\\left($argumentTex\\right)';
  }

  String _serializeMixedFraction(
    MixedFractionNode node, {
    required NodeId activeSequenceId,
    required CursorPosition cursor,
  }) {
    final wholeTex = _serializeSequence(
      node.whole,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    final numeratorTex = _serializeSequence(
      node.numerator,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    final denominatorTex = _serializeSequence(
      node.denominator,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    return '$wholeTex\\frac{$numeratorTex}{$denominatorTex}';
  }

  String _serializeScientific(
    ScientificNode node, {
    required NodeId activeSequenceId,
    required CursorPosition cursor,
  }) {
    final mantissaTex = _serializeSequence(
      node.mantissa,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    final exponentTex = _serializeSequence(
      node.exponent,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    return '$mantissaTex\\,E\\,$exponentTex';
  }

  String _serializeGroup(
    GroupNode node, {
    required NodeId activeSequenceId,
    required CursorPosition cursor,
  }) {
    final contentTex = _serializeSequence(
      node.content,
      activeSequenceId: activeSequenceId,
      cursor: cursor,
    );
    return r'\left('
        '$contentTex'
        r'\right)';
  }

  String _operatorTex(ExpressionOperator operator) {
    return switch (operator) {
      ExpressionOperator.add => '+',
      ExpressionOperator.subtract => '-',
      // 末尾空格：分隔巨集名，避免與後方字母 token（如常數 e）黏成未定義
      // 巨集（\timese）導致 Math renderer layout 失敗。空格為 LaTeX 標準巨集
      // 終止符，視覺與無空格一致。
      ExpressionOperator.multiply => r'\times ',
      ExpressionOperator.divide => r'\div ',
    };
  }

  String _constantTex(MathConstant constant) {
    return switch (constant) {
      // 同上：\pi 需以空格與後方字母 token 分隔。
      MathConstant.pi => r'\pi ',
      MathConstant.e => 'e',
      // \mathrm 而非 \operatorname：\operatorname 是 greedy function，會把
      // 緊接在後的 function token（如 hidden cursor marker \phantom{\vert}，
      // greediness 預設 1）視為自己的 argument 並拋出 ParseException，導致
      // 游標位於 Ans 後時閃爍失效帧、按 `=` 後整條算式消失。\mathrm 只吃
      // 自帶的 {Ans} 群組，不會吞後方 token，且同樣以直立體呈現。
      MathConstant.answer => r'\mathrm{Ans}',
    };
  }

  // visible / hidden cursor 的 placeholder。serialize 時先寫入 placeholder，
  // 最後分別替換成實際 marker，確保兩個版本結構完全一致。
  static const String _kCursorPlaceholder = '\uE000'; // private-use char

  static const String _kVisibleCursor = r'\vert';

  static const String _kHiddenCursor = r'\phantom{\vert}';

  static const String _kMinimumWidth = r'\phantom{0}';
}
