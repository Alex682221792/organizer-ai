import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/repositories/agent_repository.dart';
import '../../../data/services/refinement_service.dart';
import 'agents_event.dart';
import 'agents_state.dart';

class AgentsBloc extends Bloc<AgentsEvent, AgentsState> {
  final AgentRepository _agentRepository;
  final RefinementService _refinementService;

  AgentsBloc(this._agentRepository, this._refinementService) : super(const AgentsState()) {
    on<LoadAgents>(_onLoadAgents);
    on<CreateAgent>(_onCreateAgent);
    on<UpdateAgent>(_onUpdateAgent);
    on<DeleteAgent>(_onDeleteAgent);
  }

  Future<void> _onLoadAgents(LoadAgents event, Emitter<AgentsState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final agents = await _agentRepository.loadAgents(event.project);
      emit(state.copyWith(agents: agents));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onCreateAgent(CreateAgent event, Emitter<AgentsState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      String? systemPrompt = event.systemPrompt;
      if (systemPrompt == null || systemPrompt.isEmpty) {
        systemPrompt = await _refinementService.generateAgentSystemPrompt(
          name: event.name,
          description: event.description,
          model: event.model,
          tools: event.tools,
        );
        if (systemPrompt == null) {
          emit(state.copyWith(
            error: 'No se pudo generar el system prompt. '
                'Verificá que Claude CLI esté configurado en Ajustes del runner.',
          ));
          return;
        }
      }
      await _agentRepository.createAgent(
        project: event.project,
        name: event.name,
        model: event.model,
        systemPrompt: systemPrompt,
        tools: event.tools,
        description: event.description,
      );
      final agents = await _agentRepository.loadAgents(event.project);
      emit(state.copyWith(agents: agents));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onUpdateAgent(UpdateAgent event, Emitter<AgentsState> emit) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      await _agentRepository.updateAgent(event.project, event.agent);
      final agents = await _agentRepository.loadAgents(event.project);
      emit(state.copyWith(agents: agents));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onDeleteAgent(DeleteAgent event, Emitter<AgentsState> emit) async {
    try {
      await _agentRepository.deleteAgent(event.project, event.agentId);
      final agents = await _agentRepository.loadAgents(event.project);
      emit(state.copyWith(agents: agents));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
