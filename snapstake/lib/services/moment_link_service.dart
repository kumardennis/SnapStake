class MomentLinkService {
  // Override with --dart-define=PUBLIC_MOMENT_BASE_URL=https://your-domain/m
  static const String publicMomentBaseUrl = String.fromEnvironment(
    'PUBLIC_MOMENT_BASE_URL',
    defaultValue: 'https://snapstake.app/m',
  );

  // RFC 3986 scheme: ALPHA *( ALPHA / DIGIT / "+" / "-" / "." )
  static final String appDeepLinkScheme = _sanitizeScheme(
    const String.fromEnvironment(
      'APP_LINK_SCHEME',
      defaultValue: 'com.snapstake.app',
    ),
  );

  static String _sanitizeScheme(String raw) {
    var normalized = raw.toLowerCase();
    normalized = normalized.replaceAll('_', '');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9+.-]'), '');

    if (normalized.isEmpty || !RegExp(r'^[a-z]').hasMatch(normalized)) {
      return 'snapstake';
    }

    return normalized;
  }

  static String buildAppMomentLink(String momentId, {String? creatorId}) {
    final uri = Uri(
      scheme: appDeepLinkScheme,
      host: 'moment',
      pathSegments: [momentId],
      queryParameters:
          (creatorId == null || creatorId.isEmpty) ? null : {'ref': creatorId},
    );

    return uri.toString();
  }

  static String buildPublicMomentUrl(String momentId, {String? creatorId}) {
    final base =
        publicMomentBaseUrl.endsWith('/')
            ? publicMomentBaseUrl.substring(0, publicMomentBaseUrl.length - 1)
            : publicMomentBaseUrl;

    final uri = Uri.parse('$base/${Uri.encodeComponent(momentId)}');
    if (creatorId == null || creatorId.isEmpty) {
      return uri.toString();
    }

    return uri.replace(queryParameters: {'ref': creatorId}).toString();
  }

  static String? extractMomentId(Uri uri) {
    final queryMomentId =
        uri.queryParameters['momentId'] ?? uri.queryParameters['moment_id'];
    if (queryMomentId != null && queryMomentId.isNotEmpty) {
      return queryMomentId;
    }

    final segments = uri.pathSegments;

    // Supports snapstake://moment/<id> and snapstake://m/<id>
    if (uri.scheme.toLowerCase() == appDeepLinkScheme.toLowerCase()) {
      final host = uri.host.toLowerCase();
      if ((host == 'moment' || host == 'm') && segments.isNotEmpty) {
        return segments.first;
      }

      if (segments.length >= 2 &&
          (segments[0].toLowerCase() == 'moment' ||
              segments[0].toLowerCase() == 'm')) {
        return segments[1];
      }
    }

    // Supports https://<domain>/m/<id> and https://<domain>/moment/<id>
    if (segments.length >= 2) {
      final first = segments.first.toLowerCase();
      if (first == 'm' || first == 'moment') {
        return segments[1];
      }
    }

    return null;
  }
}
