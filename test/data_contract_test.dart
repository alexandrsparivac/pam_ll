import 'package:flutter_test/flutter_test.dart';

import '../tool/self_check.dart' as checks;

void main() {
  test('domain, DTO and repository contract checks', checks.runSelfChecks);
}
