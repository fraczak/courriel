NodeRSA    = require 'node-rsa'
CryptoJS   = require 'crypto-js'
{LazyValue, helpers, product, delay, compose}    = require 'functors'

$ = window.jQuery = require 'jquery'
require "jquery-ui-bundle"

myPassword = new LazyValue (cb) ->
  do (password = prompt "password") ->
    cb null, password

tag = new LazyValue (cb) ->
  myPassword.get (err, password) ->
    return cb(err) if err?
    cb null, CryptoJS.SHA1(password).toString()

newHandle = ({password,key}, cb) ->
  return cb Error "Key is empty" unless key?
  product(myState.get, tag.get) {}, (err, [state, tag]) ->
    return cb (err) if err?
    data = JSON.stringify {type: "handle", key: key.exportKey()}
    state.handles.push(key)
    encryptedData = CryptoJS.AES.encrypt data, password
    .toString()
    sendState encryptedData, cb

myState_fetcher = (cb) ->
  product(myPassword.get, tag.get) "token", (err, [password, tag]) ->
    return cb (err) if err?
    $.ajax
      url: "/getData"
      data: {tag}
    .done ( dataz ) ->
      state =
        handles:[]
        names:[]
        contacts:[]
      dataz.map (data) ->
        try
          data = JSON.parse CryptoJS.AES.decrypt(data.data, password).toString CryptoJS.enc.Utf8
          state.handles.push(new NodeRSA data.key) if state.type is "handle"
          state.names.push(data.name) if state.type is "name"
          state.contacts.push(data) if state.type is "contact"
          delete data.type
      cb null, state

myState = new LazyValue myState_fetcher

addContact = ( name, pem, cb ) ->
  product(myState.get, myPassword.get, tag.get) "token", ( err, [state, password, tag] ) ->
    return cb err if err?
    date = new Date()
    data = { type: 'contact', pem, date:date.getTime()}
    if name
      data = [data,{type:"name", pem,name}]
    data = CryptoJS.AES.encrypt (JSON.stringify data), password
    .toString()
    state.contacts.push({pem,date}) # TODO uniq
    sendState data, cb

sendState = (data, cb) ->
  $.ajax
    method: 'POST'
    url: "/addData"
    contentType: 'application/json'
    data: JSON.stringify {data, tag}
  .fail (args...) -> cb args, {}
  .done (res) -> cb null, {}

getMyLetters = (_, cb ) ->
  myState.get (err, state) ->
    return cb err if err?
    $.ajax 
      method: 'GET'
      url: "/getData"
      contentType: 'application/json'
    .fail (args...) -> cb args
    .done ( dataz ) ->
      letters = dataz
      .map (data) ->
        for handle in state.handles
          try
            return {handle: handle, msg: JSON.parse handle.decrypt data.data, 'utf8'}
        null  
      .filter (data) -> not helpers.isEmpty data
      cb null, letters

getContacts = (_, cb ) ->
  myState.get (err, state) ->
    return cb err if err?
    contacts = state.contacts
    .map (contact) ->
      names = state.names
      .map (x) -> x.name if x.pem is contact.pem
      .filter (x) -> x?
      pem: contact.pem
      date: contact.date
      names: names
    cb null, contacts

getHandles = (_, cb) ->
  myState.get (err, state) ->
    return cb err if err?
    handles = state.handles
    .map (key) ->
      names = state.names
      .map (x) -> x.name if x.pem is key.exportKey "public"
      .filter (x) -> x?
      key: key
      names: names
    cb null, handles

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
  product(getMyLetters, myState.get) null, ( err, [letters,state]) ->
    $list = $('#msgs-ul').empty()
    letters
    .map (l) -> l.msg.time = new Date l.msg.time
    .sort (a, b) ->
      return -1 if a.msg.time > b.msg.time 
      return 1 if a.msg.time < b.msg.time
      0    
    .forEach (letter) ->
      date = letter.msg.time.toLocaleString()
      preview = letter.msg.msg.trimStart().replace(/\s\s+/g, ' ').substring(0,80)
      handleNames = state.names
      .map (x) -> x.name if x.pem is letter.handle.exportKey "public"
      .filter (x) -> x?
      $list.append do ->
        $('<li>').append [
          $('<span>').text handleNames
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
            $('<pre class="msg">').text letter.msg.msg
          ]
          
