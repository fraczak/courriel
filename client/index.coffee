NodeRSA    = require 'node-rsa'
CryptoJS   = require 'crypto-js'
{LazyValue, helpers, product, delay, compose}    = require 'functors'

$ = window.jQuery = require 'jquery'
require "jquery-ui-bundle"

myPassword = new LazyValue (cb) ->
  do (password = prompt "password") ->
    cb null, password

tags = new LazyValue (cb) ->
  myPassword.get (err, password) ->
    return cb(err) if err?
    sha = CryptoJS.SHA1(password).toString()
    cb null, {
      id: sha[0..19]
      yp: sha[20..39]
    }

newId = ({password,key}, cb) ->
  key ?= new NodeRSA b: 1024
  console.log "newId:public", key.exportKey 'public'
  data = JSON.stringify type: "id", key: key.exportKey()
  encryptedData = CryptoJS.AES.encrypt data, password
  .toString()
  tags.get (err, tags) ->
    return cb (err) if err?
    $.ajax
      url: "/addData"
      method: "POST"
      contentType: "application/json"
      data: JSON.stringify data: encryptedData, tag: tags['id']
    .done (msg) ->
      cb null, key
    .fail (args...) ->
      cb args

myIds_fetcher = (cb) ->
  product(myPassword.get, tags.get) "token", (err, [password, tags]) ->
    return cb (err) if err?
    $.ajax
      url: "/getData"
      data: tag: tags['id']
    .done ( dataz ) ->
      result = dataz
      .map (data) ->
        try
          data = JSON.parse CryptoJS.AES.decrypt(data.data, password).toString CryptoJS.enc.Utf8
          return data if data.type is "id"
      .filter (x) ->
        not helpers.isEmpty x
        
      if helpers.isEmpty result
        newId {password}, (err, data) ->
          cb err, [data]
      else
        cb null, result.map (data) ->
          new NodeRSA data.key

myIds = new LazyValue myIds_fetcher

addAddress = ( name, pem, cb ) ->
  product(myPassword.get, tags.get) "token", ( err, [password, tags] ) ->
    return cb err if err?
    yp = { type: 'yp', pem, name }
    yp  = CryptoJS.AES.encrypt (JSON.stringify yp), password
    .toString()
    $.ajax
      method: 'POST'
      url: "/addData"
      contentType: 'application/json'
      data: JSON.stringify data: yp, tag: tags['yp']
    .fail (args...) -> cb args
    .done (res) -> cb null

getMyLetters = ( cb ) ->
  myIds.get (err, keys) ->
    return cb err if err?
    $.ajax 
      method: 'GET'
      url: "/getData"
      contentType: 'application/json'
    .fail (args...) -> cb args
    .done ( dataz ) ->
      letters = dataz
      .map (data) ->
        for key in keys
          try
            return JSON.parse key.decrypt data.data, 'utf8'
        null  
      .filter (data) -> not helpers.isEmpty data
      cb null, letters

getYp = ( cb ) ->
  product(myPassword.get, tags.get) "token", (err, [password, tags]) ->
    return cb err if err
    $.ajax
      url: "/getData"
      data: tag: tags['yp']
    .fail (args...) ->
      cb args
    .done (dataz) ->
      yp = dataz
      .map (data) ->
        try
          data = CryptoJS.AES.decrypt data.data, password
          .toString CryptoJS.enc.Utf8
          data = JSON.parse data
          return data if data.type is "yp"
      .filter (data) -> not helpers.isEmpty data
      cb null, yp

newMessage = (text, address, cb) ->
  pubKey = new NodeRSA address
  msg = JSON.stringify msg: text, time: (new Date()).getTime()
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
    letters
    .map (l) -> Object.assign l, {time: new Date l.time}
    .sort (a, b) ->
      return -1 if a.time > b.time 
      return 1 if a.time < b.time
      0    
    .forEach (letter) ->
      date = letter.time.toLocaleString()
      preview = letter.msg.trimStart().replace(/\s\s+/g, ' ').substring(0,80)
      $list.append do ->
        $('<li>').append [
          $('<a href="#">').addClass("label").text date
          $('<span>').text " : #{preview}"
        ]
        .click ->
          $me = $(this)
          $me.siblings().removeClass "selected"
          $me.addClass "selected" 
          $bot = $('#msg-div').empty()
          .append [
            $('<p class="label">').text "Sent: #{date}"
            $('<pre class="msg">').text letter.msg
          ]
          
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
    
show_keys = ->
  myIds.get (err, myIds) ->
    return cb err if err
    $keys = $('#keys')
    .empty()
    .append myIds.map (key) ->
      $('<div class="border">').append [
        $('<pre>').text key.exportKey()
        $('<pre>').text key.exportKey "public"
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
        when 'keys-div'
          show_keys()
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
            console.warn err if err
            me.dialog 'close'
            update_yp()
      ]
    }

  $('#new-key-btn').click ->
    myIds.get (err, ids = []) ->
      $d = $('#add-key-dialog').empty().append [
        "You have #{ids.length} key(s). "
        "Do you want to add an existing key or generate a new one?"
      ]
      .dialog
        resizable: false
        height: "auto"
        width: 400
        modal: true
        buttons:
          "Add existing": ->
            $g = $("#gen-key-dialog").empty().append [
              "Paste in private key (PEM):"
              $pemKey = $ '<textarea>' 
            ]
            .dialog
              width: 700
              buttons: 
                "Save": ->
                  try 
                    key = new NodeRSA $pemKey.val().trim()
                  catch err
                    console.error err
                    $g.dialog "close"
                    $d.dialog "close"
                    return
                  compose([
                    myPassword.get
                    delay (password) -> {password,key}
                    newId
                    myIds.get
                  ]) "token", (err, $keys) ->
                    $g.dialog "close"
                    $d.dialog "close"
                    return console.warn(err) if err? 
                    myIds = new LazyValue myIds_fetcher
                    show_keys()

          "Generate": ->
            compose([
              myPassword.get
              delay (password) -> {password}
              newId
              myIds.get
            ]) "token", (err, $keys) ->
              $d.dialog "close"
              return console.warn(err) if err? 
              myIds = new LazyValue myIds_fetcher
              show_keys() 

  update_inbox()

