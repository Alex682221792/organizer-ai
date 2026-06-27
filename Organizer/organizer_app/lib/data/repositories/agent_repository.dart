import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/agent_model.dart';
import '../models/project_model.dart';
import '../../core/constants/app_constants.dart';

class AgentRepository {
  final _uuid = const Uuid();

  String _agentsFilePath(ProjectModel project) =>
      p.join(project.folderPath, AppConstants.agentsFile);

  Future<List<AgentModel>> loadAgents(ProjectModel project) async {
    try {
      final file = File(_agentsFilePath(project));
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => AgentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load agents: $e');
    }
  }

  Future<AgentModel> createAgent({
    required ProjectModel project,
    required String name,
    required String model,
    String? systemPrompt,
    required List<String> tools,
    required String description,
  }) async {
    final agents = await loadAgents(project);
    final agent = AgentModel(
      id: _uuid.v4(),
      name: name,
      model: model,
      systemPrompt: systemPrompt,
      tools: tools,
      description: description,
    );
    agents.add(agent);
    await _writeAgents(project, agents);
    return agent;
  }

  Future<void> updateAgent(ProjectModel project, AgentModel updated) async {
    final agents = await loadAgents(project);
    final index = agents.indexWhere((a) => a.id == updated.id);
    if (index == -1) throw Exception('Agent not found');
    agents[index] = updated;
    await _writeAgents(project, agents);
  }

  Future<void> deleteAgent(ProjectModel project, String agentId) async {
    final agents = await loadAgents(project);
    agents.removeWhere((a) => a.id == agentId);
    await _writeAgents(project, agents);
  }

  Future<void> _writeAgents(ProjectModel project, List<AgentModel> agents) async {
    final file = File(_agentsFilePath(project));
    await file.writeAsString(jsonEncode(agents.map((a) => a.toJson()).toList()));
  }
}
