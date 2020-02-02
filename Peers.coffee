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
        {url, last = 0} = getOne(peers)
        [host, port=80] = url.split ":"
        console.log "Syncing with '#{host}:#{port} last=#{last}'"
        product([
          $.syncPeers.bind $ 
          $.getData.bind $
        ]) {host,port,last}, (err) ->
          return console.warn "Error syncing with '#{host}:#{port}' #{err}" if err?
          console.log "... syncing with '#{host}:#{port}' done"
    , @everyMillisecs

  syncPeers: ({host, port}, cb) ->
    { etat, proxy } = this
    compose([
      etat.getPeers.bind etat
      delay ({url}) -> { data: {url}, options: makeOptions proxy, host, port, "/peers" }
      httpPOST
      etat.addPeers.bind etat]) "all", cb

  getData: ({host, port, last = 0}, cb) ->
    { etat, proxy } = this
    compose([
      httpPOST
      delay (data) ->
        [..., last] = data
        [last.i, data]
      product([
        etat.updatePeer
        etat.addData.bind etat])
    ]) { options: makeOptions proxy, host, port, "/syncData" }, cb

module.exports = Peers
