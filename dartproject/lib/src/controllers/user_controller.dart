import 'package:liquidmoniproject/liquidmoniproject.dart';
import 'package:liquidmoniproject/src/services/authentication.dart';
import 'package:liquidmoniproject/src/services/enums.dart';

class UserController {
  UserController(this._reqBody, Db db)
      : _req = _reqBody.request,
        _store2 = db.collection('virtualaccounts'),
        _store = db.collection('users') {
    endpoints();
  }

  final HttpRequestBody _reqBody;
  final HttpRequest _req;
  final DbCollection _store, _store2;

  endpoints() async {
    var pathName = _req.uri.path;
    const path = '/users';
    //confirm request types
    switch (_req.method) {
      case 'GET':
        //confirm name of endpoints
        switch (pathName) {
          //get list of users
          case '$path/getAllUsers':
            await getAllUsers();
            break;
          //get user details
          case '$path/getUser':
            String phoneNum = (_req.uri.queryParameters['phone_number']!);
            await getUserByPhoneNumber(phoneNum);
            break;
        }

      case 'POST':
        //save new user details
        switch (pathName) {
          case '$path/saveUser':
            String fullName = (_req.uri.queryParameters['full_name']!);
            String address = (_req.uri.queryParameters['address']!);
            String email = (_req.uri.queryParameters['email']!);
            String phoneNum = (_req.uri.queryParameters['phone_number']!);
            int pin = int.parse(_req.uri.queryParameters['pin_code']!);
            await saveUser(fullName, address, email, phoneNum, pin);
            break;
        }
      case 'PATCH':
        //confirm name of endpoints
        switch (pathName) {
          //update specific user details
          case '$path/updateUser':
            String phoneNum = (_req.uri.queryParameters['phone_number']!);
            await updateUserDetails(phoneNum);
            break;
          //change password
          case '$path/changePin':
            var email = (_req.uri.queryParameters['email']!);
            var newPin = int.parse(_req.uri.queryParameters['pin_code']!);
            await changePin(email, newPin);
            break;
          //disable account instead of deleting
          case '$path/disableUser':
            String phoneNum = (_req.uri.queryParameters['phone_number']!);
            await disableUser(phoneNum);
            break;
          //enable user account after authentication
          case '$path/enableUser':
            String phoneNum = (_req.uri.queryParameters['phone_number']!);
            String auth = (_req.uri.queryParameters['temp_auth_code']!);
            await enableUser(phoneNum, auth);
            break;
          //enable user account after authentication
          case '$path/resendAuthToken':
            String phoneNum = (_req.uri.queryParameters['phone_number']!);
            await resendAuthToken(phoneNum);
            break;
        }

      default:
        _req.response.statusCode = 405;
    }

    await _req.response.close();
  }

  getAllUsers() async {
    _req.response.write(await _store.find().toList());
  }

  getUserByPhoneNumber(String phoneNum) async {
    phoneNum = (_req.uri.queryParameters['phone_number']!);
    if (phoneNum != "") {
      var itemToFind = await _store.findOne(where.eq('phone_number', phoneNum));
      if (itemToFind != null) {
        _req.response.write(itemToFind);
      } else {
        _req.response.statusCode = HttpStatus.notFound;
      }
    } else {
      _req.response.statusCode = HttpStatus.badRequest;
    }
  }

