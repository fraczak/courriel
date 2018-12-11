express     = require 'express'
body_parse  = require 'body-parser'
options = require('dreamopt') [
  "Usage:  courriel-server [options]"
  "  -c, --config FILE    config file (default: ./conf.json)"
  "  -l, --listen PORT    Port to listen on (default: 8887)"
  "  -p, --peer URL       URL to a peer"
  "  -d, --db DB        database (default: ./etat.json)"
]

options = Object.assign {}, require(options.config), options if options.config?
console.log JSON.stringify options, null, ""

Etat        = require './Etat'
etat = new Etat options.db

require("./peers.coffee") etat, [].concat options.peers, options.peer

app = express()

app.locals.pretty = true

app.get "/", (req, res) ->
  res.render "courriel.pug"

app.post "/storeEncryptedKey", body_parse.json(), (req, res) ->
  etat.setEncryptedKey req.body.encryptedKey
  res.end()

app.post "/addAddress", body_parse.json(), (req, res) ->
  etat.addAddress req.body.pem, req.body
  res.end()

app.post "/postMessage", body_parse.json(), (req, res) ->
  etat.addLetter req.body
  res.end()

app.get "/etat", (req, res) ->
  res.json etat.get()

app.get "/encryptedKey", (req, res) ->
  res.json etat.getEncryptedKey()

app.get "/yp", (req, res) ->
  res.json etat.getYp()

app.get "/letters", (req, res) ->
  pem = req.query.pem
  filter = if req.query.pem
    (x) -> x.to is req.query.pem
  else
    -> true
  res.json etat.getLetters filter

app.use express.static 'public'

app.listen options.port
