import 'package:liquidmoniproject/liquidmoniproject.dart';
//import 'package:mongo_dart/mongo_dart.dart';

main(List<String> arguments) async {
  int port = 8089;
  var server = await HttpServer.bind('localhost', port);
  //Db db = Db('mongodb://localhost:27017/liquidmoni');
  Db db;
  db = await Db.create(
      'mongodb+srv://oseno:LWYYtWTi07G5hXc2@cluster0.mk2cndw.mongodb.net/liquidmoni_db?retryWrites=true&w=majority');
  await db.open();
  if (db.isConnected) {
    print('Connected to database');
  } else {
    print('Error connecting');
  }

  server.transform(HttpBodyHandler()).listen((HttpRequestBody reqBody) async {
    var request = reqBody.request;
    var response = request.response;

    var path = request.uri.path;
    if (path.endsWith("/")) {
      response.write('Welcome to the liquidmoni api.');
      await response.close();
    } else if (path.contains("/users")) {
      UserController(reqBody, db);
    } else if (path.contains("/transactions")) {
      UserController(reqBody, db);
    } else if (path.contains("others")) {
    } else {
      response
        ..statusCode = HttpStatus.notFound
        ..write('Not Found');
      await response.close();
    }
  });

  print('Server listening at http://localhost:$port');
}
