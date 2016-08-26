var conf = require(
    process.argv.reduce(
        function(res,x){
            if (res == "-f" || x == "-f") 
                return x;
            else 
                return res;
        }, null
    ));

console.log(JSON.stringify(conf,"",2));


var express = require("express");
var body_parse  = require('body-parser');
var json_file_object = require("json-file-object");
var peers = require("./peers");

var app = express();

var etat = json_file_object({
    file: conf["db.file"],
    value: {
        encryptedKey: null,
        yp: {},
        letters: []
    }
});

peers(etat, conf["peers"]);

app.locals.pretty = true;

app.get("/", function(req,res) {
    res.render("courriel.pug");
});

app.post("/storeEncryptedKey", body_parse.json(), function(req,res) {
    console.log(req.body.encryptedKey);
    etat.encryptedKey = req.body.encryptedKey;
    res.json("ok");
});

app.post("/addAddress", body_parse.json(), function(req,res) {
    etat.yp[req.body.pem] = req.body;
    res.json("Address added");
});

app.post("/postMessage", body_parse.json(), function(req,res) {
    etat.letters.push(req.body);
    res.json("Message posted");
});

app.get("/etat", function(req,res) {
    res.json(etat);
});

app.get("/encryptedKey", function(req,res) {
    res.json(etat.encryptedKey);
});

app.get("/yp", function(req,res) {
    res.json(etat.yp);
});

app.get("/letters", function(req,res) {
    var pem = req.query.pem;
    var filter = function(){return true;};
    if (pem)
        filter = function(x){ return x.to == pem; };
    res.json(etat.letters.filter(filter));
});

app.use(express.static('public'));

app.listen(conf["port"]);
