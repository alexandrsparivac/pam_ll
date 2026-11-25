import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<File> _file() async {
  final support = await getApplicationSupportDirectory();
  return File('${support.path}/gemstore_json/state.json');
}

Future<Map<String, dynamic>?> readLocalState() async {
  final file = await _file();
  if (!await file.exists()) return null;
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

Future<void> writeLocalState(Map<String, dynamic> state) async {
  final file = await _file();
  await file.parent.create(recursive: true);
  final temporary = File('${file.path}.tmp');
  await temporary.writeAsString(jsonEncode(state), flush: true);
  await temporary.rename(file.path);
}
