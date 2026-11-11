import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/always_on_top_settings.dart';
import '../../../../app/result_format_settings.dart';
import '../viewmodel/calculator_providers.dart';
import 'calculator_keyboard_input_enabled_provider.dart';
import 'widgets/calculator_keypad.dart';
import 'widgets/calculator_keyboard_listener.dart';
import 'widgets/mode_indicator.dart';
import 'widgets/natural_math_display.dart';
import 'widgets/pin_button.dart';
import 'widgets/result_display.dart';
import 'widgets/result_format_indicator.dart';
import 'widgets/settings_button.dart';

class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorViewModelProvider);
    final viewModel = ref.read(calculatorViewModelProvider.notifier);
    final serializer = ref.watch(treeExpressionTexSerializerProvider);
    final resultFormat = ref.watch(resultFormatSettingsProvider);

    // TeX 完全由 Tree Serializer 產生；游標恆常閃爍，指示下一個輸入位置。
    final texResult = serializer.serialize(state.document);

    // 釘選 (always-on-top) 只在桌面平台提供。
    final isDesktop = ref.watch(isDesktopPlatformProvider);

    // 硬體鍵盤輸入只在桌面 / 瀏覽器啟用。
    final isKeyboardInputEnabled = ref.watch(isKeyboardInputEnabledProvider);

    return CalculatorKeyboardListener(
      enabled: isKeyboardInputEnabled,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sci Calc'),
          centerTitle: false,
          actions: [
            if (isDesktop) const PinButton(),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ModeIndicator(
                angleMode: state.angleMode,
                onPressed: viewModel.toggleAngleMode,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ResultFormatIndicator(
                resultFormat: resultFormat,
                onPressed: viewModel.toggleResultFormat,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: SettingsButton(),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          NaturalMathDisplay(
                            tex: texResult.withHiddenCursor,
                            texWithCursor: texResult.withVisibleCursor,
                          ),
                          const Divider(height: 1),
                          ResultDisplay(
                            result: state.result?.formattedValue,
                            errorMessage: state.errorMessage,
                            tex: state.result?.formattedTex,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: CalculatorKeypad(
                        onDigit: viewModel.inputDigit,
                        onDecimal: viewModel.inputDecimalPoint,
                        onAdd: viewModel.inputAdd,
                        onSubtract: viewModel.inputSubtract,
                        onMultiply: viewModel.inputMultiply,
                        onDivide: viewModel.inputDivide,
                        onOpenParenthesis: viewModel.inputOpenGroup,
                        onCloseParenthesis: viewModel.inputCloseGroup,
                        onSquare: viewModel.inputSquare,
                        onPower: viewModel.inputPower,
                        onSquareRoot: viewModel.inputSquareRoot,
                        onNthRoot: viewModel.inputNthRoot,
                        onSin: viewModel.inputSin,
                        onCos: viewModel.inputCos,
                        onTan: viewModel.inputTan,
                        onArcSin: viewModel.inputArcSin,
                        onArcCos: viewModel.inputArcCos,
                        onArcTan: viewModel.inputArcTan,
                        onLog10: viewModel.inputLog10,
                        onLogarithm: viewModel.inputLogarithm,
                        onLogarithmBase2: viewModel.inputLogarithmBase2,
                        onLn: viewModel.inputLn,
                        onPi: viewModel.inputPi,
                        onEulerNumber: viewModel.inputEulerNumber,
                        onBackspace: viewModel.backspace,
                        onClear: viewModel.clear,
                        onCalculate: viewModel.calculate,
                        onFraction: viewModel.inputFraction,
                        onMixedFraction: viewModel.inputMixedFraction,
                        onScientific: viewModel.inputScientific,
                        onAnswer: viewModel.inputAnswer,
                        onMoveUp: viewModel.moveUp,
                        onMoveDown: viewModel.moveDown,
                        onMoveLeft: viewModel.moveLeft,
                        onMoveRight: viewModel.moveRight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
