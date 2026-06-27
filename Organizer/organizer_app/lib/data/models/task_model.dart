import 'package:equatable/equatable.dart';
import 'task_status.dart';

class TaskModel extends Equatable {
  final String id;
  final String projectId;
  final String title;
  final TaskStatus status;
  final String instructions;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int runCount;
  final bool needsInput;
  final List<String> agentIds;
  final List<String> blockedBy;
  final String? folderId;

  const TaskModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.status,
    required this.instructions,
    required this.createdAt,
    required this.updatedAt,
    required this.runCount,
    required this.needsInput,
    this.agentIds = const [],
    this.blockedBy = const [],
    this.folderId,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json, String projectId) {
    return TaskModel(
      id: json['id'] as String,
      projectId: projectId,
      title: json['title'] as String,
      status: TaskStatus.fromJson(json['status'] as String? ?? 'backlog'),
      instructions: json['instructions'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      runCount: json['runCount'] as int? ?? 0,
      needsInput: json['needsInput'] as bool? ?? false,
      agentIds: (json['agentIds'] as List<dynamic>?)?.cast<String>() ?? [],
      blockedBy: (json['blockedBy'] as List<dynamic>?)?.cast<String>() ?? [],
      folderId: json['folderId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status.jsonValue,
      'instructions': instructions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'runCount': runCount,
      'needsInput': needsInput,
      'agentIds': agentIds,
      'blockedBy': blockedBy,
      if (folderId != null) 'folderId': folderId,
    };
  }

  TaskModel copyWith({
    String? id,
    String? projectId,
    String? title,
    TaskStatus? status,
    String? instructions,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? runCount,
    bool? needsInput,
    List<String>? agentIds,
    List<String>? blockedBy,
    String? folderId,
    bool clearFolderId = false,
  }) {
    return TaskModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      status: status ?? this.status,
      instructions: instructions ?? this.instructions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      runCount: runCount ?? this.runCount,
      needsInput: needsInput ?? this.needsInput,
      agentIds: agentIds ?? this.agentIds,
      blockedBy: blockedBy ?? this.blockedBy,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
    );
  }

  bool isBlocked(Set<String> completedIds) =>
      blockedBy.any((id) => !completedIds.contains(id));

  @override
  List<Object?> get props => [
        id, projectId, title, status, instructions,
        createdAt, updatedAt, runCount, needsInput, agentIds, blockedBy, folderId,
      ];
}
