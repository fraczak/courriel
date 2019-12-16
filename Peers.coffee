http = require "http"
{ parse }  = require "url"
{ map, compose, product, delay } = require "functors"
{ isEmpty, isString } = require "functors/helpers"

once = (fn) -> 
  do (ran = false, result = null) ->
    (a...) -> 
      if ran
        console.trace "The function has been ran already!"
        return result if ran
      ran = true
      result = fn? a...

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

makeOptions = (proxy, host, port, path) -> 
  if proxy?
    host: proxy.hostname
    port: proxy.port
    path: "http://#{host}:#{port}#{path}"
    headers: Host: "#{host}"
  else
    host:host
    path:path
    port:port

httpGET = (options, cb) ->
  cb = once cb
  http.get options, normalize (err, res) ->
    return cb err if err?
    do (data = []) ->
      res.setEncoding 'utf8'
      .on 'data', (chunk) -> 
        data.push chunk
      .on 'end', ->
        try
          cb null, JSON.parse data.join ''
        catch err 
          console.log data.join ''
          cb Error "Error parsing data: #{err}"
  .on 'error', cb

httpPOST = ({options, data}, cb) ->
  cb = once cb
  options.method ?= "POST"
  options.headers = Object.assign {'Content-Type': 'application/json'}, options.headers
  http.request options, normalize (err, res) ->
    return cb err if err?
    do (data = []) ->
      res.setEncoding 'utf8'
      .on 'data', (chunk) -> 
        data.push chunk
      .on 'end', ->
        try
          cb null, JSON.parse data.join ''
        catch err 
          cb Error "Error parsing data from: #{err}"
  .on 'error', cb
  .end JSON.stringify data

getOne = (list) ->
  list[Math.floor(Math.random() * list.length)]

class Peers
  constructor: (etat, proxy, everySecs = 30) ->
    @everyMillisecs = everySecs * 1000
    @etat = etat
    @proxy = if isEmpty proxy
      null
    else if isString proxy
      do ([host, port=8123] = proxy.split ":") => 
        @proxy = {host, port}
    else
      proxy 
    $ = this
    @interval = setInterval ->
      etat.getPeers "all", (err, peers) ->
        return console.warn "Error getting peers: #{err}" if err
        return console.log "No peers" if isEmpty peers
        peer = getOne peers
        console.log "Syncing with '#{peer.host}:#{peer.port}'"
        product([
          $.syncPeers.bind $ 
          $.syncData.bind $
        ]) peer, (err) ->
          return console.warn "Error syncing with '#{peer.host}:#{peer.port}' #{err}" if err?
          console.log "... syncing with '#{peer.host}:#{peer.port}' done"
    , @everyMillisecs

  syncPeers: ({host, port}, cb) ->
    etat = @etat
    proxy = @proxy
    compose([
      etat.getPeers.bind etat
      delay (data) -> { data, options: makeOptions proxy, host, port, "/peers" }
      httpPOST
      etat.addPeers.bind etat]) "all", cb

  syncData: ({host, port}, cb) ->
    etat = @etat
    proxy = @proxy
    compose([
      etat.getData.bind etat 
      delay (data) -> { data, options: makeOptions proxy, host, port, "/syncData" }
      httpPOST
      etat.addData.bind etat]) "all", cb

module.exports = Peers
