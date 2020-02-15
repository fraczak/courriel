{ Database } = require("sqlite3").verbose()
LazyValue = require "functors/LazyValue"
compose = require "functors/compose"
map = require "functors/map"
semaphore = require "functors/semaphore"
{ isEmpty, isString, isNumber } = require "functors/helpers"
crypto = require 'crypto'

getHash = (text) ->
  do (hash = crypto.createHash 'sha1') ->
    crypto.createHash 'sha1'
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
            i INTEGER PRIMARY KEY, hash TEXT, msg BLOB)"""
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

  getData: ({ i, size, order } = {}, cb) ->
    order = "ASC" unless order is "DESC"
    op = if order is "ASC" then ">=" else "<="
    @db.get (err, db) ->
      return cb err if err
      if isNumber i
        if isEmpty size
          db.all "SELECT * FROM msgs WHERE i #{op} $i ORDER BY i #{order}", {$i: i}, cb
        else
          db.all "SELECT * FROM msgs WHERE i #{op} $i ORDER BY i #{order} LIMIT $n", {$i: i, $n: size }, cb
      else
        if isEmpty size
          db.all "SELECT * FROM msgs ORDER BY i #{order}", [], cb
        else
          db.all "SELECT * FROM msgs ORDER BY i #{order} LIMIT $n", {$n: size }, cb

  addPeers: (peers = [], cb) ->
    sem = @sem
    peers = peers.map (peer) ->
      last = -1
      url = if isString peer then peer else peer.url
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

  updatePeer: ({url, last = -1}, cb) ->
    @db.get (err, db) ->
      return cb err if err?
      db.all "UPDATE peers SET last = $last WHERE url = $url", {$last:last, $url: url}, cb
      
module.exports = Etat
