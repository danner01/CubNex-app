import 'dart:js_interop';

@JS('cubnexOcrRecognize')
external JSPromise<JSString> _cubnexOcrRecognize(JSString url);

Future<String?> webRecognizeText(String url) async {
  try {
    final text = await _cubnexOcrRecognize(url.toJS).toDart;
    return text.toDart;
  } catch (_) {
    return null;
  }
}
