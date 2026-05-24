import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Direct SMTP mail sender used by the mobile app.
///
/// NOTE: Hard-coding SMTP credentials in a client-side app is risky because
/// the app binary can be decompiled. This mirrors the web app's behavior on
/// purpose (same Gmail App Password). When you're ready, move this back to a
/// Supabase Edge Function so the credentials never ship to the client.
class MailService {
  // Same Gmail App Password as the web app (smtplib in blueprints/auth.py).
  static const String _senderEmail = 'parokyanigahi21@gmail.com';
  static const String _senderPassword = 'ahzyzotndedbxeco';
  static const String _senderName = 'Velare';

  /// Sends a 6-digit password reset code to [recipientEmail].
  /// Returns true on successful delivery.
  static Future<bool> sendResetCode(
    String recipientEmail,
    String resetCode,
  ) async {
    try {
      final smtp = gmail(_senderEmail, _senderPassword);

      final message = Message()
        ..from = Address(_senderEmail, _senderName)
        ..recipients.add(recipientEmail)
        ..subject = 'Velare - Password Reset Code'
        ..text = _buildPlainText(resetCode)
        ..html = _buildHtml(resetCode);

      final report = await send(message, smtp);
      print('MailService - reset code sent: $report');
      return true;
    } on MailerException catch (e) {
      print('MailService - MailerException: ${e.message}');
      for (final problem in e.problems) {
        print('  problem: code=${problem.code}, msg=${problem.msg}');
      }
      return false;
    } catch (e) {
      print('MailService - unexpected error: $e');
      return false;
    }
  }

  static String _buildPlainText(String code) {
    return [
      'Password Reset Request',
      '',
      'You requested to reset your password for your Velare account.',
      '',
      'Your password reset code is: $code',
      '',
      'This code will expire in 15 minutes.',
      'If you didn\'t request this, please ignore this email.',
    ].join('\n');
  }

  static String _buildHtml(String code) {
    return '''
<!DOCTYPE html>
<html>
  <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
      <h2 style="color: #4A5568;">Password Reset Request</h2>
      <p>You requested to reset your password for your Velare account.</p>
      <p>Your password reset code is:</p>
      <div style="background-color: #f7fafc; padding: 20px; text-align: center; margin: 20px 0; border-radius: 5px;">
        <h1 style="color: #2D3748; letter-spacing: 5px; margin: 0;">$code</h1>
      </div>
      <p style="color: #718096;">This code will expire in 15 minutes.</p>
      <p style="color: #718096;">If you didn't request this, please ignore this email.</p>
      <hr style="border: 0; border-top: 1px solid #E2E8F0; margin: 20px 0;" />
      <p style="color: #A0AEC0; font-size: 12px;">Velare - Your trusted online marketplace</p>
    </div>
  </body>
</html>
''';
  }
}
