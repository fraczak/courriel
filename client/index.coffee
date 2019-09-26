NodeRSA    = require 'node-rsa'
CryptoJS   = require 'crypto-js'
LazyValue   = require 'functors/LazyValue'

$ = window.jQuery = require 'jquery'
require "jquery-ui-bundle"

myPassword = new LazyValue (cb) ->
  do (password = prompt "password") ->
    cb null, password

tags = new LazyValue (cb) ->
  myPassword.get (err, password) ->
    cb null, ["my Id", "address book"].reduce (tags, name) -> 
      tags[name] = CryptoJS.AES.encrypt name, password
      tags
    , {}



newId = (password, cb) ->
  key = new NodeRSA b: 1024
  console.log "newId", key
  data = JSON.stringify type: "id", key: key.exportKey()
  encryptedData = CryptoJS.AES.encrypt data, password
  .toString()
  tags.get (err, tags) ->
    return cb (err) if err?
    $.ajax
      url: "/addData"
      method: "POST"
      contentType: "application/json"
      data: JSON.stringify data: encryptedData, tag: tags['my Id']
    .done (msg) ->
      cb null, key
    .fail (args...) ->
      cb args

myId = new LazyValue (cb) ->
  myPassword.get (err, password) ->
    tags.get (err, tags) ->
      return cb (err) if err?
      $.ajax 
        url: "/getData"
        query: tag: tags['my Id']
      .done ( dataz ) ->        
        found = 0
        for {data} in dataz          
          try
            data = CryptoJS.AES.decrypt data, password
            .toString CryptoJS.enc.Utf8
            data = JSON.parse data
            if data.type is 'id'
              found = 1
              break
          catch e
            "continue"
        if found
          cb null, new NodeRSA data.key
        else
          newId password, cb




addAddress = ( name, pem, cb ) ->
  console.log "addAddress", name, pem
  myPassword.get ( err, password ) ->
    return cb err if err?
    myTags.get (err, tags) ->
      return cb err if err?
      getYp ( err, yp ) ->
        return cb err if err?
        yp.version++
        yp.contacts[pem] = name
        yp  = CryptoJS.AES.encrypt (JSON.stringify yp), password
        $.ajax
          method: 'POST'
          url: "/addData"
          contentType: 'application/json'
          data: JSON.stringify data: yp, tag:tags['address book']
        .fail (args...) -> cb args
        .done (res) -> cb null
            

getMyLetters = ( cb ) ->
  myId.get ( err, key) ->
    $.ajax url: '/getData'
    .fail (args...) -> cb args
    .done ( dataz ) ->
      letters = []
      for {data} in dataz
        try
          data = key.decrypt(data, 'utf8')
          letters.push JSON.parse data
        catch e
          []
      cb null, letters

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

getYp = ( cb ) ->
  tags.get (err, tags) ->
    return cb err if err
    myPassword.get (err, password) ->
      return cb err if err
      $.ajax
        url: "/getData"
        query: tag: tags['address book']
      .fail (args...) ->
        cb args
      .done (dataz) ->
        yp = version: 0
        for {data} in dataz
          try
            data = CryptoJS.AES.decrypt data, password
            .toString CryptoJS.enc.Utf8
            data = JSON.parse data
            if data.type is "yp" and (not yp.version? or data.version > yp.version)
              yp = data
              break
          catch e
            []
          if got
            cb null, yp
          else
            cb "error lol"
        cb null, res

newMessage = (text, address, cb) ->
  console.log "->", address
  pubKey = new NodeRSA address
  msg =
    msg: text
    time: 'Lol'
  msg = pubKey.encrypt msg, 'base64'
  $.ajax
    method: 'POST'
    url: "/addData"
    contentType: 'application/json'
    data: JSON.stringify data: msg
  .done -> cb()
  .fail (args...) -> cb args

update_inbox = ->
  getMyLetters ( err, letters=[] ) ->
    $list = $('#msgs-ul').empty()
    letters.forEach (letter) ->
      date = new Date letter.time
      $list
      .append $('<li>').append $('<a href="#">').text("Date: #{date}").click ->
        $bot = $('#msg-div').empty()
        .append [
          $("<p>").text "Sent: #{date}"
          $("<pre>").text letter.msg]

update_write = ->
  getYp (err, yp) ->
    $textarea = $('#text-area').empty()
    $addresses = Object.keys(yp).map ( addr ) ->
      $('<option value="'+addr+'">').text yp[addr].name
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
    Object.keys(yp).forEach (k) ->
      if k isnt 'version'
        entry = yp[k]
        $list
        .append [
          $('<li>').append $('<a href="#">').text entry.name
          .click ->
            $('#pem-div').empty().append [ 
              $("<p>").text "Name: #{entry.name}"
              $("<pre>").text entry.k] 
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

