import 'dart:core';
import 'dart:math';
import 'package:decimal/decimal.dart';
import 'package:liquidmoniproject/src/services/enums.dart';

//generate based on transaction type?
String generateRefNumber() {
  Random random = Random();
  var randomNum = (random.nextInt(900000000) + 100000000).toString();
  return "REF" + randomNum;
}

void SendToInHouseUser(Decimal amount, String accNumber) {}
