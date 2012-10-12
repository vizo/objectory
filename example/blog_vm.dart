library blog_example;
import 'package:objectory/objectory_vm.dart';
import 'domain_model.dart';

const Uri = 'mongodb://127.0.0.1/objectory_blog';
main(){
  objectory = new ObjectoryDirectConnectionImpl(Uri,registerClasses,true);
  var authors = new Map<String,Author>();
  var users = new Map<String,User>();  
  objectory.initDomainModel().chain((_) {
    print("===================================================================================");
    print(">> Adding Authors");
    var author = new Author();
    author.name = 'William Shakespeare';
    author.email = 'william@shakespeare.com';
    author.age = 587;
    author.save();
    author = new Author();
    author.name = 'Jorge Luis Borges';
    author.email = 'jorge@borges.com';
    author.age = 123;
    author.save();    
    return objectory.find($Author.sortBy('age'));
  }).chain((auths){  
    print("===================================================================================");
    print(">> Authors ordered by age ascending");
    for (var auth in auths) {
      authors[auth.name] = auth;
      print("[${auth.name}]:[${auth.email}]:[${auth.age}]");
    }
    print("===================================================================================");
    print(">> Adding Users");
    var user = new User();
    user.name = 'John Doe';
    user.login = 'jdoe';
    user.email = 'john@doe.com';
    user.save();
    user = new User();
    user.name = 'Lucy Smith';
    user.login = 'lsmith';
    user.email = 'lucy@smith.com';
    user.save();
    return objectory.find($User.sortBy('login'));
  }).chain((usrs){  
    print("===================================================================================");
    print(">> >> Users ordered by login ascending");
    for (var user in usrs) {
      print("[${user.login}]:[${user.name}]:[${user.email}]");      
      users[user.login] = user;
    }
    print("===================================================================================");
    print(">> Adding articles");
    var article = new Article();
    article.title = 'Caminando por Buenos Aires';
    article.body = 'Las callecitas de Buenos Aires tienen ese no se que...';
    article.author = authors['Jorge Luis Borges'];
    var comment = new Comment();
    comment.date = new Date.fromMillisecondsSinceEpoch(new Date.now().millisecondsSinceEpoch - 780987497);
    comment.body = "Well, you may do better...";
    comment.user = users['lsmith'];
    article.comments.add(comment);
    objectory.save(article);            
    comment = new Comment();
    comment.date = new Date.fromMillisecondsSinceEpoch(new Date.now().millisecondsSinceEpoch - 90987497);
    comment.body = "I love this article!";
    comment.user = users['jdoe'];
    article.comments.add(comment);    
    article.save();
    
    article = new Article();
    article.title = 'I must have seen thy face before';
    article.body = 'Thine eyes call me in a new way';
    article.author = authors['William Shakespeare'];
    comment = new Comment();
    comment.date = new Date.fromMillisecondsSinceEpoch(new Date.now().millisecondsSinceEpoch - 20987497);
    comment.body = "great article!";
    comment.user = users['jdoe'];
    article.comments.add(comment);
    article.save();
    return objectory.find($Article);  
  }).chain((articles){
    print("===================================================================================");
    print(">> Printing articles");
    return Futures.wait(articles.map((article) => printArticle(article)));     
  }).chain((_) {
    return objectory.dropCollections();
  }).then((_) {
   objectory.close();
  });      
}

Future printArticle(article) { 
  var completer = new Completer();      
  article.fetchLinks().then((__) {        
    print("${article.author.name}:${article.title}:${article.body}");
    for (var comment in article.comments) {
      print("     ${comment.date}:${comment.user.name}: ${comment.body}");     
    }
    completer.complete(true);
  });
  return completer.future;  
}
