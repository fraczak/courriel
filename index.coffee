express     = require 'express'
body_parse  = require 'body-parser'
options = require('dreamopt') [
  "Usage:  courriel-server [options]"
  "  -c, --config FILE    config file (default: ./conf.json)"
  "  -l, --listen PORT    Port to listen on (default: 8887)"
  "  -p, --peer URL       URL to a peer"
  "  -d, --db DB        database (default: ./etat.db)"
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
  console.log req.body
  etat.addKey {
    $key: req.body.key
    $name: req.body.name
  }, (err) ->
    return res.status(500).end(err) if err
    res.end()

app.post "/addAddress", body_parse.json(), (req, res) ->
  etat.addPems {$name: req.body.name, $pem: req.body.pem}, (err) ->
    return res.status(500).end(err) if err
    res.end()
  
app.post "/postMessage", body_parse.json(), (req, res) ->
  etat.addLetters {$msg: req.body.msg, $dest: req.body.to, $time: new Date}, (err) ->
    return res.status(500).end(err) if err
    res.end()

app.get "/etat", (req, res) ->
  res.json {}

app.get "/encryptedKey", (req, res) ->
  console.log req.query
  etat.getKey req.query.name, (err, data) ->
    console.log err, data
    return res.status(500).end(err) if err
    return res.status(407).end("Not found") unless data
    res.json data

app.get "/yp", (req, res) ->
  etat.getAllPems (err, data) ->
    return res.status(500).end(err) if err
    res.json data

app.get "/letters", (req, res) ->
  console.log "LETTERS: ", JSON.stringify req.query
  etat.getLetters req.query, (err, data) ->
    return res.status(500).end(err) if err
    res.json data

app.use express.static 'public'

app.listen options.port
