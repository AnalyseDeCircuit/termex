/// Deep link routing for Termex.
///
/// URL scheme: `termex://<resource>/<id>`
/// Currently handled routes:
///   termex://monitor/<server_id>  → open server monitor detail
sealed class DeepLink {
  const DeepLink();
}

class MonitorDeepLink extends DeepLink {
  final String serverId;
  const MonitorDeepLink({required this.serverId});
}

class UnknownDeepLink extends DeepLink {
  final String url;
  const UnknownDeepLink({required this.url});
}

/// Parses a `termex://` deep link URL into a typed [DeepLink].
DeepLink parseDeepLink(String url) {
  if (!url.startsWith('termex://')) {
    return UnknownDeepLink(url: url);
  }
  final path = url.substring('termex://'.length);
  final segments = path.split('/');
  if (segments.length >= 2 && segments[0] == 'monitor') {
    return MonitorDeepLink(serverId: segments[1]);
  }
  return UnknownDeepLink(url: url);
}

/// Navigates to the page corresponding to [link] using [navigateTo].
/// The caller supplies the navigation callback to avoid a BuildContext dependency.
void handleDeepLink(
  DeepLink link,
  void Function(String route, {Object? arguments}) navigateTo,
) {
  switch (link) {
    case MonitorDeepLink(:final serverId):
      navigateTo('/monitor/server/$serverId', arguments: serverId);
    case UnknownDeepLink():
      break;
  }
}
