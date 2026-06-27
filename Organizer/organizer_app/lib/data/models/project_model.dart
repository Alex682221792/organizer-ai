import 'package:equatable/equatable.dart';

class ProjectModel extends Equatable {
  final String id;
  final String name;
  final String description;
  final String folderPath;
  final String color;
  final DateTime createdAt;
  final bool schedulerEnabled;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.folderPath,
    required this.color,
    required this.createdAt,
    this.schedulerEnabled = true,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json, String folderPath) {
    return ProjectModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      folderPath: folderPath,
      color: json['color'] as String? ?? '#6366f1',
      createdAt: DateTime.parse(json['createdAt'] as String),
      schedulerEnabled: json['schedulerEnabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
      'schedulerEnabled': schedulerEnabled,
    };
  }

  ProjectModel copyWith({
    String? id,
    String? name,
    String? description,
    String? folderPath,
    String? color,
    DateTime? createdAt,
    bool? schedulerEnabled,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      folderPath: folderPath ?? this.folderPath,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      schedulerEnabled: schedulerEnabled ?? this.schedulerEnabled,
    );
  }

  @override
  List<Object?> get props => [id, name, description, folderPath, color, createdAt, schedulerEnabled];
}
