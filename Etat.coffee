
json_file_object = require 'json-file-object'

class Etat
  constructor: (db) ->
    @state = json_file_object
      file: db
      value: 
        encryptedKey: null
        yp: {}
        letters: []
  get: ->
    @state
  merge: (state) ->
    @state.yp = Object.assign @state.yp, state.yp
    @state.letters  =  Object.assign @state.letters, state.letters
  setEncryptedKey: (eKey) ->
    @state.encryptedKey = eKey
  getEncryptedKey: ->
    @state.encryptedKey 
  addAddress: (pem, data) ->
    @state.yp[pem] = data
  addLetter: (msg) ->
    @state.letters[msg.msg] = msg
  getYp: ->
    @state.yp
  getLetters: (filter) ->
    Object.values(@state.letters).filter filter
  

module.exports = Etat
