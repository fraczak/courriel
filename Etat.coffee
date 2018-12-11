{ Database } = require("sqlite3").verbose()
LazyValue = require "functors/LazyValue"
compose = require "functors/compose"
map = require "functors/map"
semaphore = require "functors/semaphore"
{ flatten } = require "functors/helpers"
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
          _db.all.bind _db, "CREATE TABLE IF NOT EXISTS pems (name TEXT PRIMARY KEY, pem TEXT)"
          _db.all.bind _db, "CREATE TABLE IF NOT EXISTS keys (name TEXT PRIMARY KEY, key TEXT)"
        ]) [], (err) ->
          cb err, _db
    @db.get console.log.bind console

  addKey: ({$name, $key}, cb) ->
    @db.get (err, db) ->
      return cb err if err
      db.all "INSERT OR IGNORE INTO keys(name,key) VALUES($name,$key)", {$name,$key}, cb
        
  getKey: ($name, cb) ->
    @db.get (err, db) ->
      return cb err if err
      db.get "SELECT * FROM keys WHERE name = $name", {$name}, cb

  addPems: (pems..., cb) ->
    sem = @sem
    @db.get (err, db) ->
      return cb err if err
      pems = flatten pems
      map( sem db.all.bind db, """
        INSERT INTO pems(name,pem) VALUES($name,$pem) 
        ON CONFLICT(name) DO UPDATE SET pem=excluded.pem"""
      ) pems, cb
  getPem: ($name, cb) ->
    @db.get (err, db) ->
      return cb err if err
      db.get "SELECT * FROM pems WHERE name = $name", {$name}, cb
  getAllPems: (cb) ->
    @db.get (err, db) ->
      return cb err if err
      db.all "SELECT * FROM pems", [], cb

  addLetters: (letters..., cb) ->
    sem = @sem
    @db.get (err, db) ->
      return cb err if err
      letters = flatten letters
      map( sem db.all.bind db, """
        INSERT OR IGNORE INTO letters(msg,time,dest) VALUES($msg,$time,$dest)"""
      ) letters, cb

  getLetters: (filter, cb) ->
    @db.get (err, db) ->
      return cb err if err
      switch  
        when filter?.$time? and filter.$dest? 
          db.all "SELECT * FROM letters WHERE dest = $dest AND time > $time", filter, cb
        when filter?.$time? 
          db.all "SELECT * FROM letters WHERE time > $time", filter, cb
        when filter?.$dest? 
          db.all "SELECT * FROM letters WHERE dest = $dest", filter, cb
        else
          db.all "SELECT * FROM letters", [], cb
  
module.exports = Etat
