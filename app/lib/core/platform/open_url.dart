// Opens a web link on the phone: YouTube links in the YouTube app (full quality, at the
// time in the link), anything else in the phone's browser. Used by "Watch on phone".
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('deskpanel/open');

/// True when an app took the link.
Future<bool> openOnPhone(String url) async {
  try {
    return await _channel.invokeMethod<bool>('url', {'url': url}) ?? false;
  } on MissingPluginException {
    return false; // tests / non-Android
  } on PlatformException catch (e) {
    debugPrint('DeskPanel open: ${e.message}');
    return false;
  }
}
