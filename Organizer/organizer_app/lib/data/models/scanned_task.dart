import 'package:equatable/equatable.dart';

class ScannedTask extends Equatable {
  final String title;
  final String instructions;
  final String sourcePath;

  const ScannedTask({
    required this.title,
    required this.instructions,
    required this.sourcePath,
  });

  @override
  List<Object?> get props => [title, instructions, sourcePath];
}
