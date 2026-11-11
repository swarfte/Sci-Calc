import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/result_format_settings.dart';
import '../../../core/errors/calculator_exception.dart';
import '../../../core/math/angle_mode.dart';
import '../model/calculator_state.dart';
import '../model/expression/expression_document.dart';
import '../model/expression/node/constant_node.dart';
import '../model/expression/node/function_node.dart';
import '../model/expression/node/operator_node.dart';
import '../service/expression_navigator.dart';
import '../service/tree_calculator_engine.dart';
import '../service/tree_expression_editor.dart';
import 'calculator_providers.dart';

/// 計算機 ViewModel。
///
/// 所有按鍵 intent 都轉發至 Tree services：
/// - 輸入類（數字、運算符、函數、分數、根號、指數、群組）-> [TreeExpressionEditor]
/// - 方向鍵 -> [ExpressionNavigator]
/// - `=` -> [TreeCalculatorEngine]
///
/// ViewModel 不建立 TeX、不持有 BuildContext、不操作 Widget、不直接修改 Tree。
class CalculatorViewModel extends Notifier<CalculatorState> {
  late final TreeExpressionEditor _editor;
  late final ExpressionNavigator _navigator;
  late final TreeCalculatorEngine _engine;

  @override
  CalculatorState build() {
    _editor = ref.read(treeExpressionEditorProvider);
    _navigator = ref.read(expressionNavigatorProvider);
    _engine = ref.read(treeCalculatorEngineProvider);
    return CalculatorState.initial();
  }

  // ---- 數字 / 小數點 -------------------------------------------------------

  void inputDigit(String digit) {
    _edit((doc) => _editor.insertDigit(doc, digit));
  }

  void inputDecimalPoint() {
    _edit(_editor.insertDecimalPoint);
  }

  // ---- 運算符 -------------------------------------------------------------

  void inputAdd() {
    _inputOperator(ExpressionOperator.add);
  }

  void inputSubtract() {
    _inputOperator(ExpressionOperator.subtract);
  }

  void inputMultiply() {
    _inputOperator(ExpressionOperator.multiply);
  }

  void inputDivide() {
    _inputOperator(ExpressionOperator.divide);
  }

  void _inputOperator(ExpressionOperator operator) {
    _edit((doc) => _editor.insertOperator(doc, operator));
  }

  // ---- 函數 ---------------------------------------------------------------

  void inputSin() {
    _inputFunction(MathFunction.sin);
  }

  void inputCos() {
    _inputFunction(MathFunction.cos);
  }

  void inputTan() {
    _inputFunction(MathFunction.tan);
  }

  void inputArcSin() {
    _inputFunction(MathFunction.asin);
  }

  void inputArcCos() {
    _inputFunction(MathFunction.acos);
  }

  void inputArcTan() {
    _inputFunction(MathFunction.atan);
  }

  void inputLog10() {
    _inputFunction(MathFunction.log10);
  }

  void inputLn() {
    _inputFunction(MathFunction.ln);
  }

  void _inputFunction(MathFunction function) {
    _edit((doc) => _editor.insertFunction(doc, function));
  }

  // ---- 常數 ---------------------------------------------------------------

  void inputPi() {
    _inputConstant(MathConstant.pi);
  }

  void inputEulerNumber() {
    _inputConstant(MathConstant.e);
  }

  void inputAnswer() {
    _inputConstant(MathConstant.answer);
  }

  void _inputConstant(MathConstant constant) {
    _edit((doc) => _editor.insertConstant(doc, constant));
  }

  // ---- 結構 node ----------------------------------------------------------

  void inputFraction() {
    _edit(_editor.insertFraction);
  }

  void inputSquareRoot() {
    _edit(_editor.insertSquareRoot);
  }

  void inputNthRoot() {
    _edit(_editor.insertNthRoot);
  }

  void inputPower() {
    _edit(_editor.insertPower);
  }

  void inputSquare() {
    _edit(_editor.insertSquare);
  }

  void inputLogarithm() {
    _edit(_editor.insertLogarithm);
  }

