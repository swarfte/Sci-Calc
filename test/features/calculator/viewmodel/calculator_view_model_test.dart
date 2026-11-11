import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scientific_calculator/features/calculator/model/calculator_state.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/function_node.dart';
import 'package:scientific_calculator/features/calculator/model/expression/node/number_node.dart';
import 'package:scientific_calculator/features/calculator/viewmodel/calculator_providers.dart';
import 'package:scientific_calculator/features/calculator/viewmodel/calculator_view_model.dart';

/// Phase 6 ViewModel 測試：驗證 state transition 與 Tree services 接駁。
void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  CalculatorViewModel viewModel() =>
      container.read(calculatorViewModelProvider.notifier);

  CalculatorState state() => container.read(calculatorViewModelProvider);

  group('CalculatorViewModel digit input', () {
    test('連續輸入 123 合併為單一 NumberNode', () {
      viewModel().inputDigit('1');
      viewModel().inputDigit('2');
      viewModel().inputDigit('3');

      expect(state().document.root.children.length, 1);
      expect((state().document.root.children.first as NumberNode).value, '123');
    });

    test('計算後繼續輸入保留算式並清除結果', () {
      viewModel().inputDigit('1');
      viewModel().inputAdd();
      viewModel().inputDigit('2');
      viewModel().calculate();
      expect(state().result, isNotNull);

      // 繼續輸入：算式在原處延伸，舊結果清除。
      viewModel().inputDigit('3');
      expect(state().document.root.children.length, 3);
      expect(state().result, isNull);
    });
  });

  group('function navigation', () {
    test('插入函數後 cursor 進入 argument', () {
      viewModel().inputSin();

      final fn = state().document.root.children.first as FunctionNode;
      expect(fn.function, MathFunction.sin);
      // cursor 在 argument 開頭。
      expect(state().document.cursor.sequenceId, fn.argument.id);
      expect(state().document.cursor.nodeOffset, 0);
    });

    test('從 function argument 向右離開（sin(30) -> sin(30)|）', () {
      viewModel().inputSin();
      viewModel().inputDigit('3');
      viewModel().inputDigit('0');

      // cursor 在 NumberNode 30 的文字末端；單次向右即合併隱形中間步、
      // 直接離開 function 至 root。
      viewModel().moveRight();

      expect(state().document.cursor.sequenceId, state().document.root.id);
      expect(state().document.cursor.nodeOffset, 1);
    });
  });

  group('fraction', () {
    test('建立 fraction 並在 numerator/denominator 導航', () {
      viewModel().inputFraction();

      final frac = state().document.root.children.first;
      // 向下進 denominator，再向上回 numerator，結構不變。
      viewModel().moveDown();
      viewModel().moveUp();
      expect(state().document.root.children.first, same(frac));
    });
  });

  group('calculate', () {
    test('計算成功後 result 更新', () {
      viewModel().inputDigit('2');
      viewModel().inputAdd();
      viewModel().inputDigit('3');
      viewModel().calculate();

      expect(state().result, isNotNull);
      expect(state().result!.value, 5);
      expect(state().result!.formattedValue, '5');
      expect(state().answer, 5.0);
      expect(state().errorMessage, isNull);
    });

    test('計算失敗只更新 result error，不顯示於 expression', () {
      viewModel().inputDigit('1');
      viewModel().inputDivide();
      viewModel().inputDigit('0');
      viewModel().calculate();

      expect(state().errorMessage, isNotNull);
      expect(state().result, isNull);
    });

    test('計算失敗後繼續輸入清除 error', () {
      viewModel().inputDigit('1');
      viewModel().inputDivide();
      viewModel().inputDigit('0');
      viewModel().calculate();
      expect(state().errorMessage, isNotNull);

      // 繼續輸入（backspace）清除 error。
      viewModel().backspace();
      expect(state().errorMessage, isNull);
    });
  });

  group('clear', () {
    test('AC 清空 Tree 但保留 angle mode 與 answer', () {
      viewModel().inputDigit('2');
      viewModel().inputAdd();
      viewModel().inputDigit('3');
      viewModel().calculate();
      viewModel().toggleAngleMode();

      final modeBefore = state().angleMode;
      final answerBefore = state().answer;

      viewModel().clear();

      expect(state().document.root.children, isEmpty);
      expect(state().result, isNull);
      expect(state().errorMessage, isNull);
      // angle mode 與 answer 保留。
      expect(state().angleMode, modeBefore);
      expect(state().answer, answerBefore);
    });
  });
}
