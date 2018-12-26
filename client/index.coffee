NodeRSA    = require 'node-rsa'
CryptoJS   = require 'crypto-js'
LazyValue   = require 'functors/LazyValue'

$ = window.jQuery = require 'jquery'
require "jquery-ui-bundle"

addAddress = (name, pem, cb) ->
  console.log "addAddress", name, pem
  if not pem
    randomKey = new NodeRSA b: 1024
    pem = randomKey.exportKey 'public'
  $.ajax
    method: "POST"
    contentType: 'application/json'
    url: "/addPems"
    data: JSON.stringify {name,pem}
  .done ( msg ) ->
    cb null, msg
  .fail (args...) ->
    cb args

myEncryptedKey = new LazyValue (cb) ->
  name = prompt "My name:"
  $("#name-span").text "'#{name}'"
  $.ajax
    url: "/getKeys"
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
      url: '/addKeys'
      contentType: 'application/json'
      data: JSON.stringify {name: name, key: encryptedKey}
    .always console.log.bind console
    cb null, encryptedKey
    addAddress name, key.exportKey('public'), console.log.bind console
  .done ( data ) ->
    cb null, data[0].key

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
  $.ajax "/getPems"
  .fail (args...) ->
    cb args
  .done (res) ->
    cb null, res

getMyEncryptedLetters = ( cb ) ->
  myPublicKey.get ( err, pubKey ) ->
    $.ajax
      url: '/getLetters'
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
    dest: address
    msg: pubKey.encrypt text,'base64'
  $.ajax
    method: 'POST'
    url: "/addLetters"
    contentType: 'application/json'
    data: JSON.stringify msg
  .done -> cb()
  .fail (args...) -> cb args

update_inbox = ->
  getMyEncryptedLetters ( err, letters=[] ) ->
    $list = $('#msgs-ul').empty()
    letters.forEach (letter) ->
      date = new Date letter.time
      $list
      .append $('<li>').append $('<a href="#">').append("Date: #{date}").click ->
        decryptMessage letter.msg, (err, msg) ->
          $bot = $('#msg-div').empty()
          .append [ 
            $("<p>").append "Sent: #{date}"
            $("<pre>").append msg]

update_write = ->
  getYp (err, yp) ->
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
          $('#pem-div').empty().append [ 
            $("<p>").append "Name: #{entry.name}"
            $("<pre>").append entry.pem] 
      ]

$ ->
  $('#reload-btn').click ->
    update_inbox()
    update_yp()
  $( "#tabs" ).tabs {
    heightStyle: "fill"
    beforeActivate: (event, ui) ->
      switch ui.newPanel[0].id
        when 'inbox-div' 
          update_inbox()
        when 'write-div'
          update_write()
        when 'yp-div'
          update_yp()
  }
  $('#add-address-btn').click ->
    $dialog = $("#new-address-div").empty().append [
      "Name:"
      $addressName = $ '<input>'
      "Address:"
      $addressPem = $ '<textarea>' 
    ]
    .dialog {
      width: 700
      buttons: [
        text: "Save"
        click: ->
          me = $ this
          addAddress $addressName.val(), $addressPem.val().trim(), (err) ->
            console.log err if err
            me.dialog 'close'
            update_yp()]
    } 
  update_inbox()

