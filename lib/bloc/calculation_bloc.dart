import 'dart:async';
import 'dart:developer';

import 'package:calculator/bloc/calculation_state.dart';
import 'package:calculator/bloc/calculation_event.dart';
import 'package:calculator/calculation_model.dart';
import 'package:calculator/services/calculation_history_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

export 'calculation_event.dart';
export 'calculation_state.dart';

class CalculationBloc extends Bloc<CalculationEvent, CalculationState> {
  CalculationBloc({required this.calculationHistoryService})
      : super(CalculationInitial()) {
    on<NumberPressed>(_onNumberPressed);
    on<OperatorPressed>(_onOperatorPressed);
    on<CalculateResult>(_onCalculateResult);
    on<ClearCalculation>(_onClearCalculation);
    on<FetchHistory>(_onFetchHistory);
  }

  final CalculationHistoryService calculationHistoryService;

  Future<void> _onNumberPressed(NumberPressed event, Emitter<CalculationState> emit) async {
    final CalculationModel model = state.calculationModel;

    if (model.result != null) {
      final CalculationModel newModel = model.copyWith(
        firstOperand: event.number,
        // result: () => null
      );

      emit(CalculationChanged(
        calculationModel: newModel,
        history: List.of(state.history),
      ));
      return;
    }

    if (model.firstOperand == null) {
      final CalculationModel newModel = model.copyWith(firstOperand: event.number);

      emit(CalculationChanged(
        calculationModel: newModel,
        history: List.of(state.history),
      ));
      return;
    }

    if (model.operator == null) {
      final CalculationModel newModel = model.copyWith(
        firstOperand: int.parse('${model.firstOperand}${event.number}'),
      );

      emit(CalculationChanged(
        calculationModel: newModel,
        history: List.of(state.history),
      ));
      return;
    }

    if (model.secondOperand == null) {
      final CalculationModel newModel = model.copyWith(secondOperand: event.number);

      emit(CalculationChanged(
        calculationModel: newModel,
        history: List.of(state.history),
      ));
      return;
    }

    emit(CalculationChanged(
      calculationModel: model.copyWith(
        secondOperand: int.parse('${model.secondOperand}${event.number}'),
      ),
      history: List.of(state.history),
    ));
  }

  Future<void> _onOperatorPressed(OperatorPressed event, Emitter<CalculationState> emit) async {
    final List<String> allowedOperators = ['+', '-', '*', '/'];

    if (!allowedOperators.contains(event.operator)) {
      return;
    }

    final CalculationModel model = state.calculationModel;

    final CalculationModel newModel = model.copyWith(
      firstOperand: model.firstOperand ?? 0,
      operator: event.operator,
    );

    emit(CalculationChanged(
      calculationModel: newModel,
      history: List.of(state.history),
    ));
  }

  Future<void> _onCalculateResult(CalculateResult event, Emitter<CalculationState> emit) async {
    final CalculationModel model = state.calculationModel;

    if (model.operator == null || model.secondOperand == null) {
      emit(state);
      return;
    }

    int result = 0;

    switch (model.operator) {
      case '+':
        result = model.firstOperand! + model.secondOperand!;
        break;
      case '-':
        result = model.firstOperand! - model.secondOperand!;
        break;
      case '*':
        result = model.firstOperand! * model.secondOperand!;
        break;
      case '/':
        if (model.secondOperand == 0) {
          result = 0;
        } else {
          result = model.firstOperand! ~/ model.secondOperand!;
        }
        break;
    }

    final CalculationModel newModel = CalculationInitial().calculationModel.copyWith(
      firstOperand: result,
    );

    emit(CalculationChanged(
      calculationModel: newModel,
      history: List.of(state.history),
    ));

    await _yieldHistoryStorageResult(model, newModel, emit);
  }

  Future<void> _yieldHistoryStorageResult(CalculationModel model, CalculationModel newModel, Emitter<CalculationState> emit) async {
    final CalculationModel resultModel = model.copyWith(result: newModel.firstOperand);

    if (await calculationHistoryService.addEntry(resultModel)) {
      emit(CalculationChanged(
        calculationModel: newModel,
        history: calculationHistoryService.fetchAllEntries(),
      ));
    }
  }

  void _onClearCalculation(ClearCalculation event, Emitter<CalculationState> emit) {
    final CalculationModel resultModel = CalculationInitial().calculationModel.copyWith();

    emit(CalculationChanged(
      calculationModel: resultModel,
      history: List.of(state.history),
    ));
  }

  void _onFetchHistory(FetchHistory event, Emitter<CalculationState> emit) {
    emit(CalculationChanged(
      calculationModel: state.calculationModel,
      history: calculationHistoryService.fetchAllEntries(),
    ));
  }

  @override
  void onChange(Change<CalculationState> change) {
    log(change.currentState.calculationModel.toString());
    log(change.nextState.calculationModel.toString());
    super.onChange(change);
  }
}
