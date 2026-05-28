import 'package:url_launcher/url_launcher.dart';

class ContactService {
  const ContactService();

  Future<String?> openPhone(String? phone) async {
    final cleanPhone = _cleanPhone(phone);
    if (cleanPhone == null) return 'Telefono no configurado.';

    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await launchUrl(uri)) return null;
    return 'No se pudo abrir la llamada.';
  }

  Future<String?> openWhatsApp(String? phone, {String? message}) async {
    final cleanPhone = _cleanPhone(phone);
    if (cleanPhone == null) return 'WhatsApp no configurado.';

    final uri = Uri.https('wa.me', '/$cleanPhone', {
      if (message != null && message.isNotEmpty) 'text': message,
    });
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return null;
    return 'No se pudo abrir WhatsApp.';
  }

  String? _cleanPhone(String? value) {
    final digits = value?.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits == null || digits.isEmpty) return null;
    return digits.startsWith('+') ? digits.substring(1) : digits;
  }
}
