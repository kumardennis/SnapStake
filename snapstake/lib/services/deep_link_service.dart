import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:get/get.dart';

import '../controllers/auth_controller.dart';
import 'moment_link_service.dart';

class DeepLinkService extends GetxService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  bool _initialized = false;
  String? _pendingMomentId;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final initialUri = await _appLinks.getInitialLink();
      _handleUri(initialUri);
    } catch (e) {
      print('❌ Error reading initial deep link: $e');
    }

    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleUri,
      onError: (Object error) {
        print('❌ Deep link stream error: $error');
      },
    );
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;

    final momentId = MomentLinkService.extractMomentId(uri);
    if (momentId == null || momentId.isEmpty) return;

    _pendingMomentId = momentId;
    tryNavigatePendingMoment();
  }

  void tryNavigatePendingMoment() {
    if (_pendingMomentId == null) return;
    if (!Get.isRegistered<AuthController>()) return;

    final authController = Get.find<AuthController>();
    if (!authController.isSignedIn) return;

    final momentId = _pendingMomentId!;
    _pendingMomentId = null;

    Future.microtask(() {
      Get.toNamed('/moment', arguments: {'momentId': momentId});
    });
  }

  @override
  void onClose() {
    _linkSubscription?.cancel();
    super.onClose();
  }
}
