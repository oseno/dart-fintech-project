//accounts table not transacttion table orrr...
//accounts table is list of all accounts which makes no sense if i just link them to Transaction
//then in transaction table its identified using the virtual account number and thats how its filtered..

//transaction table no need for a transaction history table right, i prefer this logic
//interacts with virtualaccounts and Transaction table to also populate the transaction table
//list all transactions(Acc name, bank, acc no, reference number, remark, amt, date, status, payment method)
//list transaction history
//send money (diff. transfers from liq acc to liq acc, from liq acc to personal acc, request money
//from other liq accs)
//receive money(topup liq acc from card, receive money using liq acc(???idk not sure how i'd do this tho?))
//withdraw money
import 'package:decimal/decimal.dart';
import 'package:liquidmoniproject/liquidmoniproject.dart';
import 'package:liquidmoniproject/src/services/enums.dart';
import 'package:liquidmoniproject/src/services/paymentpostingservices.dart';

class TransactionController {
  TransactionController(this._reqBody, Db db)
      : _req = _reqBody.request,
        _store2 = db.collection('users'),
        _store3 = db.collection('transactions'),
        _store = db.collection('virtualaccounts') {
    endpoints();
  }

  final HttpRequestBody _reqBody;
  final HttpRequest _req;
  final DbCollection _store, _store2, _store3;

  endpoints() async {
    var pathName = _req.uri.path;
    const path = '/Transactions';
    //confirm request types
    switch (_req.method) {
      case 'GET':
        //confirm name of endpoints
        switch (pathName) {
          //get list of Transactions
          case '$path/getAllTransactions':
            await getAllTransactions();
            break;
          //get Transaction details
          case '$path/getTransaction':
            String referenceNo = (_req.uri.queryParameters['ref_number']!);
            await getTransactionByRefNumber(referenceNo);
            break;
        }

      case 'POST':
        //send money details, this can go for appproval, they can request money too
        switch (pathName) {
          case '$path/sendToLiquidMoniUser':
            String sourceAcc = (_req.uri.queryParameters['source_account']!);
            String destinationAcc =
                (_req.uri.queryParameters['destination_account']!);
            Decimal amount = Decimal.parse(_req.uri.queryParameters['amount']!);
            int pin = int.parse(_req.uri.queryParameters['pin_code']!);
            String narration = (_req.uri.queryParameters['narration']!);
            await sendToLiquidMoniUser(
                sourceAcc, destinationAcc, amount, narration, pin);
            break;
        }

      default:
        _req.response.statusCode = 405;
    }
    await _req.response.close();
  }

  getAllTransactions() async {
    _req.response.write(await _store.find().toList());
  }

  getTransactionByRefNumber(String refNum) async {
    refNum = (_req.uri.queryParameters['ref_number']!);
    if (refNum != "") {
      var itemToFind = await _store.findOne(where.eq('ref_number', refNum));
      if (itemToFind != null) {
        _req.response.write(itemToFind);
      } else {
        _req.response.statusCode = HttpStatus.notFound;
      }
    } else {
      _req.response.statusCode = HttpStatus.badRequest;
    }
  }

  sendToLiquidMoniUser(String sourceAcc, String destinationAcc, Decimal amount,
      String narration, int pin) async {
    //do some validation
    //or receive destination accounts as objects? No.

    if (sourceAcc.isEmpty) {
      _req.response.write('Please enter source account number.');
    }
    if (destinationAcc.isEmpty) {
      _req.response.write('Please enter destination account number.');
    }
    //crosscheck that this does what you want it to do
    if (amount <= Decimal.zero) {
      _req.response.write('Please enter a valid amount.');
    }
    bool status = false;
    //hash pin and crosscheck that pin is right
    if (pin < 0 || pin.toString().length != 4) {
      _req.response.write('Invalid pin.');
    } else {
      var itemToFind =
          await _store2.findOne(where.eq('accountNumber', sourceAcc));
      if (itemToFind != null) {
        if (itemToFind['pin_code'] == pin) {
          status = true;
        }
      }
    }
    var transactionType = TransactionType.userToUser;

    String refNum = generateRefNumber();
    //smoothen logic here so that ref number isnt repeated.
    var doesRefNumExist =
        await _store.findOne(where.eq('accountNumber', refNum));
    if (doesRefNumExist != null) {
      refNum = generateRefNumber();
    }
    //transfer process for the money
    creditInHouseUser(amount, destinationAcc);
    debitInHouseUser(amount, sourceAcc);
    //update transaction account
    var newTransaction = {
      "date_of_transaction": DateTime.now(),
      "source_account": sourceAcc,
      "destination_account": destinationAcc,
      "amount": amount,
      "narration": narration,
      "status": status,
      "ref_number": refNum,
      "transactionType": transactionType
    };
    _req.response.write(await _store3.insertOne(newTransaction));
  }

  creditInHouseUser(amount, destinationAcc) async {
    var itemToFind =
        await _store.findOne(where.eq('accountNumber', destinationAcc));
    if (itemToFind != null) {
      Decimal newAmount = amount + itemToFind['balance_amount'];
      _req.response.write(await _store.updateOne(
          itemToFind, modify.set("balance_amount", newAmount)));
    } else {
      _req.response
          .write('Phone Number could not be confirmed. Please try again.');
    }
  }

  debitInHouseUser(amount, sourceAcc) async {
    var itemToFind = await _store.findOne(where.eq('accountNumber', sourceAcc));
    if (itemToFind != null) {
      if (itemToFind['balance_amount'] >= amount) {
        Decimal newAmount = itemToFind['balance_amount'] - amount;
        _req.response.write(await _store.updateOne(
            itemToFind, modify.set("balance_amount", newAmount)));
      } else {
        _req.response.write('Insufficient balance. Please try again.');
      }
    } else {
      _req.response
          .write('Phone Number could not be confirmed. Please try again.');
    }
  }
  //freeze or flag and reverse transactions
}
