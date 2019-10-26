express     = require 'express'
body_parse  = require 'body-parser'
{ isEmpty } = require 'functors/helpers'

options = require('dreamopt') [
  "Usage:  courriel-server [options]"
  "  -c, --config FILE    config file (default: ./conf.json)"
  "  -l, --listen PORT    Port to listen on (default: 8887)"
  "  -p, --peer URL       URL to a peer"
  "  -d, --db DB        database (default: ./etat.db)"
]

options = Object.assign {}, require(options.config), options if options.config?
console.log JSON.stringify options, null, 2

Etat = require './Etat'
etat = new Etat options.db

etat.addPeers [].concat(options.peers, options.peer ? []), (err) ->
  return console.warn "Error storing peers: #{err}" if err
  etat.getPeers "all", (err, peers) ->
    return console.warn "Error getting peers: #{err}" if err
    console.log "My peers: #{JSON.stringify peers}"
Peers = require './Peers'
peers = new Peers etat

app = express()

app.locals.pretty = true

app.get "/", (req, res) ->
  res.render "courriel.pug"

app.post "/addData", body_parse.json(), (req, res) ->
  etat.addData req.body, (err) ->
    console.log err
    return res.status(500).end(err) if err
    res.json("Ok")

app.get "/getData", (req, res) ->
  console.log req.query
  etat.getData req.query, (err, data = []) ->
    return res.status(500).end(err) if err
    # return res.status(404).end("Not found") if isEmpty data
    res.json data

app.post "/peers", body_parse.json(), (req, res) ->
  etat.addPeers req.body, (err, data) ->
    return res.status(500).end(err) if err
    etat.getPeers "all", (err, data) ->
      return res.status(500).end(err) if err
      return res.status(404).end("Not found") if isEmpty data
      res.json data

app.get "/peers", (req, res) ->
  etat.getPeers "all", (err, data) ->
    return res.status(500).end(err) if err
    return res.status(404).end("Not found") if isEmpty data
    res.json data

app.use express.static 'public'

app.listen options.listen
