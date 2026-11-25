Map<String, dynamic>? _saved;
Future<Map<String, dynamic>?> readLocalState() async => _saved;
Future<void> writeLocalState(Map<String, dynamic> state) async {
  _saved = state;
}
