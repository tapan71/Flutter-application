// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

String? getWebStorageItem(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void setWebStorageItem(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}
