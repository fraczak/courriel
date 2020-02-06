{ Database } = require("sqlite3").verbose()
{ LazyValue, compose, product, map, semaphore } = require "functors"
{ isEmpty, isString, withContinuation } = require "functors/helpers"
crypto = require 'crypto'
options = require('dreamopt') [
  "Usage:  migrate [options]"
  "  -f, --from DB        existing database"
  "  -t, --to DB          new database"
]

oldDb = new LazyValue (cb) ->
  db = new Database options.from, (err) ->
    return cb err, db

newDb = new LazyValue (cb) ->
  db = new Database options.to, (err) ->
    return cb err if err
    compose([
      db.all.bind db, """CREATE TABLE IF NOT EXISTS msgs (
        i INTEGER PRIMARY KEY, hash TEXT, msg BLOB)"""
      db.all.bind db, "CREATE UNIQUE INDEX IF NOT EXISTS msgs_idx ON msgs (hash)"
    ]) [], (err) ->
      cb err, db


getHash = (text) ->
  do (hash = crypto.createHash 'sha1') ->
    crypto.createHash 'sha1'
    .update text
    .digest 'hex'

      
migrateData = ({oldDb, newDb}, cb) ->
  oldDb.all "SELECT * FROM data", [], (err, data) ->
    data = data.map ( data ) ->
      console.log data
      data = data?.data
      if isEmpty data
        return null
      $msg: data
      $hash: getHash data
    .filter (x) -> x?
    console.log "Importing #{data.length} rows..."
    map( semaphore(1) newDb.all.bind newDb, """
        INSERT OR IGNORE INTO msgs (hash,msg) VALUES ($hash,$msg)"""
    ) data, cb

compose([
  product(oldDb.get, newDb.get)
  withContinuation ([oldDb, newDb]) -> {oldDb, newDb}
  migrateData
]) "token", (err) ->
  console.log err if err?
  console.log "Done importing 'data[tag,data]' into 'msgs[i,hash,msg]''"
