import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scientific_calculator/features/calculator/model/expression/cursor_position.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/constant_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/number_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/operator_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/sequence_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node_id.dart';
import 'package:scientific_calculator/features/calculator/model/expression/tree_expression_document.dart';
import 'package:scientific_calculator/features/calculator/service/tree_expression_tex_serializer.dart';

/// Serializer 輸出的 TeX 必須真的能被 `flutter_math_fork` 渲染。
///
/// 回歸背景：`Ans` 曾以 `\operatorname{Ans}` 序列化，其 greedy argument
/// parsing 會把緊接在後的 function token（hidden cursor marker
/// `\phantom{\vert}`）誤當成自己的 argument 並拋出 ParseException：
/// - 閃爍的「游標熄滅」帧落入 onErrorFallback，輸入欄不斷閃跳。
/// - 按 `=` 後（cursorVisible=false，兩版本均帶 hidden marker）整條算式消失。
void main() {
  const serializer = TreeExpressionTexSerializer();

  /// 建立 `44+1+Ans`，游標位於 [cursorIndex]（node boundary，5 = Ans 之後）。
  TreeExpressionDocument docWithCursorAfterAns({required int cursorIndex}) {
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
    return TreeExpressionDocument(
      root: root,
      cursor: CursorPosition(sequenceId: root.id, nodeOffset: cursorIndex),
    );
  }

  Future<bool> rendersWithoutFallback(WidgetTester tester, String tex) async {
    var usedFallback = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Math.tex(
            tex,
            onErrorFallback: (error) {
              usedFallback = true;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    return !usedFallback;
  }

  testWidgets('游標在 Ans 後：visible / hidden 兩幀皆可渲染', (tester) async {
    final result = serializer.serialize(docWithCursorAfterAns(cursorIndex: 5));
    expect(await rendersWithoutFallback(tester, result.withVisibleCursor),
        isTrue);
    expect(await rendersWithoutFallback(tester, result.withHiddenCursor),
        isTrue);
  });

  testWidgets('游標在 Ans 後、按 = 後（cursorVisible=false）：算式仍可渲染',
      (tester) async {
    final result = serializer.serialize(
      docWithCursorAfterAns(cursorIndex: 5),
      cursorVisible: false,
    );
    expect(
      await rendersWithoutFallback(tester, result.withHiddenCursor),
      isTrue,
    );
  });

  testWidgets('游標在 Ans 前：visible / hidden 兩幀皆可渲染', (tester) async {
    final result = serializer.serialize(docWithCursorAfterAns(cursorIndex: 4));
    expect(await rendersWithoutFallback(tester, result.withVisibleCursor),
        isTrue);
    expect(await rendersWithoutFallback(tester, result.withHiddenCursor),
        isTrue);
  });
}