  saveUser(String fullName, String address, String email, String phoneNum,
      int pin) async {
    //do some validation

    if (fullName.isEmpty) {
      _req.response.write('Please enter full name.');
    }
    if (address.isEmpty) {
      _req.response.write('Please enter address.');
    }
    if (phoneNum.isEmpty || !phoneNum.startsWith('+')) {
      _req.response.write('Please enter correct phone number.');
    } else {
      var itemToFind = await _store.findOne(where.eq('phone_number', phoneNum));
      if (itemToFind != null) {
        _req.response.write('Phone Number already exists.');
      }
    }
    if (email.isEmpty) {
      _req.response.write('Please enter an email.');
    } else {
      var itemToFind = await _store.findOne(where.eq('email', email));
      if (itemToFind != null) {
        _req.response.write('Email already exists.');
      }
    }
    if (pin < 0 || pin.toString().length != 4) {
      _req.response.write('Invalid pin.');
    }
    var userTier = UserTier.level0;
    String virtualAccNum = generateVirtualAccountNumber();
    //smoothen logic here so that virtual account number isnt repeated.
    var doesAccNumExist =
        await _store.findOne(where.eq('accountNumber', virtualAccNum));
    if (doesAccNumExist != null) {
      virtualAccNum = generateVirtualAccountNumber();
    }
    var auth = sendAuthCode(phoneNum);
    var newUser = {
      "full_name": fullName,
      "address": address,
      "email": email,
      "is_enabled": false,
      "phone_number": phoneNum,
      "accountNumber": virtualAccNum,
      "user_tier": userTier,
      "pin_code": pin,
      "temp_auth_code": auth
    };
    //save to virtual accounts table
    saveVirtualAccount(virtualAccNum);
    //to resend call send authcode. add a timer too.
    _req.response.write(await _store.insertOne(newUser));
  }

  disableUser(String phoneNum) async {
    if (phoneNum.isEmpty) {
      _req.response.write('Please enter correct phone number.');
    }
    var itemToFind = await _store.findOne(where.eq('phone_number', phoneNum));
    if (itemToFind != null) {
      bool disable = false;
      _req.response.write(await _store.updateOne(
          itemToFind, modify.set("is_enabled", disable)));
    } else {
      _req.response
          .write('Phone Number could not be confirmed. Please try again.');
    }
  }

  enableUser(String phoneNum, String auth) async {
    if (phoneNum.isEmpty) {
      _req.response.write('Please enter correct phone number.');
    }
    var itemToFind = await _store.findOne(where.eq('phone_number', phoneNum));
    if (itemToFind != null) {
      bool enable = false;
      var x = itemToFind['temp_auth_token'];
      if (x == auth) {
        enable == true;
      } else {
        _req.response
            .write('Error confirming user' 's authcode. Please try again.');
      }
      _req.response.write(
          await _store.updateOne(itemToFind, modify.set("is_enabled", enable)));
    } else {
      _req.response
          .write('Phone Number could not be confirmed. Please try again.');
    }
  }

  resendAuthToken(String phoneNum) async {
    var newCode = sendAuthCode(phoneNum);
    var itemToFind = await _store.findOne(where.eq('phone_number', phoneNum));
    if (itemToFind != null) {
      _req.response.write(await _store.updateOne(
          itemToFind, modify.set("temp_auth_code", newCode)));
    }
  }

  updateUserDetails(String phoneNum) async {
    var itemToPatch = await _store.findOne(where.eq('phone_number', phoneNum));
    if (itemToPatch != null) {
      _req.response
          .write(await _store.update(itemToPatch, {r'$set': _reqBody.body}));
    } else {
      _req.response.write('Please enter the correct phone number.');
    }
  }

  changePin(String email, int newPin) async {
    if (email.isEmpty) {
      _req.response.write('Please enter correct email.');
    }
    var itemToFind = await _store.findOne(where.eq('email', email));
    if (itemToFind != null) {
      bool isConfirmed = confirmEmail(email);
      if (isConfirmed == true) {
        newPin.truncate();
        _req.response.write(
            await _store.updateOne(itemToFind, modify.set("pin_code", newPin)));
      } else {
        _req.response.write('Could not confirm email. Please try again');
      }
    } else {
      _req.response.write('Email could not be confirmed. Please try again.');
    }
  }

  saveVirtualAccount(String virtualAccNum) async {
    var newVirtualAccount = {
      "date_created": DateTime.now(),
      "virtual_account_number": virtualAccNum,
      "balance_amount": 0.00
    };
    await _store2.insertOne(newVirtualAccount);
  }

  login() {}
  logout() {}
}
