import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/constant_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/fraction_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/group_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/number_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/operator_node.dart';
import 'package:scientific_calculator/features/calculator/view/widgets/calculator_keyboard_listener.dart';
import 'package:scientific_calculator/features/calculator/viewmodel/calculator_providers.dart';
import 'package:scientific_calculator/features/calculator/viewmodel/calculator_view_model.dart';

/// 鍵盤處理器測試：驗證硬體鍵盤事件正確對應到 ViewModel 方法。
void main() {
  late ProviderContainer container;
  late CalculatorKeyboardHandler handler;

  setUp(() {
    container = ProviderContainer();
    final viewModel = container.read(calculatorViewModelProvider.notifier);
    handler = CalculatorKeyboardHandler(viewModel);
  });

  tearDown(() => container.dispose());

  CalculatorViewModel viewModel() =>
      container.read(calculatorViewModelProvider.notifier);

  /// 以 character + logicalKey 合成 KeyDownEvent，並回傳是否已處理。
  bool press({
    String? character,
    LogicalKeyboardKey logicalKey = LogicalKeyboardKey.space,
  }) {
    final event = KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.space,
      logicalKey: logicalKey,
      timeStamp: Duration.zero,
      character: character,
    );
    return handler.handle(event);
  }

  group('CalculatorKeyboardHandler 數字 / 小數點', () {
    test('0-9 對應 inputDigit', () {
      for (var d = 0; d <= 9; d++) {
        press(character: d.toString());
      }
      final node =
          viewModel().state.document.root.children.first as NumberNode;
      expect(node.value, '0123456789');
    });

    test('Numpad 數字（無 character）也能輸入', () {
      // 模擬部份瀏覽器不產生 character 的 numpad。
      press(logicalKey: LogicalKeyboardKey(0x31)); // '1'
      press(logicalKey: LogicalKeyboardKey(0x32)); // '2'
      press(logicalKey: LogicalKeyboardKey(0x33)); // '3'
      final node =
          viewModel().state.document.root.children.first as NumberNode;
      expect(node.value, '123');
    });

    test('. 輸入小數點', () {
      press(character: '1');
      press(character: '.');
      press(character: '5');
      final node =
          viewModel().state.document.root.children.first as NumberNode;
      expect(node.value, '1.5');
    });
  });

  group('CalculatorKeyboardHandler 四則運算', () {
    test('+ - * / 各自對應正確 operator', () {
      press(character: '1');
      press(character: '+');
      expect(
        (viewModel().state.document.root.children[1] as OperatorNode)
            .operator,
        ExpressionOperator.add,
      );

      viewModel().clear();
      press(character: '1');
      press(character: '-');
      expect(
        (viewModel().state.document.root.children[1] as OperatorNode)
            .operator,
        ExpressionOperator.subtract,
      );

      viewModel().clear();
      press(character: '1');
      press(character: '*');
      expect(
        (viewModel().state.document.root.children[1] as OperatorNode)
            .operator,
        ExpressionOperator.multiply,
      );

      viewModel().clear();
      press(character: '1');
      press(character: '/');
      expect(
        (viewModel().state.document.root.children[1] as OperatorNode)
            .operator,
        ExpressionOperator.divide,
      );
    });

    test('x 與 X 也對應乘法', () {
      press(character: '2');
      press(character: 'x');
      expect(
        (viewModel().state.document.root.children[1] as OperatorNode)
            .operator,
        ExpressionOperator.multiply,
      );
    });
  });

  group('CalculatorKeyboardHandler 括號 / 常數 / 分數', () {
    test('( 與 ) 建立 Group', () {
      press(character: '(');
      expect(
        viewModel().state.document.root.children.first,
        isA<GroupNode>(),
      );

      viewModel().clear();
      press(character: ')');
      expect(
        viewModel().state.document.root.children.first,
        isA<GroupNode>(),
      );
    });

    test('e 對應歐拉數常數', () {
      press(character: 'e');
      final node = viewModel().state.document.root.children.first;
      expect(node, isA<ConstantNode>());
      expect((node as ConstantNode).constant, MathConstant.e);
    });

    test('p 對應 π 常數', () {
      press(character: 'p');
      final node = viewModel().state.document.root.children.first;
      expect(node, isA<ConstantNode>());
      expect((node as ConstantNode).constant, MathConstant.pi);
    });

    test('? 對應分數 a/b', () {
      press(character: '?');
      expect(
        viewModel().state.document.root.children.first,
        isA<FractionNode>(),
      );
    });
  });

  group('CalculatorKeyboardHandler 計算 / 編輯鍵', () {
    test('= 觸發 calculate', () {
      press(character: '2');
      press(character: '+');
      press(character: '3');
      press(character: '=');
      expect(viewModel().state.result?.value, 5);
    });

    test('Enter 觸發 calculate', () {
      press(character: '2');
      press(character: '+');
      press(character: '3');
      press(logicalKey: LogicalKeyboardKey.enter);
      expect(viewModel().state.result?.value, 5);
    });

    test('Backspace 觸發 backspace', () {
      press(character: '1');
      press(character: '2');
      expect(
        (viewModel().state.document.root.children.first as NumberNode).value,
        '12',
      );
      press(logicalKey: LogicalKeyboardKey.backspace);
      expect(
        (viewModel().state.document.root.children.first as NumberNode).value,
        '1',
      );
    });

    test('Escape 觸發 clear', () {
      press(character: '1');
      press(character: '+');
      press(logicalKey: LogicalKeyboardKey.escape);
      expect(viewModel().state.document.root.children, isEmpty);
    });
  });

  group('CalculatorKeyboardHandler 方向鍵', () {
    test('方向鍵不輸入新 node，只移動游標', () {
      press(character: '1');
      press(character: '+');
      press(character: '2');

      final countBefore = viewModel().state.document.root.children.length;
      press(logicalKey: LogicalKeyboardKey.arrowLeft);
      press(logicalKey: LogicalKeyboardKey.arrowRight);
      press(logicalKey: LogicalKeyboardKey.arrowUp);
      press(logicalKey: LogicalKeyboardKey.arrowDown);
      expect(
        viewModel().state.document.root.children.length,
        countBefore,
      );
    });
  });

  group('CalculatorKeyboardHandler 未對應的鍵', () {
    test('未對應的字元回傳 false（例如 q）', () {
      final result = handler.handle(
        KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyQ,
          logicalKey: LogicalKeyboardKey.keyQ,
          timeStamp: Duration.zero,
          character: 'q',
        ),
      );
      expect(result, isFalse);
      expect(viewModel().state.document.root.children, isEmpty);
    });

    test('非 KeyDownEvent（如 KeyRepeatEvent）不處理', () {
      final event = KeyRepeatEvent(
        physicalKey: PhysicalKeyboardKey.digit1,
        logicalKey: LogicalKeyboardKey.digit1,
        timeStamp: Duration.zero,
        character: '1',
      );
      expect(handler.handle(event), isFalse);
    });
  });
}
