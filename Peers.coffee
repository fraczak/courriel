http = require "http"
{ parse }  = require "url"
{ map, compose, product, delay } = require "functors"
{ isEmpty } = require "functors/helpers"

once = (fn) -> (a...) -> do (r = fn?.apply? this, a) -> fn = null; r

normalize = do ->
  resError = (res) ->
    err = if 200 <= res.statusCode < 300 then null else "Error: Response status code: #{res.statusCode}"
    console.error err if err
    res.on 'data', (data) ->
      console.error data.toString() if err
    err
  (fn) ->
    (res) ->
      fn resError(res), res

httpGET = (url, cb) ->
  cb = once cb
  http.get url, normalize (err, res) ->
    do (data = []) ->
      res.setEncoding 'utf8'
      .on 'data', (chunk) -> 
        data.push chunk
      .on 'end', ->
        try
          cb null, JSON.parse data.join ''
        catch err 
          console.log data.join ''
          cb Error  "Error parsing data from '#{url}': #{err}"
  .on 'error', cb

httpPOST = ({url, data}, cb) ->
  cb = once cb
  http.request Object.assign( parse(url), {
    method: "POST"
    headers: 'Content-Type': 'application/json'
  }), normalize (err, res) ->
    do (data = []) ->    
      res.setEncoding 'utf8'
      .on 'data', (chunk) -> 
        data.push chunk
      .on 'end', ->
        try
          cb null, JSON.parse data.join ''
        catch err 
          cb Error "Error parsing data from '#{url}': #{err}"
  .on 'error', cb
  .end JSON.stringify data

getOne = (list) ->
  list[Math.floor(Math.random() * list.length)]

class Peers
  constructor: (etat, everySecs = 30) ->
    @everyMillisecs = everySecs * 1000
    @etat = etat
    $ = this
    @interval = setInterval ->
      etat.getPeers "all", (err, peers) ->
        return console.warn "Error getting peers: #{err}" if err
        return console.log "No peers" if isEmpty peers
        { url } = getOne peers
        console.log "Syncing with #{url}"
        product([
          $.syncPeers.bind $ 
          $.syncData.bind $
        ]) url, (err) ->
          return console.warn "Error syncing with #{url}: #{err}" if err
          console.log "... syncing with #{url} done"
    , @everyMillisecs

  syncPeers: (url, cb) ->
    etat = @etat
    etat.getPeers "all", (err, peers) ->
      return cb err if err
      httpPOST {url:"#{url}/peers", data: peers}, (err, peers) ->
        return cb err if err
        etat.addPeers peers, cb

  syncData: (url, cb) ->
    etat = @etat
    httpGET "#{url}/getData", (err, dataz) ->
      console.log "--Data------>", dataz
      return cb err if err
      for data in dataz
        etat.addData data, cb

module.exports = Peers
