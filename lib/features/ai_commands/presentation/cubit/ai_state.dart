import 'package:equatable/equatable.dart';

import '../../services/inference_pipeline_service.dart';
import '../../../../core/models/timeline_models.dart';

/// Base AI state for the AI commands cubit.
abstract class AIState extends Equatable {
  const AIState();

  @override
  List<Object?> get props => [];
}

/// The initial state before any AI command is executed.
class AIInitial extends AIState {
  const AIInitial();
}

/// Generic loading state while the AI engine or pipeline is preparing.
class AILoading extends AIState {
  final String? detail;

  const AILoading({this.detail});

  @override
  List<Object?> get props => [detail];
}

/// State emitted while a model is downloading or loading.
class AIDownloadingModel extends AILoading {
  final String? modelName;

  const AIDownloadingModel({String? detail, this.modelName}) : super(detail: detail);

  @override
  List<Object?> get props => [detail, modelName];
}

/// State emitted while the AI pipeline is running inference.
class AIRunningInference extends AILoading {
  final AIInferenceStatus status;
  final int currentAction;
  final int totalActions;

  const AIRunningInference({
    required this.status,
    required this.currentAction,
    required this.totalActions,
    String? detail,
  }) : super(detail: detail);

  @override
  List<Object?> get props => [status, currentAction, totalActions, detail];
}

/// State emitted when an AI operation completes successfully.
class AISuccess extends AIState {
  final List<AIInferenceResult> results;
  final String? detail;

  const AISuccess({
    this.results = const [],
    this.detail,
  });

  @override
  List<Object?> get props => [results, detail];
}

/// State emitted when an AI operation fails.
class AIFailure extends AIState {
  final String errorMessage;
  final String? detail;

  const AIFailure({
    required this.errorMessage,
    this.detail,
  });

  @override
  List<Object?> get props => [errorMessage, detail];
}

// Legacy compatibility states used by existing AI UI.

/// Processing state emitted while an AI command is executing.
class AIProcessing extends AIRunningInference {
  const AIProcessing({
    required AIInferenceStatus status,
    required int currentAction,
    required int totalActions,
    String? detail,
  }) : super(
          status: status,
          currentAction: currentAction,
          totalActions: totalActions,
          detail: detail,
        );
}

/// State emitted when a model is downloading or loading within the processing flow.
class AIModelDownloading extends AIProcessing {
  final String? modelName;

  const AIModelDownloading({
    required AIInferenceStatus status,
    required int currentAction,
    required int totalActions,
    String? detail,
    this.modelName,
  }) : super(
          status: status,
          currentAction: currentAction,
          totalActions: totalActions,
          detail: detail,
        );

  @override
  List<Object?> get props => super.props..add(modelName);
}

/// State emitted when an AI command completes successfully.
class AICompleted extends AIModelDownloading {
  final List<AIInferenceResult> results;

  const AICompleted({
    required AIInferenceStatus status,
    required int currentAction,
    required int totalActions,
    String? detail,
    String? modelName,
    this.results = const [],
  }) : super(
          status: status,
          currentAction: currentAction,
          totalActions: totalActions,
          detail: detail,
          modelName: modelName,
        );

  @override
  List<Object?> get props => [...super.props, results];
}

/// State emitted when an AI command fails.
class AIError extends AICompleted {
  final String errorMessage;

  const AIError({
    required AIInferenceStatus status,
    required int currentAction,
    required int totalActions,
    String? detail,
    String? modelName,
    List<AIInferenceResult> results = const [],
    required this.errorMessage,
  }) : super(
          status: status,
          currentAction: currentAction,
          totalActions: totalActions,
          detail: detail,
          modelName: modelName,
          results: results,
        );

  @override
  List<Object?> get props => [...super.props, errorMessage];
}
