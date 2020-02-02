NodeRSA    = require 'node-rsa'
CryptoJS   = require 'crypto-js'
{ LazyValue, product, delay, compose, merge, map } = require 'functors'
{ withContinuation, isEmpty } = require 'functors/helpers'
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

logCB = (msg = "callback finished") -> 
  (err, data) ->
    console.log msg, err, data


pemToName = (pem) ->
  pem
  .split "\n"
  .map (x) -> x.substring 0, 3
  .join ""

keyToPem = (key) ->
  if key.isPrivate()
    key.exportKey "private"
  else
    key.exportKey "public"

syncState = (state, cb) ->
  $.ajax
    method: 'GET'
    url: "/getData"
    data: {last: state.last}
    contentType: 'application/json'
  .fail (args...) -> cb args
  .done ( dataz ) ->
    map( 
      merge [
        withContinuation ({i,hash,msg}) ->
          state.last = Math.max i, state.last
          { type, name, time, pem } = JSON.parse CryptoJS.AES.decrypt(msg, state.secret).toString CryptoJS.enc.Utf8
          rsaKey = new NodeRSA()
          rsaKey.importKey pem
          pubKey = rsaKey.exportKey "public"
          sha1 = CryptoJS.SHA1(pubKey).toString()
          time = new Date time
          name = pemToName pubKey if isEmpty name
          switch type
            when "handle"
              console.warn "Handle '#{pubKey}' exists already! It will be overwritten with new meta-data..." if state.handle[sha1]?
              state.handle[sha1] = { name, time, pem, rsaKey }
            when "contact"
              console.warn "Contact '#{pubKey}' exists already! It will be overwritten with new meta-data..." if state.contact[sha1]?
              state.contact[sha1] = { name, time, pem, rsaKey }
          state
        (data, cb) ->
          decryptFns = (for sha1, handle of state.handle
            do (handle) ->
              withContinuation ({i,hash,msg}) ->
                console.log "Trying to decrypt message #{i} ..."
                decrypted = handle.rsaKey.decrypt msg, 'utf8'
                state.msgs[hash] = { i, hash, msg, decrypted, handle }
                state)
          merge(decryptFns) data, cb 
        withContinuation (data) ->
          console.log "Message #{data.i} dropped..."
          state
      ]) dataz, (err) ->
        console.log err if err? 
        cb err, state

theState = new LazyValue (cb) ->
  state = do (secret = prompt "password") ->
    secret: secret 
    sha1: CryptoJS.SHA1(secret).toString()
    last: -1
    handle: {}
    contact: {}
    msgs: {}
  syncState state, cb

sendData = (data, cb) ->
  $.ajax
    method: 'POST'
    url: "/addData"
    contentType: 'application/json'
    data: JSON.stringify data
  .fail (args...) -> cb args
  .done -> cb null

sendState = (data, cb) ->
  theState.get ( err, state ) ->
    return cb err if err?
    data = CryptoJS.AES.encrypt( (JSON.stringify data), state.secret ).toString()
    sendData { msg: data }, cb

addToState = ({type, name, rsaKey}, cb) ->
  return cb Error "Key is empty" unless rsaKey?
  return cb Error "Unknown type #{type}" unless type is 'contact' or type is 'handle'
  pubKey = rsaKey.exportKey "public"
  sha1 = CryptoJS.SHA1(pubKey).toString()
  pem = keyToPem rsaKey 
  time = new Date()
  name = pemToName pubKey if isEmpty name
  data = { name, time, pem, rsaKey }
  theState.get (err, state) ->
    state[type][sha1] = data
    sendState {type, name, time: time.getTime(), pem}, cb
 
newMessage = ({msg, pem}, cb) ->
  pubKey = new NodeRSA pem
  msg = pubKey.encrypt msg, 'base64'
  sendData { msg }, cb

update_inbox = ->
  theState.get ( err, state) ->
    return console.error err if err?
    letters = Object.values state.msgs 
    $list = $('#msgs-ul').empty()
    letters
    .sort (a, b) -> 
      a.i - b.i
    .forEach (letter) ->
      {i, msg, handle, decrypted } = letter
      preview = decrypted.trimStart().replace(/\s\s+/g, ' ').substring(0,99)
      $list.append do ->
        $('<li>').append [
          $('<a href="#">').addClass("label").text "#{i} [#{handle.name}]"
          $('<span>').text " : #{preview}"
        ]
        .click ->
          $me = $(this)
          $me.siblings().removeClass "selected"
          $me.addClass "selected" 
          $bot = $('#msg-div').empty()
          .append [
            $('<p class="label">').text "Position: #{i}"
            $('<pre class="msg">').text decrypted
          ]
          
update_write = ->
  theState.get (err, state) ->
    return console.error err if err?
    contacts = Object.values state.contact
    $textarea = $('#text-area').empty()
    $contacts = ( $("<option value=\"#{i}\">").text(name) for {name}, i in contacts when name? )
    $to = $('#write-select').empty().append $contacts
    $('#send-btn').off().click ->
      return false if $textarea.val().trim() is ""
      if $to.val()?
        newMessage {msg: $textarea.val(), pem: contacts[$to.val()].pem }, (err) ->
          return alert "ERROR: #{err}" if err?
          alert "Message sent"
          $textarea.val ""
          update_write()

update_addrbook = ->
  theState.get (err, state) ->
    return console.error err if err?
    contacts = Object.values state.contact
    $contacts = $( '#addrbook' )
    .empty()
    .append $('<ol>').append contacts.map ({pem,name,time}) ->
      $('<li class="border">').append [
        $('<pre class="title">').text name
        $('<pre>').text time
        $('<pre>').text pem
    ]

update_handles = ->
  theState.get (err, state) ->
    return console.error err if err?
    handles = Object.values state.handle
    $handles = $('#handles')
    .empty()
    .append handles.map ({pem, rsaKey, name,time}) ->
      $('<div class="border">').append [
        $('<pre class="title">').text name
        $('<pre>').text time
        $('<pre>').text pem
        $('<pre>').text rsaKey.exportKey "public"
      ]
      
$ ->
  $('#reload-btn').click ->
    compose(theState.get, syncState) "token", (err) ->
      console.error err if err?
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
          rsaKey = new NodeRSA()
          rsaKey.importKey $contactPem.val().trim()
          addToState {type: "contact", name: $contactName.val(), rsaKey }, logCB "Adding a contact"  
          me.dialog 'close'
          update_addrbook()
          update_write()
      ]
    }

  $('#new-handle-btn').click ->
    theState.get (err, state) ->
      return console.error err if err?
      # this whole part should be rewritten:
      mode = "new"
      $d = $('#create-handle-dialog').empty().append [
        $('<p>').text("You have #{Object.values(state.handle).length} handles. ")
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
            addToState {type: "handle", name: $handleName.val(), rsaKey: key}, logCB "Creation of new handle"
            $d.dialog "close" 
            update_handles() 
      setTimeout (-> $pemDiv.hide())
  update_inbox()