  void inputLogarithmBase2() {
    _edit(_editor.insertLogarithmBase2);
  }

  void inputMixedFraction() {
    _edit(_editor.insertMixedFraction);
  }

  void inputScientific() {
    _edit(_editor.insertScientific);
  }

  /// `(` 鍵：建立群組。
  void inputOpenGroup() {
    _edit(_editor.insertGroup);
  }

  /// `)` 鍵：Tree 模型沒有「關閉群組」操作（離開群組由方向鍵處理）。
  ///
  /// 為保留既有 keypad 行為，這裡也建立新群組，與 `(` 行為一致。
  void inputCloseGroup() {
    _edit(_editor.insertGroup);
  }

  // ---- 方向鍵 -------------------------------------------------------------

  void moveLeft() {
    _move(_navigator.moveLeft);
  }

  void moveRight() {
    _move(_navigator.moveRight);
  }

  void moveUp() {
    _move(_navigator.moveUp);
  }

  void moveDown() {
    _move(_navigator.moveDown);
  }

  // ---- Backspace / Clear --------------------------------------------------

  void backspace() {
    _edit(_editor.backspace, preserveResult: true);
  }

  void clear() {
    // AC 清空 Tree 與結果，但保留 angle mode。
    state = CalculatorState.initial().copyWith(
      angleMode: state.angleMode,
      answer: state.answer,
    );
  }

  // ---- 計算 ---------------------------------------------------------------

  void calculate() {
    _evaluate(document: state.document);
  }

  /// 以給定 [document] 求值，並更新 state（成功時放入結果、清錯誤）。
  void _evaluate({required ExpressionDocument document}) {
    final resultFormat = ref.read(resultFormatSettingsProvider);
    try {
      final result = _engine.evaluate(
        document.root,
        angleMode: state.angleMode,
        answer: state.answer,
        resultFormat: resultFormat,
      );
      state = state.copyWith(
        result: result,
        answer: result.value.toDouble(),
        clearError: true,
      );
    } on CalculatorException catch (error) {
      state = state.copyWith(
        errorMessage: error.message,
        clearResult: true,
      );
    }
  }

  // ---- 角度模式 -----------------------------------------------------------

  void toggleAngleMode() {
    final nextMode = state.angleMode == AngleMode.degree
        ? AngleMode.radian
        : AngleMode.degree;
    state = state.copyWith(angleMode: nextMode, clearError: true);
  }

  // ---- 結果顯示格式 -------------------------------------------------------

  /// 切換 DEC / FRAC 顯示格式。
  ///
  /// 切換後若目前已有結果，會以新格式重新求值同一算式，讓顯示即時更新，
  /// 不需要再按一次 `=`。
  Future<void> toggleResultFormat() async {
    final current = ref.read(resultFormatSettingsProvider);
    final next = current == ResultFormatPreference.decimal
        ? ResultFormatPreference.fraction
        : ResultFormatPreference.decimal;
    await ref.read(resultFormatSettingsProvider.notifier).set(next);

    // 若已有結果，以新格式重新求值。錯誤狀態（errorMessage）不重新計算。
    if (state.result != null && state.errorMessage == null) {
      _evaluate(document: state.document);
    }
  }

  // ---- helpers ------------------------------------------------------------

  /// 套用一個會修改 document 的編輯操作，並清除結果／錯誤。
  ///
  /// [preserveResult] 為 `true` 時（例如 backspace）保留舊結果，僅清錯誤。
  void _edit(
    ExpressionDocument Function(ExpressionDocument document) action, {
    bool preserveResult = false,
  }) {
    final nextDocument = action(state.document);
    state = state.copyWith(
      document: nextDocument,
      clearResult: !preserveResult,
      clearError: true,
    );
  }

  /// 套用一個只移動游標的導航操作，並清除錯誤。
  void _move(ExpressionDocument Function(ExpressionDocument document) action) {
    final nextDocument = action(state.document);
    state = state.copyWith(document: nextDocument, clearError: true);
  }
}
