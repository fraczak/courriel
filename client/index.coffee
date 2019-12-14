NodeRSA    = require 'node-rsa'
CryptoJS   = require 'crypto-js'
{LazyValue, helpers, product, delay, compose}    = require 'functors'

$ = global.jQuery = require 'jquery'

require 'jquery-ui/ui/data'
require 'jquery-ui/ui/widget'
require 'jquery-ui/ui/unique-id'
require 'jquery-ui/ui/widgets/mouse'
require 'jquery-ui/ui/safe-active-element'
require 'jquery-ui/ui/tabbable'
require 'jquery-ui/ui/focusable'
require 'jquery-ui/ui/widgets/dialog'
require 'jquery-ui/ui/widgets/button'
require 'jquery-ui/ui/widgets/tabs'

require 'jquery-ui/ui/keycode'

myPassword = new LazyValue delay ->
  prompt "password"

myTag = new LazyValue compose myPassword.get, delay (password) ->
  CryptoJS.SHA1(password).toString()

newHandle = ({name, key}, cb) ->
  return cb Error "Key is empty" unless key?
  myState.get (err, state) ->
    return cb (err) if err?
    time = new Date()
    if name
      pem = key.exportKey "public"
      state.contacts.push {name, pem, time}
      sendState {type: "contact", pem, name, time: time.getTime()}, (err) ->
        console.error err if err? 
    data = {type: "handle", name: name, key: key.exportKey(), time: time.getTime()}
    state.handles.push {name, key, time:time}
    sendState data, cb


myStateFetcher = (cb) ->
  product(myPassword.get, myTag.get) "token", (err, [password, tag]) ->
    return cb (err) if err?
    $.ajax
      url: "/getData"
      data: {tag}
    .done ( dataz ) ->
      state =
        handles:[]
        contacts:[]
      for data in dataz
        try
          data = JSON.parse CryptoJS.AES.decrypt(data.data, password).toString CryptoJS.enc.Utf8
          name = data.name or "?"
          switch data.type
            when "handle"
              state.handles.push name: name, time: (new Date data.time), key: new NodeRSA data.key
            when "contact"
              state.contacts.push name: name, pem: data.pem, time: new Date data.time
        catch err
          console.error err, "\nState failed", data
      cb null, state
    
myState = new LazyValue myStateFetcher

addContact = ( {name, pem}, cb ) ->
  myState.get ( err, state ) ->
    return cb err if err?
    time = new Date()
    data = { name: name, type: 'contact', pem, time: time.getTime() }
    state.contacts.push { name, pem, time } # TODO uniq
    sendState data, cb

sendState = (data, cb) ->
  product(myPassword.get, myTag.get) "token", ( err, [password, tag] ) ->
    data = CryptoJS.AES.encrypt( (JSON.stringify data), password ).toString()
    $.ajax
      method: 'POST'
      url: "/addData"
      contentType: 'application/json'
      data: JSON.stringify {data, tag}
    .fail (args...) -> cb args
    .done -> cb null

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
            return { handle: handle, msg: JSON.parse handle.key.decrypt data.data, 'utf8' }
          null
      .filter (data) -> not helpers.isEmpty data
      console.log "got letterz", letters.length
      cb null, letters

newMessage = ({text, address}, cb) ->
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
      preview = letter.msg.msg.trimStart().replace(/\s\s+/g, ' ').substring(0,99)
      $list.append do ->
        $('<li>').append [
          $('<a href="#">').addClass("label").text time
          $('<span>').text "[#{letter.handle.name}]"
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
  myState.get (err, state) ->
    return console.error err if err?
    $textarea = $('#text-area').empty()
    $contacts = ( $("<option value=\"#{i}\">").text(name) for {name}, i in state.contacts when name? )
    $to = $('#write-select').empty().append $contacts
    $('#send-btn').off().click ->
      return false if $textarea.val().trim() is ""
      if $to.val()?
        newMessage {text: $textarea.val(), address: state.contacts[$to.val()].pem }, (err) ->
          return alert "ERROR: #{err}" if err?
          alert "Message sent"
          $textarea.val ""
          update_write()

update_addrbook = ->
  myState.get (err, state) ->
    return console.error err if err?
    $contacts = $( '#addrbook' )
    .empty()
    .append $('<ol>').append state.contacts.map ({pem,name,time}) ->
      $('<li class="border">').append [
        $('<pre class="title">').text name
        $('<pre>').text time
        $('<pre>').text pem
    ]

update_handles = ->
  myState.get (err, state) ->
    return console.error err if err?
    $handles = $('#handles')
    .empty()
    .append state.handles.map ({key,name,time}) ->
      $('<div class="border">').append [
        $('<pre class="title">').text name
        $('<pre>').text time
        $('<pre>').text key.exportKey()
        $('<pre>').text key.exportKey "public"
      ]
      
$ ->
  $('#reload-btn').click ->
    myState = new LazyValue myStateFetcher
    update_inbox()
    update_addrbook()
    update_handles()
    
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
    myState.get (err, state) ->
      return console.error err if err?
      # this whole part should be rewritten:
      mode = "new"
      $d = $('#create-handle-dialog').empty().append [
        $('<p>').text("You have #{state.handles.length} handles(s). ")
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
        width: 700
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

