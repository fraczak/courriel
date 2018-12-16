$          = require 'jquery'
NodeRSA    = require 'node-rsa'
CryptoJS   = require 'crypto-js'
LazyValue   = require 'functors/LazyValue'

$focus = $ '#focus'
$body  = $ '#body'

addAddress = (name, pem, cb) ->
  if not pem 
    pem = randomKey.exportKey 'public'
    randomKey = new NodeRSA b: 1024
  $.ajax
    method: "POST"
    contentType: 'application/json'
    url: "/addAddress"
    data: JSON.stringify {name,pem}
  .done ( msg ) ->
    cb null, msg
  .fail (args...) ->
    cb args

myEncryptedKey = new LazyValue (cb) ->
  name = prompt "My name:"
  $.ajax 
    url: "/encryptedKey"
    data: name: name
  .fail ( jqXHR, textStatus, errorThrown ) ->
    console.log jqXHR, textStatus, errorThrown
    # we do not have our key yet
    key = new NodeRSA b: 1024
    password = prompt "New password" 
    encryptedKey = CryptoJS.AES.encrypt key.exportKey(), password
    .toString()
    password = ""
    $.ajax
      method: 'POST'
      url: '/storeEncryptedKey'
      contentType: 'application/json'
      data: JSON.stringify {name: name, key: encryptedKey}
    .always console.log.bind console
    cb null, encryptedKey
    addAddress name, key.exportKey('public'), console.log.bind console
  .done ( data ) ->
    cb null, data.key

myKey = new LazyValue ( cb ) ->
  myEncryptedKey.get (err, encryptedKey) ->
    return cb err if err
    key = null 
    for i in [1..10]
      pem = null
      try 
        password = prompt "#{i}. Password check:"
        pem = CryptoJS.AES.decrypt encryptedKey, password
          .toString CryptoJS.enc.Utf8
        password = ""
        key = new NodeRSA pem
        return cb null, key
      catch e 
        alert "Try again..."  
    cb Error "Hymmm... ?"

myPublicKey = new LazyValue ( cb ) ->
  myKey.get (err, key) ->
    return cb err if err
    cb null, key.exportKey 'public'

getYp = ( cb ) ->
  $.ajax "/yp"
  .fail (args...) ->
    cd args
  .done (res) ->
    cb null, res

getMyEncryptedLetters = ( cb ) ->
  myPublicKey.get ( err, pubKey ) ->
    $.ajax
      url: '/letters'
      data: pem: pubKey 
    .fail (args...) -> cb args
    .done ( data ) ->
      cb null, data

yp = new LazyValue getYp 
myEncryptedLetters = new LazyValue getMyEncryptedLetters

decryptMessage = ( msg, cb ) ->
  myKey.get ( err, key) ->
    return cb err if err
    result = "Failed to decrypt";
    try 
      result = key.decrypt(msg, 'utf8');
    catch e
      console.warn "Problem: #{e}"
      
    cb null, result

newMessage = (text, address) ->
  console.log "->", address
  pubKey = new NodeRSA address
  msg = 
    time: new Date()
    to: address
    msg: pubKey.encrypt text,'base64'
  $.ajax
    method: 'POST'
    url: "/postMessage"
    contentType: 'application/json'
    data: JSON.stringify msg
  .always console.log.bind console

redraw_view = ->
  $content = null
  switch $focus.val()
    when "inbox" 
      myEncryptedLetters.get ( err, letters ) ->
        return cb err if err
        $list = $ '<ul>'
            
        letters.forEach (letter) ->
          $list
          .append $('<li>').append $('<a href="#">').append("Date: #{new Date letter.time}").click ->
            decryptMessage letter.msg, (err, msg) ->
              alert "Sent: #{new Date letter.time}\n\n #{msg}"
            
        $reload = $ '<button>'
        .append "Reload"
        .click ->
          yp = new LazyValue getYp 
          myEncryptedLetters = new LazyValue getMyEncryptedLetters 
          redraw_view()
        $content =  [$list, $reload]
        $body.empty().append $content
    when "write" 
      yp.get (err, yp) ->
        return cb err if err
        $textarea = $ '<textarea>'
        $addresses = Object.keys(yp).map ( addr ) ->
          $('<option value="'+addr+'">').append yp[addr].name
        $to = $('<select>').append $addresses 
        $newMessage = $('<button>').append "New Message"
        .click ->
          newMessage $textarea.val(), yp[$to.val()].pem
          $textarea.val ""
          redraw_view()
        $content = [ "Compose a new message...", $to, $textarea, $newMessage ]
        $body.empty().append $content
    when "yp"
      yp.get ( err, yp) ->
        return cb err if err 
        $list = $ '<ul>'
        Object.keys(yp).forEach (pem) ->
          entry = yp[pem]
          $list
          .append $ '<li>'
          .append( 
            $ '<a href="#">'
            .append entry.name
            .click ->
              alert JSON.stringify entry
          )
        $newAddress = $ '<button>'
        .append "New Address"
        .click ->
          addAddress "user_" + Object.keys(yp).length, null, console.log.bind console 
          redraw_view()
        $content =  ["Address book...", $list, $newAddress ]
        $body.empty().append $content
    
$focus.change redraw_view 

redraw_view()

