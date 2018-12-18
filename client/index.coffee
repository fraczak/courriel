NodeRSA    = require 'node-rsa'
CryptoJS   = require 'crypto-js'
LazyValue   = require 'functors/LazyValue'

addAddress = (name, pem, cb) ->
  console.log "addAddress", name, pem
  if not pem
    randomKey = new NodeRSA b: 1024
    pem = randomKey.exportKey 'public'
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
  $("#name-span").text "'#{name}'"
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

decryptMessage = ( msg, cb ) ->
  myKey.get ( err, key) ->
    return cb err if err
    result = "Failed to decrypt";
    try
      result = key.decrypt(msg, 'utf8');
    catch e
      console.warn "Problem: #{e}"
    cb null, result

newMessage = (text, address, cb) ->
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
  .done -> cb()
  .fail console.log.bind console

update_inbox = ->
  getMyEncryptedLetters ( err, letters ) ->
    # return cb err if err
    $list = $('#msgs-ul').empty()
    letters.forEach (letter) ->
      date = new Date letter.time
      $list
      .append $('<li>').append $('<a href="#">').append("Date: #{date}").click ->
        decryptMessage letter.msg, (err, msg) ->
          $bot = $('#bot-div').empty()
          .append [ 
            $("<p>").append "Sent: #{date}"
            $("<pre>").append msg]

update_write = ->
  getYp (err, yp) ->
    return cb err if err
    $textarea = $('#text-area').empty()
    $addresses = Object.keys(yp).map ( addr ) ->
      $('<option value="'+addr+'">').append yp[addr].name
    $to = $('#write-select').empty().append $addresses 
    $('#send-btn').off().click ->
      return false if $textarea.val().trim() is ""
      newMessage $textarea.val(), yp[$to.val()].pem, (err) ->
        return alert "ERROR: #{err}" if err
        alert "Message sent"
        $textarea.val ""
        update_write()
    
update_yp = ->
  getYp ( err, yp) ->
    return cb err if err
    $list = $('#address-ul').empty()
    Object.keys(yp).forEach (pem) ->
      entry = yp[pem]
      $list
      .append [
        $('<li>').append $('<a href="#">').append entry.name
        .click ->
          $dialog = $('<div>').append [ 
            $("<p>").append "Name: #{entry.name}"
            $("<pre>").append entry.pem]
          $('body').append $dialog
          $dialog.dialog width: 600 
      ]
    

update_all = ->
  update_inbox()
  update_write()
  update_yp()

$ ->
  $('#reload-btn').click update_all
  $( "#tabs" ).tabs heightStyle: "fill"
  $ '#add-address-btn'
  .click ->
    do ($dialog = $("<div>").append [
      "Name:"
      $ '<input id="address-name">'
      "Address:"
      $ '<textarea id="address-pem">' 
    ]) ->
      $('body').append $dialog
      $dialog.dialog {
        width: 700
        buttons: [
          text: "Save"
          click: ->
            me = $ this
            addAddress $('#address-name').val(), $('#address-pem').val().trim(), (err) ->
              console.log err if err
              me.dialog 'close'
              update_yp()
              update_write()
        ]
      } 
  update_all()

