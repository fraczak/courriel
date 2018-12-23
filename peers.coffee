http = require "http"
{ map, compose, product, delay } = require "functors"

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

http_get = (url, cb) ->
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
          cb Error  "Error parsing data from '#{url}': #{err}"
  .on 'error', cb

update_state = (etat, url) ->
  compose([
    map http_get
    map delay (x) -> 
      x.map (m) ->
        Object.keys(m).reduce (res,k) ->
          res["$#{k}"] = m[k]; res
        , {}
    product etat.addPems.bind(etat), etat.addLetters.bind(etat)
   ]) ["#{url}/yp", "#{url}/letters"], (err) ->
    return console.warn "Error synchronizing with '#{url}': #{err}" if err
    console.log "Synchronized with '#{url}' successfully"

class peers
  constructor: (@etat, @peers, everySecs = 10) ->
    everyMillisecs = (everySecs or 10) * 1000
    $ = this
    @interval = setInterval ->
      $.peers.forEach (url) ->
        update_state $.etat, url
    , everyMillisecs

  

module.exports = (etat, peers, everySecs = 10) ->
  everyMillisecs = (everySecs or 10) * 1000
  setInterval ->
    peers.forEach (url) ->
      update_state etat, url
  , everyMillisecs
