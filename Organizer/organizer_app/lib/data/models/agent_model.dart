import 'package:equatable/equatable.dart';

class AgentModel extends Equatable {
  final String id;
  final String name;
  final String model;
  final String? systemPrompt;
  final List<String> tools;
  final String description;

  const AgentModel({
    required this.id,
    required this.name,
    required this.model,
    this.systemPrompt,
    required this.tools,
    required this.description,
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    final sp = json['system_prompt'] as String?;
    return AgentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      model: json['model'] as String? ?? 'claude-sonnet-4-6',
      systemPrompt: (sp != null && sp.isNotEmpty) ? sp : null,
      tools: (json['tools'] as List<dynamic>?)?.cast<String>() ?? [],
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'model': model,
      if (systemPrompt != null) 'system_prompt': systemPrompt,
      'tools': tools,
      'description': description,
    };
  }

  AgentModel copyWith({
    String? id,
    String? name,
    String? model,
    Object? systemPrompt = _sentinel,
    List<String>? tools,
    String? description,
  }) {
    return AgentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      model: model ?? this.model,
      systemPrompt:
          systemPrompt == _sentinel ? this.systemPrompt : systemPrompt as String?,
      tools: tools ?? this.tools,
      description: description ?? this.description,
    );
  }

  @override
  List<Object?> get props => [id, name, model, systemPrompt, tools, description];
}

const _sentinel = Object();

const kAvailableModels = [
  'claude-opus-4-7',
  'claude-sonnet-4-6',
  'claude-haiku-4-5',
];

const kAvailableTools = [
  'web_search',
  'bash',
  'file_read',
  'file_write',
  'computer_use',
];
