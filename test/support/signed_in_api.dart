import 'package:cam_bien_te_nga/services/motion_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Existing device UI tests exercise an already authenticated member session.
MotionApi signedInTestApi() {
  final api = _SignedInApi();
  addTearDown(api.dispose);
  return api;
}

class _SignedInApi extends MotionApi {
  _SignedInApi() {
    restored = true;
    user = {'id': 'test-member', 'name': 'Test', 'role': 'member'};
  }
  @override
  bool get signedIn => true;
}
