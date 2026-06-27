import 'package:equatable/equatable.dart';
import '../../../data/models/agent_model.dart';

class AgentsState extends Equatable {
  final List<AgentModel> agents;
  final bool isLoading;
  final String? error;

  const AgentsState({
    this.agents = const [],
    this.isLoading = false,
    this.error,
  });

  AgentsState copyWith({
    List<AgentModel>? agents,
    bool isLoading = false,
    String? error,
    bool clearError = false,
  }) {
    return AgentsState(
      agents: agents ?? this.agents,
      isLoading: isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [agents, isLoading, error];
}