update_write = ->
  product(myState.get, getContacts) {}, (err, [state,contacts]) ->
    if err?
      console.log "update_write error", err
    else
      $textarea = $('#text-area').empty()
      $contacts = Object.keys(state.contacts).map ( i ) ->
        date = new Date contacts[i].date
        $('<option value="'+i+'">').text contacts[i].names
      $to = $('#write-select').empty().append $contacts
      $('#send-btn').off().click ->
        return false if $textarea.val().trim() is ""
        if $to.val()?
          newMessage $textarea.val(), state.contacts[$to.val()].pem, (err) ->
            return alert "ERROR: #{err}" if err?
            alert "Message sent"
            $textarea.val ""
            update_write()

update_addrbook = ->
  getContacts {}, (err, data) ->
    return console.error err if err?
    $contacts = $( '#addrbook' )
    .empty()
    .append $('<ol>').append data.map ({pem,names,date}) ->
      $('<li class="border">').append [
        $('<pre class="title">').text names
        $('<pre>').text new Date date
        $('<pre>').text pem
    ]
  

update_handles = ->
  getHandles {}, (err, handles) ->
    return console.error err if err?
    $handles = $('#handles')
    .empty()
    .append handles.map ({key,names}) ->
      $('<div class="border">').append [
        $('<pre class="title">').text names
        $('<pre>').text key.exportKey()
        $('<pre>').text key.exportKey "public"
      ]

$ ->
  $('#reload-btn').click ->
    getHandles {}, (err, handles) -> []
    update_inbox()
    update_addrbook()
    
  $( "#tabs" ).tabs {
    heightStyle: "fill"
    beforeActivate: (event, ui) ->
      switch ui.newPanel[0].id
        when 'inbox-div'
          update_inbox()
        when 'write-div'
          update_write()
        when 'addrbook-div'
          update_addrbook()
        when 'handles-div'
          update_handles()
  }

  $('#add-contact-btn').click ->
    $dialog = $("#new-contact-div").empty().append [
      "Name:"
      $contactName = $ '<input>'
      "Address:"
      $contactPem = $ '<textarea>' 
    ]
    .dialog {
      width: 700
      buttons: [
        text: "Save"
        click: ->
          me = $ this
          addContact $contactName.val(), $contactPem.val().trim(), (err) ->
            console.warn err if err?
            me.dialog 'close'
            update_addrbook()
      ]
    }

  $('#new-key-btn').click ->
    getHandles (err, handles) ->
      $d = $('#create-handle-dialog').empty().append [
        "You have #{handles.length} handles(s). "
        "Do you want to make one from an existing private key or generate a new one?"
      ]
      .dialog
        resizable: false
        height: "auto"
        width: 400
        modal: true
        buttons:
          "Add existing": ->
            $g = $("#edit-key-dialog").empty().append [
              "Private key (PEM):"
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
                    newHandle
                    getHandles
                  ]) "token", (err, $keys) ->
                    $g.dialog "close"
                    $d.dialog "close"
                    return console.warn(err) if err? 
                    #myIds = new LazyValue myIds_fetcher
                    update_handles()

          "Generate": ->
            compose([
              myPassword.get
              delay (password) ->
                { password, key: new NodeRSA b: 1024 }
              newHandle
              getHandles
            ]) "token", (err, $keys) ->
              $d.dialog "close"
              return console.warn(err) if err? 
              #myIds = new LazyValue myIds_fetcher
              update_handles() 

  update_inbox()

