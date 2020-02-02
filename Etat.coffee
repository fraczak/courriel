{ Database } = require("sqlite3").verbose()
LazyValue = require "functors/LazyValue"
compose = require "functors/compose"
map = require "functors/map"
semaphore = require "functors/semaphore"
{ isEmpty, isString } = require "functors/helpers"
crypto = require 'crypto'

getHash = (text) ->
  do (hash = crypto.createHash 'sha256') ->
    crypto.createHash 'sha256'
    .update text
    .digest 'hex'


class Etat
  constructor: (db) ->
    @sem = semaphore 1
    @db = new LazyValue (cb) ->
      _db = new Database db, (err) ->
        return cb err if err
        compose([
          _db.all.bind _db, """CREATE TABLE IF NOT EXISTS msgs (
            i INTEGER PRIMARY KEY AUTOINCREMENT, hash TEXT, msg TEXT)"""
          _db.all.bind _db, "CREATE UNIQUE INDEX IF NOT EXISTS msgs_idx ON msgs (hash)"
          _db.all.bind _db, "CREATE TABLE IF NOT EXISTS peers (url TEXT NOT NULL, last INTEGER)"
          _db.all.bind _db, "CREATE UNIQUE INDEX IF NOT EXISTS peers_idx ON peers (url)"
        ]) [], (err) ->
          cb err, _db
    @db.get console.log.bind console

  addData: (data, cb) ->
    sem = @sem
    data = [].concat data
    data = data.map ( {hash, msg} = {} ) -> 
      if isEmpty msg
        return null
      $msg: msg
      $hash: getHash msg
    .filter (x) -> x?
    @db.get (err, db) ->
      return cb err if err
      map( sem db.all.bind db, """
        INSERT OR IGNORE INTO msgs (hash,msg) VALUES ($hash,$msg)"""
      ) data, cb

  getData: ({ start = 0, size } = {}, cb) ->
    @db.get (err, db) ->
      return cb err if err
      if isEmpty size
        db.all "SELECT * FROM msgs WHERE i >= $i", {$i:start}, (err, data) ->
          console.log " ->", data
          cb err, data
      else
        db.all "SELECT * FROM msgs WHERE i >= $i LIMIT $n", {$i: start, $n: size }, (err, data) ->
          console.log " ->", data
          cb err, data
  
  addPeers: (peers = [], cb) ->
    sem = @sem
    peers = peers.map ({url, last = 0} = {}) ->
      return if isEmpty url
      { $url: url, $last: last }
    .filter (x) -> x?
    @db.get (err, db) ->
      return cb err if err
      map( sem db.all.bind db, """
        INSERT OR IGNORE INTO peers (url,last) VALUES ($url,$last)"""
      ) peers, cb
  
  getPeers: (..., cb) ->
    @db.get (err, db) ->
      return cb err if err
      db.all "SELECT * FROM peers", [], cb

module.exports = Etat
