import 'dart:core';
import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:mailer/smtp_server/sendgrid.dart';
import 'dart:developer';
import 'package:twilio_dart_api/twilio.dart';

final String accountSid = '';
final String authToken = '';
final String twilioNumber = '';
final bool enabled = false;

Twilio twilio = Twilio(
    accountSid: '*************************', // replace *** with Account SID
    authToken: 'xxxxxxxxxxxxxxxxxx', // replace xxx with Auth Token
    twilioNumber: '+...............' // replace .... with Twilio Number
    );

String sendAuthCode(String num) {
  //Use sendMessage with the recipient number and message body.
  final String authcode = generateAuthCode();
  twilio.messages.sendMessage(num, "Your authentication code is $authcode");
  return authcode;
}

bool confirmEmail(String email) {
  String username = 'liquidmoni@gmail.com';
  String password = 'password';
  // set up email abi?
  final smtpServer = gmail(username, password);
  var message = Message()
    ..from = Address(username)
    ..recipients.add(email)
    ..subject = 'Notice for Pin Change'
    ..text =
        'This is to notify you of a change in your pin for the LiquidMoni app. If you did not trigger this process, please contact support immediately.';
  //..html = "<h1>Test</h1>\n<p>Hey! Here's some HTML content</p>";

  try {
    final sendReport = send(message, smtpServer);
    print('Message sent: ' + sendReport.toString());
    return true;
  } on MailerException catch (e) {
    print('Message not sent.');
    for (var p in e.problems) {
      print('Problem: ${p.code}: ${p.msg}');
    }
    return false;
  }
  // wanted to send link but its proving difficult, me idk o i wanted to be able to register on click by sending a button
  //or link idek
  //sends an email with a prompt to click to put in new pin
  //for forgotPin
}

String generateVirtualAccountNumber() {
  Random random = Random();
  var randomNum = (random.nextInt(900000000) + 100000000).toString();
  return randomNum;
}

String generateAuthCode() {
  Random random = Random();
  var randomNum = (random.nextInt(900000) + 100000).toString();
  return randomNum;
}


//hash password