import 'package:equatable/equatable.dart';
import '../../../data/models/agent_model.dart';
import '../../../data/models/project_model.dart';

abstract class AgentsEvent extends Equatable {
  const AgentsEvent();

  @override
  List<Object?> get props => [];
}

class LoadAgents extends AgentsEvent {
  final ProjectModel project;

  const LoadAgents(this.project);

  @override
  List<Object?> get props => [project];
}

class CreateAgent extends AgentsEvent {
  final ProjectModel project;
  final String name;
  final String model;
  final String? systemPrompt;
  final List<String> tools;
  final String description;

  const CreateAgent({
    required this.project,
    required this.name,
    required this.model,
    this.systemPrompt,
    required this.tools,
    required this.description,
  });

  @override
  List<Object?> get props => [project, name, model, systemPrompt, tools, description];
}

class UpdateAgent extends AgentsEvent {
  final ProjectModel project;
  final AgentModel agent;

  const UpdateAgent({required this.project, required this.agent});

  @override
  List<Object?> get props => [project, agent];
}

class DeleteAgent extends AgentsEvent {
  final ProjectModel project;
  final String agentId;

  const DeleteAgent({required this.project, required this.agentId});

  @override
  List<Object?> get props => [project, agentId];
}
