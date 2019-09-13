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
          _db.all.bind _db, "CREATE TABLE IF NOT EXISTS letters (msg TEXT PRIMARY KEY, time TIME, dest TEXT)"
          _db.all.bind _db, "CREATE INDEX IF NOT EXISTS dest_idx on letters (dest)"
          _db.all.bind _db, "CREATE INDEX IF NOT EXISTS time_idx on letters (time)"
          _db.all.bind _db, "CREATE TABLE IF NOT EXISTS peers (url TEXT PRIMARY KEY, added TIME)"
          _db.all.bind _db, "CREATE TABLE IF NOT EXISTS pems (name TEXT, pem TEXT, UNIQUE (name,pem))"
          #_db.all.bind _db, "CREATE UNIQUE INDEX IF NOT EXISTS pems_idx ON pems(name,pem)"
          _db.all.bind _db, "CREATE TABLE IF NOT EXISTS keys (name TEXT PRIMARY KEY, key TEXT)"
          _db.all.bind _db, "CREATE TABLE IF NOT EXISTS data (data TEXT, tag TEXT)"
          _db.all.bind _db, "CREATE INDEX IF NOT EXISTS tag_idx on data (tag)"
        ]) [], (err) ->
          cb err, _db
    @db.get console.log.bind console

  toArray = (x) ->
    [].concat(x).filter (x) -> x?

  addKeys: (keys, cb) ->
    keys = toArray keys
    keys = ({$name:name,$key:key} for {name,key} in keys when not (isEmpty(name) or isEmpty key))
    sem = @sem
    @db.get (err, db) ->
      return cb err if err
      map( sem db.all.bind db, """
        INSERT OR IGNORE INTO keys(name,key) VALUES($name,$key)"""
      ) keys, cb
  getKeys: (names, cb) ->
    names = toArray names
    $names = (name for {name} in names when name?)
    $$ = ("?" for name in $names).join ","
    if isEmpty $names
      @db.get (err, db) ->
        return cb err if err
        db.all "SELECT * FROM keys", [], cb
    else
      @db.get (err, db) ->
        return cb err if err
        db.all "SELECT * FROM keys WHERE name IN (#{$$})", $names, cb

  addPems: (pems, cb) ->
    pems = toArray pems
    pems = ({$name:name,$pem:pem} for {name,pem} in pems when not (isEmpty(name) or isEmpty pem))
    sem = @sem
    @db.get (err, db) ->
      return cb err if err
      map( sem db.all.bind db, """
        INSERT OR IGNORE INTO pems(name,pem) VALUES($name,$pem)"""
      ) pems, cb
  getPems: (names, cb) ->
    $names = (name for {name} in toArray(names) when not isEmpty name)
    $$ = ("?" for name in $names).join ","
    if isEmpty $names
      @db.get (err, db) ->
        return cb err if err
        db.all "SELECT * FROM pems", [], cb
    else
      @db.get (err, db) ->
        return cb err if err
        db.all "SELECT * FROM pems WHERE name IN (#{$$})", $names, cb

  addLetters: (letters, cb) ->
    letters = toArray letters
    letters = ({
      $msg: msg
      $dest: dest
      $time: time ? new Date()
    } for {msg,dest,time} in letters when not (isEmpty(msg) or isEmpty dest)) 
    sem = @sem
    @db.get (err, db) ->
      return cb err if err
      map( sem db.all.bind db, """
        INSERT OR IGNORE INTO letters(msg,time,dest) VALUES($msg,$time,$dest)"""
      ) letters, cb

  getLetters: (filters, cb) ->
    filters = toArray filters
    return cb Error "Max one filter supported now..." if filters.length > 1
    filter = filters[0]
    $time = filter?.time
    $dest = filter?.pem
    @db.get (err, db) ->
      return cb err if err
      switch  
        when $time? and $dest? 
          db.all "SELECT * FROM letters WHERE dest = $dest AND time > $time", {$time,$dest}, cb
        when $time? 
          db.all "SELECT * FROM letters WHERE time > $time", {$time}, cb
        when $dest? 
          db.all "SELECT * FROM letters WHERE dest = $dest", {$dest}, cb
        else
          db.all "SELECT * FROM letters", [], cb

  addData: (data, tag, cb) ->
    sem = @sem
    @db.get (err, db) ->
      return cb err if err
      db.all "INSERT OR IGNORE INTO data(data,tag) VALUES ($data,$tag)", {$data:data, $tag:tag}, cb

  getData: (tag, cb) ->
    @db.get (err, db) ->
      return cb err if err
      if tag
        db.all "SELECT * FROM data WHERE tag = $tag", {$tag:tag}, cb
      else
        db.all "SELECT * FROM data", cb
  
  addPeers: (peers, cb) ->
    sem = @sem
    peers = toArray peers
    .map (peer) ->
      $url   : peer.url ? peer
      $added : peer.added ? new Date()
    @db.get (err, db) ->
      return cb err if err
      map( sem db.all.bind db, """
        INSERT OR IGNORE INTO peers(url,added) VALUES($url,$added)"""
      ) peers, cb
  
  getPeers: (..., cb) ->
    @db.get (err, db) ->
      return cb err if err
      db.all "SELECT * FROM peers", [], cb

module.exports = Etat
