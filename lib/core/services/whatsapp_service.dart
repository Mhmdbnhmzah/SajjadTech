import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class WhatsappService {
  // Utility method to clean and format the phone number robustly
  static String formatPhoneNumber(String phone) {
    // Remove all non-digits
    String cleaned = phone.replaceAll(RegExp(r'[^\d]'), '');

    // Strip leading double zeros 00
    if (cleaned.startsWith('00')) {
      cleaned = cleaned.substring(2);
    }

    // If it starts with 967, it is already formatted
    if (cleaned.startsWith('967')) {
      return cleaned;
    }

    // If it starts with a single 0 (e.g., 077XXXXXXX), strip the 0
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    // If it is 9 digits and starts with 7, add country code
    if (cleaned.length == 9 && cleaned.startsWith('7')) {
      cleaned = '967$cleaned';
    }

    return cleaned;
  }

  // Method to launch WhatsApp
  static Future<bool> sendWhatsAppMessage({
    required String phone,
    required String message,
  }) async {
    final formattedPhone = formatPhoneNumber(phone);
    final encodedMessage = Uri.encodeComponent(message);
    final urlString = 'https://wa.me/$formattedPhone?text=$encodedMessage';
    final uri = Uri.parse(urlString);

    try {
      // Launch directly, which is more reliable on Android 11+
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Error launching WhatsApp directly: $e');
      try {
        final webUri = Uri.parse(
          'https://api.whatsapp.com/send?phone=$formattedPhone&text=$encodedMessage',
        );
        return await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (ex) {
        print('Error launching fallback WhatsApp web: $ex');
        return false;
      }
    }
  }

  // Stage 1 Message: Order Received
  static String getOrderReceivedMessage({
    required String customerName,
    required int itemCount,
    required double totalPrice,
    required double paidAmount,
    required DateTime deliveryDate,
    required String laundryName,
  }) {
    final dateStr = DateFormat('yyyy-MM-dd').format(deliveryDate);
    final remaining = totalPrice - paidAmount;
    return '''
مرحباً بك يا *$customerName* 👋

تم استلام سجادك بنجاح في *مغسلة $laundryName*.
📦 *عدد القطع:* $itemCount
💰 *التكلفة الإجمالية:* ${totalPrice.toStringAsFixed(0)} ريال
💵 *المبلغ المدفوع:* ${paidAmount.toStringAsFixed(0)} ريال
⏳ *المبلغ المتبقي:* ${remaining.toStringAsFixed(0)} ريال
📅 *تاريخ التسليم المتوقع:* $dateStr

شرفتنا بزيارتك ونعدك بأفضل خدمة! ✨
''';
  }

  // Stage 2 Message: Order Ready
  static String getOrderReadyMessage({
    required String customerName,
    required double totalPrice,
    required double paidAmount,
    required String laundryName,
  }) {
    final remaining = totalPrice - paidAmount;
    final String paymentStatusStr = remaining <= 0 
        ? '💵 *حالة الدفع:* مدفوع بالكامل (شكراً لك!)' 
        : '⏳ *المبلغ المطلوب عند الاستلام:* ${remaining.toStringAsFixed(0)} ريال';
        
    return '''
مرحباً يا *$customerName* 👋

يسعدنا إبلاغك بأن سجادك أصبح *جاهزاً للاستلام* الآن في *مغسلة $laundryName*.
$paymentStatusStr

نسعد بزيارتك في أي وقت! 🧼✨
''';
  }

  // Stage 3 Message: Order Delivered & Confirmed
  static String getOrderDeliveredMessage({
    required String customerName,
    required double totalPrice,
    required double paidAmount,
    required String laundryName,
  }) {
    final remaining = totalPrice - paidAmount;
    final String paymentStatusStr = remaining <= 0
        ? '💵 *حالة الدفع:* تم دفع الحساب بالكامل (شكراً لك! ✓)'
        : '💰 *القيمة الإجمالية للطلب:* ${totalPrice.toStringAsFixed(0)} ريال\n'
          '💵 *المبلغ المدفوع:* ${paidAmount.toStringAsFixed(0)} ريال\n'
          '⏳ *المبلغ المتبقي (آجل):* ${remaining.toStringAsFixed(0)} ريال';

    return '''
مرحباً يا *$customerName* 👋

تم تسليم السجاد وتأكيد عملية الاستلام بنجاح في *مغسلة $laundryName*.

$paymentStatusStr

شكراً لتعاملك معنا وثقتك الغالية. نتطلع لخدمتك مرة أخرى! ❤️🧼
''';
  }
}
