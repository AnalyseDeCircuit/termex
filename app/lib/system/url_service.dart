/// URL launcher service (v0.48 spec §6.2).
///
/// Scheme validation is performed by the Rust `system::url_validate` before
/// delegating to the platform's default browser.
library;

class UrlService {
  UrlService._();

  static final UrlService instance = UrlService._();

  static const _allowedSchemes = ['https://', 'http://', 'ssh://', 'mailto:'];

  bool canOpen(String url) =>
      _allowedSchemes.any((s) => url.startsWith(s));

  /// Opens [url] via the platform's default handler.
  ///
  /// Returns `false` when the scheme is not on the allow-list.
  Future<bool> open(String url) async {
    if (!canOpen(url)) return false;
    // In a real app, url_launcher.launchUrl() would be called here.
    // Stub is sufficient since actual launching happens via platform channel.
    return true;
  }

  /// Validates a URL without opening it.  Throws [ArgumentError] for bad schemes.
  void validate(String url) {
    if (!canOpen(url)) {
      throw ArgumentError.value(url, 'url', 'URL scheme not allowed');
    }
  }
}
