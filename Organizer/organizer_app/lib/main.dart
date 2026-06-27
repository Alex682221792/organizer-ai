import 'package:flutter/material.dart';
import 'app.dart';
import 'injection_container.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  setupInjection();
  runApp(const OrganizerApp());
}
