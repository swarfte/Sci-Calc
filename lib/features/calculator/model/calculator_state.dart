import '../../../../core/math/angle_mode.dart';
import 'calculation_result.dart';
import 'expression/expression_document.dart';

/// 計算機的 UI 狀態。
///
/// Phase 6 後，算式只以 [document]（Expression Tree）表示，不再保存
/// evaluation string、TeX string、cursor offset 或 [FractionDraft]。分數、
/// 根式、指數等均為 Tree 中的正常 node。
class CalculatorState {
  const CalculatorState({
    required this.document,
    this.result,
    this.angleMode = AngleMode.degree,
    this.errorMessage,
    this.answer = 0,
  });

  /// 算式的 Expression Tree（唯一 source of truth）。
  final ExpressionDocument document;

  /// 上一次按 `=` 的計算結果。
  final CalculationResult? result;

  final AngleMode angleMode;

  /// 計算錯誤訊息；只在按 `=` 後出現於 ResultDisplay，繼續輸入後清除。
  final String? errorMessage;

  /// 上一個答案，供 `Ans` 常數使用；首次啟動預設為 `0`。
  final double answer;

  factory CalculatorState.initial() {
    return CalculatorState(document: ExpressionDocument.empty());
  }

  CalculatorState copyWith({
    ExpressionDocument? document,
    CalculationResult? result,
    AngleMode? angleMode,
    String? errorMessage,
    double? answer,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return CalculatorState(
      document: document ?? this.document,
      result: clearResult ? null : result ?? this.result,
      angleMode: angleMode ?? this.angleMode,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      answer: answer ?? this.answer,
    );
  }
}
