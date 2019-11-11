{ Database } = require("sqlite3").verbose()
LazyValue = require "functors/LazyValue"
compose = require "functors/compose"
map = require "functors/map"
semaphore = require "functors/semaphore"
{ isEmpty } = require "functors/helpers"

class Etat
  constructor: (db) ->
    @sem = semaphore 1
    @db = new LazyValue (cb) ->
      _db = new Database db, (err) ->
        return cb err if err
        compose([
          _db.all.bind _db, "CREATE TABLE IF NOT EXISTS peers (host TEXT, port TEXT, added TIME)"
          _db.all.bind _db, "CREATE TABLE IF NOT EXISTS data (data TEXT PRIMARY KEY, tag TEXT)"
          _db.all.bind _db, "CREATE INDEX IF NOT EXISTS tag_idx on data (tag)"
          _db.all.bind _db, "CREATE UNIQUE INDEX IF NOT EXISTS peers_idx ON peers ( host, port )"
        ]) [], (err) ->
          cb err, _db
    @db.get console.log.bind console

  addData: ({ data, tag }, cb) ->
    sem = @sem
    return cb new Error "Empty data?" if isEmpty data
    @db.get (err, db) ->
      return cb err if err
      db.all "INSERT OR REPLACE INTO data(data,tag) VALUES ($data,$tag)", {$data:data, $tag:tag}, cb

  getData: ({ tag } = {}, cb) ->
    console.log "GET DATA: ", tag
    @db.get (err, db) ->
      return cb err if err
      if tag?
        db.all "SELECT * FROM data WHERE tag LIKE $tag", {$tag:tag}, (err, data) ->
          console.log " ->", data
          cb err, data
      else
        db.all "SELECT * FROM data", (err, data) ->
          console.log " ->", data
          cb err, data
  
  addPeers: (peers, cb) ->
    sem = @sem
    peers = peers.filter (x) -> not isEmpty x
    .map (peer) ->
      $host  : peer.host
      $port  : peer.port
      $added : new Date()
    @db.get (err, db) ->
      return cb err if err
      map( sem db.all.bind db, """
        INSERT OR IGNORE INTO peers(host,port,added) VALUES($host,$port,$added)"""
      ) peers, cb
  
  getPeers: (..., cb) ->
    @db.get (err, db) ->
      return cb err if err
      db.all "SELECT * FROM peers", [], cb

module.exports = Etat
