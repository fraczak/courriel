var $          = require('jquery');
var NodeRSA    = require('node-rsa');
var CryptoJS   = require('crypto-js');
var superagent = require('superagent');
var LazyValue   = require('functors').LazyValue;


var log = console.log.bind(console);
var warn = console.warn.bind(console);
var error = console.error.bind(console);

var $focus = $('#focus');
var $body  = $('#body');

var addAddress = function(name, pem, cb) {
    if (! cb) cb = log;
    if (! pem ) {
        var randomKey = new NodeRSA({b: 512});
        pem = randomKey.exportKey('public');
    }
    superagent
        .post("/addAddress")
        .send({pem:pem, name:name})
        .end( cb );
};

var myEncryptedKey = new LazyValue( function( cb ) {
    superagent
        .get("/encryptedKey")
        .end( function(err, res) {
            if (err) return cb(err);
            var password="???";
            var encryptedKey = res.body;
            if (! encryptedKey) {
                // we do not have our key yet
                var key = new NodeRSA({b: 512});
                var name = prompt("My full name");
                password = prompt("New password");
                encryptedKey = CryptoJS.AES.encrypt(key.exportKey(), password)
                    .toString();
                password = "";
                superagent
                    .post("/storeEncryptedKey")
                    .send({encryptedKey: encryptedKey})
                    .end(log);
                // add my public key to the yp
                addAddress((name || "me"), key.exportKey('public'), log);
            }
            return cb(null, encryptedKey);
        });
});

var myKey = new LazyValue( function( cb ) {
    myEncryptedKey.get( function(err, encryptedKey) {
        if (err) return cb(err);
        var key, password;
        while (true) {
            var pem = null;
            try {
                password = prompt("Password check:");
                pem = CryptoJS.AES.decrypt(encryptedKey, password)
                    .toString(CryptoJS.enc.Utf8);
                password = "";
                key = new NodeRSA(pem);
                break;
            } catch (e) {
                alert("Try again...");
            }
        }
        return cb(null, key);
    });
});

var myPublicKey = new LazyValue( function( cb ) {
    myKey.get( function(err, key) {
        if (err) return cb(err);
        return cb(null, key.exportKey('public'));
    });
});

var getYp = function( cb ) {
    superagent
        .get("/yp")
        .end( function(err, res) {
            if (err) return cb(err);
            return cb(null, res.body);
        });
};

var getMyEncryptedLetters = function( cb ) {
    myPublicKey.get( function(err, pubKey) {
        superagent
            .get("/letters")
            .query({pem: pubKey})
            .end( function(err, res) {
                if (err) return cb(err);
                return cb(null, res.body);
            });
    });
};

var yp = new LazyValue( getYp );
var myEncryptedLetters = new LazyValue( getMyEncryptedLetters );

var decryptMessage = function( msg, cb ) {
    myKey.get( function(err, key) {
        if (err) return cb(err);
        var result = "Failed to decrypt";
        try {
            result = key.decrypt(msg, 'utf8');
        } catch (e) {
            warn("Problem: " + e);
        }
        return cb(null, result);
    });
};

var newMessage = function(text, address) {
    var pubKey = new NodeRSA(address);
    var msg = {date:new Date(), to: address, msg: pubKey.encrypt(text,'base64')};
    superagent
        .post("/postMessage")
        .send(msg)
        .end(log);
};

var redraw_view = function() {
    var $content;
    switch($focus.val()) {
    case "inbox" :
        myEncryptedLetters.get( function(err, letters) {
            var $list = $('<ul>');
            if (err) error(err);
            else {
                letters.forEach( function(letter) {
                    $list.append($('<li>').append(
                        $('<a href="#">').append("Date: "+letter.date).click( function() {
                            decryptMessage( letter.msg, function(err, msg) {
                                alert("Sent: "+letter.date+"\n\n"+ msg );
                            });
                        })));
                });
                var $reload = $('<button>').append("Reload")
                    .click( function() {
                        yp = new LazyValue( getYp );
                        myEncryptedLetters = new LazyValue( getMyEncryptedLetters );
                        redraw_view();
                    });
                $content =  [$list, $reload];
                $body.empty().append($content);
            }
        });
        break;
    case "write" :
        yp.get( function(err, yp) {
            if (err) error(err);
            else {
                var $textarea = $('<textarea>');
                var $addresses = Object.keys(yp).map( function( addr ) {
                    return $('<option value="'+addr+'">').append(yp[addr].name);
                });
                var $to = $('<select>').append( $addresses );
                var $newMessage = $('<button>').append("New Message")
                    .click(function(){
                        newMessage($textarea.val(), $to.val());
                        $textarea.val("");
                        redraw_view();
                    });
                $content = [ "Compose a new message...", $to, $textarea, $newMessage ];
                $body.empty().append($content);
            }
        });
        break;
    case "yp" :
        yp.get( function( err, yp) {
            if (err) error(err);
            else {
                var $list = $('<ul>');
                Object.keys(yp).forEach( function(pem) {
                    var entry = yp[pem];
                    $list.append($('<li>').append(
                        $('<a href="#">').append(entry.name).click(function(){
                            alert(JSON.stringify(entry));
                        }))
                                );
                });
                var $newAddress = $('<button>').append("New Address")
                    .click(function(){ addAddress("user_" + Object.keys(yp).length); redraw_view(); });
                $content =  ["Address book...", $list, $newAddress ];
                $body.empty().append($content);
            }});
        break;
    };
};

$focus.change( redraw_view );

redraw_view();

