express     = require 'express'
body_parser  = require 'body-parser'
{ isEmpty } = require 'functors/helpers'
compose = require 'functors/compose'

json_parser = body_parser.json limit: '50mb'

options = require('dreamopt') [
  "Usage:  courriel-server [options]"
  "  -c, --config FILE    config file (default: ./conf.json)"
  "  -l, --listen PORT    Port to listen on"
  "  -p, --peer PEER      host:port of a peer"
  "  -d, --db DB          database"
  "      --proxy PROXY    host:port of proxy"
]

options = Object.assign {}, require(options.config), options if options.config?
console.log JSON.stringify options, null, 2

Etat = require './Etat'
etat = new Etat options.db
if options.peer
  options.peers.push options.peer
etat.addPeers options.peers, (err) ->
  return console.warn "Error storing peers: #{err}" if err
  etat.getPeers "all", (err, peers) ->
    return console.warn "Error getting peers: #{err}" if err
    console.log "My peers: #{JSON.stringify peers}"
Peers = require './Peers'
peers = new Peers etat, options.proxy

app = express()

app.locals.pretty = true

app.get "/", (req, res) ->
  res.render "courriel.pug"

app.post "/syncData", json_parser, (req, res) ->
  etat.addData req.body, (err) ->
    console.log err
    return res.status(500).end "#{err}" if err
    etat.getData "all", (err, data = []) ->
      return res.status(500).end "#{err}" if err
      res.json data

app.post "/addData", json_parser, (req, res) ->
  console.log "POST /addData #{JSON.stringify req.body}"
  etat.addData req.body, (err) ->
    console.log err
    return res.status(500).end "#{err}" if err
    res.json("Ok")

app.get "/getData", (req, res) ->
  console.log "GET /getData #{JSON.stringify req.query}"
  etat.getData req.query, (err, data = []) ->
    return res.status(500).end "#{err}" if err
    res.json data

app.post "/peers", json_parser, (req, res) ->
  console.log "POST /peers #{JSON.stringify req.body}"
  etat.addPeers req.body, (err, data) ->
    return res.status(500).end "#{err}" if err
    etat.getPeers "all", (err, data) ->
      return res.status(500).end "#{err}" if err
      res.json data

app.get "/peers", (req, res) ->
  etat.getPeers "all", (err, data) ->
    return res.status(500).end "#{err}" if err
    res.json data

app.use express.static 'public'

app.listen options.listen
