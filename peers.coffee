http = require "http"

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

update_state = (etat, url) ->
  http.get url, normalize (err, res) ->
    return console.warm err if err

    do (data = []) ->
      res
      .setEncoding 'utf8'
      .on 'data', (chunk) ->
        data.push chunk
      .on 'end', ->
        console.log data
        try
          data = JSON.parse data.join ''
          etat.merge data
        catch err 
          console.error "Error parsing data from '#{url}': #{err}"
      .on 'error', (err) ->
        console.error "Error reading from '#{url}': #{err}"
  .on 'error', (err) ->
    console.error "Error connecting to '#{url}': #{err}"


module.exports = (etat, peers, everySecs = 10) ->
  everyMillisecs = (everySecs or 10) * 1000
  setInterval ->
    peers.forEach (url) ->
      update_state etat, url
  , everyMillisecs
