import 'package:flutter/material.dart';

enum SharedChatMessageType {
  observation,
  update,
  decision,
  question,
  note,
  system;

  String get jsonValue => name;

  static SharedChatMessageType fromJson(String? value) =>
      SharedChatMessageType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => SharedChatMessageType.note,
      );

  String get displayName => switch (this) {
        observation => 'Observación',
        update => 'Actualización',
        decision => 'Decisión',
        question => 'Pregunta',
        note => 'Nota',
        system => 'Sistema',
      };

  IconData get icon => switch (this) {
        observation => Icons.visibility_outlined,
        update => Icons.sync_outlined,
        decision => Icons.check_circle_outline,
        question => Icons.help_outline,
        note => Icons.notes_outlined,
        system => Icons.info_outline,
      };

  Color color(ColorScheme cs) => switch (this) {
        observation => cs.tertiary,
        update => cs.secondary,
        decision => Colors.green,
        question => Colors.orange,
        note => cs.primary,
        system => cs.outline,
      };
}

class SharedChatMessage {
  final String id;
  final DateTime timestamp;
  final String role; // 'agent' | 'user' | 'system'
  final String? agentId;
  final String agentName;
  final String? taskId;
  final String? taskTitle;
  final SharedChatMessageType type;
  final String content;

  const SharedChatMessage({
    required this.id,
    required this.timestamp,
    required this.role,
    this.agentId,
    required this.agentName,
    this.taskId,
    this.taskTitle,
    required this.type,
    required this.content,
  });

  factory SharedChatMessage.fromJson(Map<String, dynamic> json) {
    return SharedChatMessage(
      id: json['id'] as String? ?? '',
      timestamp: DateTime.parse(json['timestamp'] as String),
      role: json['role'] as String? ?? 'user',
      agentId: json['agent_id'] as String?,
      agentName: json['agent_name'] as String? ?? 'Desconocido',
      taskId: json['task_id'] as String?,
      taskTitle: json['task_title'] as String?,
      type: SharedChatMessageType.fromJson(json['type'] as String?),
      content: json['content'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'role': role,
        if (agentId != null) 'agent_id': agentId,
        'agent_name': agentName,
        if (taskId != null) 'task_id': taskId,
        if (taskTitle != null) 'task_title': taskTitle,
        'type': type.jsonValue,
        'content': content,
      };
}
