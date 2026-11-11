import 'package:flutter_test/flutter_test.dart';
import 'package:scientific_calculator/features/calculator/model/expression/cursor_position.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/constant_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/fraction_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/function_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/group_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/number_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/operator_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/power_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/root_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/sequence_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node_id.dart';
import 'package:scientific_calculator/features/calculator/model/expression/tree_expression_document.dart';
import 'package:scientific_calculator/features/calculator/service/tree_expression_tex_serializer.dart';

/// Phase 3 serializer 測試。
///
/// 驗證所有 MVP node 的 TeX 輸出、空 sequence 占位、cursor 位置，
/// 以及 visible / hidden cursor 的等寬結構。
void main() {
  const serializer = TreeExpressionTexSerializer();

  /// 便利：取得 visible 版的 TeX。
  String visibleTex(TreeExpressionDocument doc) =>
      serializer.serialize(doc).withVisibleCursor;

  /// 便利：取得 hidden 版的 TeX。
  String hiddenTex(TreeExpressionDocument doc) =>
      serializer.serialize(doc).withHiddenCursor;

  group('basic node serialization (no cursor)', () {
    test('2 + 3 -> 2+3', () {
      final doc = docOf(
        SequenceNode(
          id: NodeId.generate(),
          children: [
            NumberNode.create('2'),
            OperatorNode.create(ExpressionOperator.add),
            NumberNode.create('3'),
          ],
        ),
      );
      // cursor 在 root 末端（gap mode），仍會插入 marker；先確認主體。
      expect(visibleTex(doc), contains('2+3'));
    });

    test('multiply / divide operators', () {
      final doc = docOf(
        SequenceNode(
          id: NodeId.generate(),
          children: [
            NumberNode.create('6'),
            OperatorNode.create(ExpressionOperator.multiply),
            NumberNode.create('3'),
            OperatorNode.create(ExpressionOperator.divide),
            NumberNode.create('2'),
          ],
        ),
      );
      final tex = visibleTex(doc);
      // 巨集後以空格分隔（見 _operatorTex 註釋）。
      expect(tex, contains(r'6\times 3\div 2'));
    });

    test('operators 接常數 e 不黏成未定義巨集（回歸）', () {
      for (final op in [
        ExpressionOperator.multiply,
        ExpressionOperator.divide,
      ]) {
        final doc = docOf(
          SequenceNode(
            id: NodeId.generate(),
            children: [
              NumberNode.create('13'),
              OperatorNode.create(op),
              ConstantNode.create(MathConstant.e),
            ],
          ),
        );
        final tex = hiddenTex(doc);
        switch (op) {
          case ExpressionOperator.multiply:
            expect(tex, contains(r'13\times e'));
            expect(tex, isNot(contains(r'\timese')));
          case ExpressionOperator.divide:
            expect(tex, contains(r'13\div e'));
            expect(tex, isNot(contains(r'\dive')));
          default:
            fail('unexpected operator $op');
        }
      }
    });

    test('pi 接常數 e 不黏成未定義巨集（回歸）', () {
      final doc = docOf(
        SequenceNode(
          id: NodeId.generate(),
          children: [
            ConstantNode.create(MathConstant.pi),
            ConstantNode.create(MathConstant.e),
          ],
        ),
      );
      final tex = hiddenTex(doc);
      expect(tex, contains(r'\pi e'));
      expect(tex, isNot(contains(r'\pie')));
    });

    test('constants pi / e / Ans', () {
      final doc = docOf(
        SequenceNode(
          id: NodeId.generate(),
          children: [
            ConstantNode.create(MathConstant.pi),
            ConstantNode.create(MathConstant.e),
            ConstantNode.create(MathConstant.answer),
          ],
        ),
      );
      final tex = hiddenTex(doc);
      // \pi 與 e 必須為相異 token（不黏成 \pie）。
      expect(tex, contains(r'\pi e'));
      expect(tex, contains(r'\mathrm{Ans}'));
    });

    test(r'游標緊接 Ans 後：hidden marker 不被 \operatorname 吞掉（回歸）', () {
      // 回歸背景：\operatorname{Ans} 後直接跟 \phantom{\vert}（hidden cursor
      // marker）時，\operatorname 的 greedy argument parsing 會拋出
      // ParseException，導致閃爍 fallback、按 = 後算式消失。改用 \mathrm 後，
      // 兩個 cursor 版本都必須保持 \mathrm{Ans} 完整、且後方 marker 不變形。
      final root = SequenceNode(
        id: NodeId.generate(),
        children: [
          NumberNode.create('44'),
          OperatorNode.create(ExpressionOperator.add),
          NumberNode.create('1'),
          OperatorNode.create(ExpressionOperator.add),
          ConstantNode.create(MathConstant.answer),
        ],
      );
      final doc = TreeExpressionDocument(
        root: root,
        cursor: CursorPosition(sequenceId: root.id, nodeOffset: 5),
      );

      final result = serializer.serialize(doc);
      expect(result.withVisibleCursor, contains(r'\mathrm{Ans}\vert'));
      expect(result.withHiddenCursor, contains(r'\mathrm{Ans}\phantom{\vert}'));
      // 不應再出現會吞掉後方 function token 的 \operatorname 形式。
      expect(result.withVisibleCursor, isNot(contains(r'\operatorname')));
      expect(result.withHiddenCursor, isNot(contains(r'\operatorname')));
    });
  });

  group('function serialization', () {
    test('sin(30) -> \\sin\\left(30\\right)', () {
      final argument = SequenceNode(
        id: NodeId.generate(),
        children: [NumberNode.create('30')],
      );
      final function = FunctionNode(
        id: NodeId.generate(),
        function: MathFunction.sin,
        argument: argument,
      );
      final doc = docOf(
        SequenceNode(id: NodeId.generate(), children: [function]),
      );
      expect(hiddenTex(doc), contains(r'\sin\left(30\right)'));
    });

    test('log10(100) -> \\log_{10}\\left(100\\right)', () {
      final argument = SequenceNode(
        id: NodeId.generate(),
        children: [NumberNode.create('100')],
      );
      final function = FunctionNode(
        id: NodeId.generate(),
        function: MathFunction.log10,
        argument: argument,
      );
      final doc = docOf(
        SequenceNode(id: NodeId.generate(), children: [function]),
      );
      expect(hiddenTex(doc), contains(r'\log_{10}\left(100\right)'));
    });

    test('asin uses ^{-1} notation', () {
      final function = FunctionNode(
        id: NodeId.generate(),
        function: MathFunction.asin,
        argument: SequenceNode(
          id: NodeId.generate(),
          children: [NumberNode.create('1')],
        ),
      );
      final doc = docOf(
        SequenceNode(id: NodeId.generate(), children: [function]),
      );
      expect(hiddenTex(doc), contains(r'\sin^{-1}\left(1\right)'));
    });

    test('abs uses \\left|...\\right|', () {
      final function = FunctionNode(
        id: NodeId.generate(),
        function: MathFunction.absolute,
        argument: SequenceNode(
          id: NodeId.generate(),
          children: [NumberNode.create('-5')],
        ),
      );
      final doc = docOf(
        SequenceNode(id: NodeId.generate(), children: [function]),
      );
      expect(hiddenTex(doc), contains(r'\left|-5\right|'));
    });

    test('empty function argument 使用 phantom 占位', () {
      final function = FunctionNode.create(MathFunction.sin);
      final doc = docOf(
        SequenceNode(id: NodeId.generate(), children: [function]),
      );
      // argument 空、非 active -> \phantom{0}
      expect(hiddenTex(doc), contains(r'\sin\left(\phantom{0}\right)'));
    });
  });

  group('root / fraction / power serialization', () {
    test('sqrt(2) -> \\sqrt{2}', () {
      final root = RootNode(
        id: NodeId.generate(),
        radicand: SequenceNode(
          id: NodeId.generate(),
          children: [NumberNode.create('2')],
        ),
      );
      final doc = docOf(SequenceNode(id: NodeId.generate(), children: [root]));
      expect(hiddenTex(doc), contains(r'\sqrt{2}'));
    });

    test('nth root -> \\sqrt[degree]{radicand}', () {
      final root = RootNode(
        id: NodeId.generate(),
        radicand: SequenceNode(
          id: NodeId.generate(),
          children: [NumberNode.create('8')],
        ),
        degree: SequenceNode(
          id: NodeId.generate(),
          children: [NumberNode.create('3')],
        ),
      );
      final doc = docOf(SequenceNode(id: NodeId.generate(), children: [root]));
      expect(hiddenTex(doc), contains(r'\sqrt[3]{8}'));
    });

    test('sqrt(2)/sqrt(3) -> \\frac{\\sqrt{2}}{\\sqrt{3}}', () {
      final fraction = FractionNode(
        id: NodeId.generate(),
        numerator: SequenceNode(
          id: NodeId.generate(),
          children: [
            RootNode(
              id: NodeId.generate(),
              radicand: SequenceNode(
                id: NodeId.generate(),
                children: [NumberNode.create('2')],
              ),
            ),
          ],
        ),
        denominator: SequenceNode(
          id: NodeId.generate(),
          children: [
            RootNode(
              id: NodeId.generate(),
              radicand: SequenceNode(
                id: NodeId.generate(),
                children: [NumberNode.create('3')],
              ),
            ),
          ],
        ),
      );
      final doc = docOf(
        SequenceNode(id: NodeId.generate(), children: [fraction]),
      );
      expect(hiddenTex(doc), contains(r'\frac{\sqrt{2}}{\sqrt{3}}'));
    });

    test('5^(3/2) -> {5}^{\\frac{3}{2}}', () {
      final power = PowerNode(
        id: NodeId.generate(),
        base: SequenceNode(
          id: NodeId.generate(),
          children: [NumberNode.create('5')],
        ),
        exponent: SequenceNode(
          id: NodeId.generate(),
          children: [
            FractionNode(
              id: NodeId.generate(),
              numerator: SequenceNode(
                id: NodeId.generate(),
                children: [NumberNode.create('3')],
              ),
              denominator: SequenceNode(
                id: NodeId.generate(),
                children: [NumberNode.create('2')],
              ),
            ),
          ],
        ),
      );
      final doc = docOf(SequenceNode(id: NodeId.generate(), children: [power]));
      expect(hiddenTex(doc), contains(r'{5}^{\frac{3}{2}}'));
    });

    test('group -> \\left(content\\right)', () {
      final group = GroupNode(
        id: NodeId.generate(),
        content: SequenceNode(
          id: NodeId.generate(),
          children: [
            NumberNode.create('2'),
            OperatorNode.create(ExpressionOperator.add),
            NumberNode.create('3'),
          ],
        ),
      );
      final doc = docOf(SequenceNode(id: NodeId.generate(), children: [group]));
      expect(hiddenTex(doc), contains(r'\left(2+3\right)'));
    });
  });

  group('empty sequence placeholders', () {
    test('空 root 仍顯示占位寬度', () {
      final root = SequenceNode.empty();
      final doc = TreeExpressionDocument(
        root: root,
        cursor: CursorPosition(sequenceId: root.id, nodeOffset: 0),
      );
      expect(hiddenTex(doc), contains(r'\phantom{0}'));
    });

    test('空 fraction 的 numerator 與 denominator 均占位', () {
      final fraction = FractionNode.empty();
      final doc = docOf(
        SequenceNode(id: NodeId.generate(), children: [fraction]),
      );
      expect(hiddenTex(doc), contains(r'\frac{\phantom{0}}{\phantom{0}}'));
    });
  });

  group('cursor placement', () {
    test('cursor 在 NumberNode 內 textOffset=1 -> 1\\vert23', () {
      final number = NumberNode.create('123');
      final root = SequenceNode(id: NodeId.generate(), children: [number]);
      final doc = TreeExpressionDocument(
        root: root,
        cursor: CursorPosition(
          sequenceId: root.id,
          nodeOffset: 0,
          textOffset: 1,
        ),
      );
      expect(visibleTex(doc), '1\\vert23');
    });

    test('sin(30|) 與 sin(30)| 輸出不同且位置正確', () {
      final argument = SequenceNode(
        id: NodeId.generate(),
        children: [NumberNode.create('30')],
      );
      final function = FunctionNode(
        id: NodeId.generate(),
        function: MathFunction.sin,
        argument: argument,
      );
      final root = SequenceNode(id: NodeId.generate(), children: [function]);

      // cursor 在 argument 末端（30 後）。
      final inside = TreeExpressionDocument(
        root: root,
        cursor: CursorPosition(sequenceId: argument.id, nodeOffset: 1),
      );
      final insideTex = visibleTex(inside);
      expect(insideTex, contains(r'\sin\left(30\vert\right)'));

      // cursor 在 root、function 後方。
      final outside = TreeExpressionDocument(
        root: root,
        cursor: CursorPosition(sequenceId: root.id, nodeOffset: 1),
      );
      final outsideTex = visibleTex(outside);
      expect(outsideTex, contains(r'\sin\left(30\right)\vert'));

      expect(insideTex, isNot(equals(outsideTex)));
    });

    test('分子游標只出現在 numerator', () {
      final numerator = SequenceNode(
        id: NodeId.generate(),
        children: [NumberNode.create('1')],
      );
      final denominator = SequenceNode(
        id: NodeId.generate(),
        children: [NumberNode.create('2')],
      );
      final fraction = FractionNode(
        id: NodeId.generate(),
        numerator: numerator,
        denominator: denominator,
      );
      final root = SequenceNode(id: NodeId.generate(), children: [fraction]);
      final doc = TreeExpressionDocument(
        root: root,
        cursor: CursorPosition(sequenceId: numerator.id, nodeOffset: 1),
      );
      final tex = visibleTex(doc);
      expect(tex, contains(r'\frac{1\vert}{2}'));
    });

    test('分母游標只出現在 denominator', () {
      final numerator = SequenceNode(
        id: NodeId.generate(),
        children: [NumberNode.create('1')],
      );
      final denominator = SequenceNode(
        id: NodeId.generate(),
        children: [NumberNode.create('2')],
      );
      final fraction = FractionNode(
        id: NodeId.generate(),
        numerator: numerator,
        denominator: denominator,
      );
      final root = SequenceNode(id: NodeId.generate(), children: [fraction]);
      final doc = TreeExpressionDocument(
        root: root,
        cursor: CursorPosition(sequenceId: denominator.id, nodeOffset: 1),
      );
      final tex = visibleTex(doc);
      expect(tex, contains(r'\frac{1}{2\vert}'));
    });
  });

  group('visible / hidden cursor width stability', () {
    test('兩版本只差在 cursor marker，其餘完全相同', () {
      final number = NumberNode.create('123');
      final root = SequenceNode(id: NodeId.generate(), children: [number]);
      final doc = TreeExpressionDocument(
        root: root,
        cursor: CursorPosition(
          sequenceId: root.id,
          nodeOffset: 0,
          textOffset: 1,
        ),
      );

      final result = serializer.serialize(doc);
      // visible: 1\vert23, hidden: 1\phantom{\vert}23
      expect(result.withVisibleCursor, '1\\vert23');
      expect(result.withHiddenCursor, r'1\phantom{\vert}23');
    });

    test('空 active sequence 兩版本均含 phantom 占位寬度', () {
      final root = SequenceNode.empty();
      final doc = TreeExpressionDocument(
        root: root,
        cursor: CursorPosition(sequenceId: root.id, nodeOffset: 0),
      );
      final result = serializer.serialize(doc);
      expect(result.withVisibleCursor, r'\vert\phantom{0}');
      expect(result.withHiddenCursor, r'\phantom{\vert}\phantom{0}');
    });

    test(r'hidden 版不應出現未被包在 \phantom 內的獨立 \vert', () {
      final number = NumberNode.create('5');
      final root = SequenceNode(id: NodeId.generate(), children: [number]);
      final doc = TreeExpressionDocument(
        root: root,
        cursor: CursorPosition(sequenceId: root.id, nodeOffset: 1),
      );
      final result = serializer.serialize(doc);
      expect(result.withHiddenCursor, contains(r'\phantom{\vert}'));
      // 移除所有 \phantom{\vert} 後不應殘留任何 \vert
      //（即每個 \vert 都被包在 \phantom 內，例如不該出現末尾 \vert5）。
      final stripped = result.withHiddenCursor.replaceAll(
        r'\phantom{\vert}',
        '',
      );
      expect(stripped, isNot(contains(r'\vert')));
    });
  });
}

/// 以給定 root 建立 document，cursor 預設在 root 結尾（hidden 測試用）。
TreeExpressionDocument docOf(SequenceNode root) {
  return TreeExpressionDocument(
    root: root,
    cursor: CursorPosition(
      sequenceId: root.id,
      nodeOffset: root.children.length,
    ),
  );
}
