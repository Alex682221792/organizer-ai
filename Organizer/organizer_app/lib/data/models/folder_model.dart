import 'package:equatable/equatable.dart';

class FolderModel extends Equatable {
  final String id;
  final String name;
  final Map<String, String> attributes;

  const FolderModel({
    required this.id,
    required this.name,
    this.attributes = const {},
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    return FolderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      attributes: (json['attributes'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as String)),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'attributes': attributes,
      };

  FolderModel copyWith({
    String? id,
    String? name,
    Map<String, String>? attributes,
  }) {
    return FolderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      attributes: attributes ?? this.attributes,
    );
  }

  @override
  List<Object?> get props => [id, name, attributes];
}
