NodeRSA    = require 'node-rsa'
CryptoJS   = require 'crypto-js'
{LazyValue, helpers, product, delay, compose}    = require 'functors'

$ = window.jQuery = require 'jquery'
require "jquery-ui-bundle"

myPassword = new LazyValue delay ->
  prompt "password"

myTag = new LazyValue compose myPassword.get, delay (password) ->
  CryptoJS.SHA1(password).toString()

newHandle = ({name, key}, cb) ->
  return cb Error "Key is empty" unless key?
  myState.get (err, state) ->
    return cb (err) if err?
    if name
      pem = key.exportKey "public"
      state.names.push {pem, name}
      sendState {type:"name", pem, name}, -> #TODO handle error
    time = new Date()
    data = {type: "handle", key: key.exportKey(), time: time.getTime()}
    state.handles.push {key, time:time}
    sendState data, cb

myState = new LazyValue (cb) ->
  product(myPassword.get, myTag.get) "token", (err, [password, tag]) ->
    return cb (err) if err?
    $.ajax
      url: "/getData"
      data: {tag}
      #data: data: tag
      #i dont get it
    .done ( dataz ) ->
      state =
        handles:[]
        names:[]
        contacts:[]
      console.log "STATEETTETETEEEEE", dataz.length
      dataz.map (data) ->
        try
          data = JSON.parse CryptoJS.AES.decrypt(data.data, password).toString CryptoJS.enc.Utf8
          #data = JSON.parse CryptoJS.AES.decrypt(data.tag, password).toString CryptoJS.enc.Utf8
          console.log "state", data
          state.handles.push time: (new Date data.time), key: new NodeRSA data.key if data.type is "handle"
          state.names.push data if data.type is "name"
          state.contacts.push pem:data.pem,time: new Date data.time if data.type is "contact"
          delete data.type
          return
        console.log "state failed", data
      #console.log "STATE", state
      cb null, state

addContact = ( {name, pem}, cb ) ->
  myState.get ( err, state ) ->
    return cb err if err?
    time = new Date()
    data = { type: 'contact', pem, time:time.getTime()}
    if name
      state.names.push {pem,name}
      sendState {type:"name", pem,name}, -> #TODO handle error
    state.contacts.push({pem,time}) # TODO uniq
    sendState data, cb

sendState = (data, cb) ->
  product(myPassword.get, myTag.get) "token", ( err, [password, tag] ) ->
    data = CryptoJS.AES.encrypt( (JSON.stringify data), password ).toString()
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
      #console.log "whythefuckwho", state.handles.map (h) -> h.key.exportKey()
      letters = dataz
      .map (data) ->
        for handle in state.handles
          try
            #console.log "fuk0", data
            #console.log "fuk1", handle.key.decrypt data.data, 'utf8'
            #console.log "fuk2", JSON.parse handle.key.decrypt data.data, 'utf8'
            return {handle: handle, msg: JSON.parse handle.key.decrypt data.data, 'utf8'}
        null  
      .filter (data) -> not helpers.isEmpty data
      console.log "letterz", letters.length
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
      time: contact.time
      names: names
    cb null, contacts

getHandles = (cb) ->
  myState.get (err, state) ->
    return cb err if err?
    handles = state.handles
    .map ({key,time}) ->
      names = state.names
      .map (x) -> x.name if x.pem is key.exportKey "public"
      .filter (x) -> x?
      key: key
      names: names
      time: time
    cb null, handles

newMessage = (text, address, cb) ->
  console.log "senddem", text, address
  pubKey = new NodeRSA address
  msg = JSON.stringify msg: text, time: (new Date()).getTime()
  msg = pubKey.encrypt msg, 'base64'
  console.log "ciphetext", msg
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
    .map (l) -> l.msg.time = new Date l.msg.time; l
    .sort (a, b) ->
      return -1 if a.msg.time > b.msg.time 
      return 1 if a.msg.time < b.msg.time
      0    
    .forEach (letter) ->
      time = letter.msg.time.toLocaleString()
      preview = letter.msg.msg.trimStart().replace(/\s\s+/g, ' ').substring(0,80)
      handleNames = state.names
      .map (x) -> x.name if x.pem is letter.handle.key.exportKey "public"
      .filter (x) -> x?
      $list.append do ->
        $('<li>').append [
          $('<a href="#">').addClass("label").text time
          $('<span>').text '[' + handleNames.toString() + ']'
          $('<span>').text " : #{preview}"
        ]
        .click ->
          $me = $(this)
          $me.siblings().removeClass "selected"
          $me.addClass "selected" 
          $bot = $('#msg-div').empty()
          .append [
            $('<p class="label">').text "Sent: #{time}"
            $('<pre class="msg">').text letter.msg.msg
          ]
          
update_write = ->
  product(myState.get, getContacts) {}, (err, [state,contacts]) ->
    if err?
      console.log "update_write error", err
    else
      $textarea = $('#text-area').empty()
      $contacts = Object.keys(state.contacts).map ( i ) ->
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
    .append $('<ol>').append data.map ({pem,names,time}) ->
      $('<li class="border">').append [
        $('<pre class="title">').text names
        $('<pre>').text time
        $('<pre>').text pem
    ]
  

update_handles = ->
  getHandles (err, handles) ->
    return console.error err if err?
    $handles = $('#handles')
    .empty()
    .append handles.map ({key,names,time}) ->
      $('<div class="border">').append [
        $('<pre class="title">').text names
        $('<pre>').text time
        $('<pre>').text key.exportKey()
        $('<pre>').text key.exportKey "public"
      ]

$ ->
  $('#reload-btn').click ->
    getHandles (err, handles) -> []
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

          addContact {name: $contactName.val(), pem: $contactPem.val().trim()}, (err) ->
            console.warn err if err?
            me.dialog 'close'
            update_addrbook()
            update_write()
      ]
    }

  $('#new-handle-btn').click ->
    getHandles (err, handles) ->
      # this whole part should be rewritten:
      mode = "new"
      $d = $('#create-handle-dialog').empty().append [
        $('<p>').text("You have #{handles.length} handles(s). ")
        $('<p>').text("Name:")
        $handleName = $ '<input>'
        $('<div>').append [
          $('<input id="create-handle-new-rad" type="radio" checked="checked">').click ->
            $("#create-handle-from-pkey-rad")[0].checked=0
            $pemDiv.hide()
            mode = "new"
          $('<label for="create-handle-new-rad">').text("New")
          $('<input id="create-handle-from-pkey-rad" type="radio">').click ->
            $("#create-handle-new-rad")[0].checked=0
            $pemDiv.show()
            mode = "frompk"
          $('<label for="create-handle-from-pkey">').text("From private key")
        ]
        $pemDiv= $('<div id=create-handle-pkey>').append [
          $('<p>').text("Private key:")
          $pemKey= $ '<textarea>' 
        ]
        #$btn = $('<input type="button">').text("Create").click ->
      ]
      .dialog
        resizable: false
        height: "auto"
        width: 600
        modal: true
        buttons:
          "Create": ->
            if mode == "new"
              key = new NodeRSA b: 1024
            else
              try
                key = new NodeRSA $pemKey.val().trim()
              catch err
                console.error err
                $d.dialog "close"
                return
            newHandle {name: $handleName.val(), key: key}, (err) ->
              $d.dialog "close"
              return console.warn "generate handle fail", err if err? 
              update_handles() 
      setTimeout (-> $pemDiv.hide())
  update_inbox()

