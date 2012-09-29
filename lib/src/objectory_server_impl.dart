#library('objectory_server_impl');
#import('dart:io');
#import('json_ext.dart');
#import('package:mongo_dart/mongo.dart');
#import('package:mongo_dart/bson.dart');
#import('package:logging/logging.dart');
#import('log_helper.dart');

final IP = '127.0.0.1';
final PORT = 8080;
final URI = 'mongodb://127.0.0.1/objectory_server_test';

//Map<String, ObjectoryClient> connections;
List chatText;
Db db;
class RequestHeader {
  String command;
  String collection;
  int requestId;
  RequestHeader.fromMap(Map commandMap) {
    command = commandMap['command'];
    collection = commandMap['collection'];
    requestId = commandMap['requestId'];    
  }
  Map toMap() => {'command': command, 'collection': collection, 'requestId': requestId};
  String toString() => 'RequestHeader(${toMap()})';
}
class ObjectoryClient {
  int token;  
  String name;
  WebSocketConnection conn;
  bool closed = false;
  ObjectoryClient(this.name, this.token, this.conn) {
    conn.send(JSON.stringify([{'command':'hello'}, {'connection':this.name}]));
    conn.onMessage = (message) {
      log.fine('message is $message');
      var jdata = JSON.parse(message);      
      var header = new RequestHeader.fromMap(jdata[0]);
      Map content = jdata[1];
      if (header.command == "save") {
        save(header,content);
        return;
      }
      if (header.command == "findOne") {
        findOne(header,content);
        return;
      }
      if (header.command == "find") {
        find(header,content);
        return;
      }
      if (header.command == "queryDb") {
        queryDb(header,content);
        return;
      }      
      log.shout('Unexpected message: $message');
      sendResult(header,content);
    };
    
    conn.onClosed = (int status, String reason) {
      log.info('closed with $status for $reason');
      closed = true;
    };    
  }
  sendResult(RequestHeader header, content) {
    log.fine('sendResult($header, $content) ');
    if (closed) {
      log.shout('ERROR: trying send on closed connection. $header, $content');
    } else {
      conn.send(JSON.stringify([header.toMap(),content]));
    }      
  }
  save(RequestHeader header, Map mapToSave) {
    var createdId;
    if (mapToSave !== null && header.collection !== null) {
      if (mapToSave["_id"] === null) {
        createdId = new ObjectId(); 
        mapToSave["_id"] = createdId;
        db.collection(header.collection).insert(mapToSave);
      } else {
        db.collection(header.collection).save(mapToSave);     
      }       
      db.getLastError().then((responseData) {
        log.fine('$responseData');
        if (createdId !== null) {
          responseData["createdId"] = createdId;
        }
        sendResult(header, responseData);
      });
    }
    else {
      protocolError('Command: save, MapToSave: $mapToSave');
    }
  }
  
  find(RequestHeader header, Map selector) {        
    db.collection(header.collection).find(selector).toList().
    then((responseData) {       
      sendResult(header, responseData);          
    });
  }

  findOne(RequestHeader header, Map selector) {      
    db.collection(header.collection).findOne(selector).
    then((responseData) {       
      sendResult(header, responseData);          
    });
  }
  
  queryDb(RequestHeader header,Map query) {
    db.executeDbCommand(DbCommand.createQueryDBCommand(db,query))
    .then((responseData) {
      log.fine('$responseData');
      sendResult(header,responseData);
    });
  }
  
  
  
  protocolError(String errorMessage) {
    log.shout('PROTOCOL ERROR: $errorMessage');
    conn.send(JSON.stringify({'error': errorMessage}));
  }    
  
  
  String toString() {
    return "${name}_${token}";
  }
}

class ObjectoryServerImpl {
  String hostName; 
  int port;
  String mongoUri;
  ObjectoryServerImpl(this.hostName,this.port,this.mongoUri){
    chatText = [];
    int token = 0;
    HttpServer server;
    db = new Db(mongoUri);
    db.open().then((_) {
      server = new HttpServer();
      WebSocketHandler wsHandler = new WebSocketHandler();
      server.addRequestHandler((req) => req.path == '/ws', wsHandler.onRequest);
      configureConsoleLogger(Level.ALL);
      wsHandler.onOpen = (WebSocketConnection conn) {
        token+=1;
        var c = new ObjectoryClient('objectory_client_${token}', token, conn);
        log.info('adding connection token = ${token}');
      };    
      print('listing on http://$hostName:$port\n');      
      log.fine('MongoDB connection: ${db.serverConfig.host}:${db.serverConfig.port}');
      server.listen(hostName, port);
    });    
  }
}
