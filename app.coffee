express = require "express"
htmlData = require "fixtures/html"
serveStatic = require "serve-static"

app = express()

app.use serveStatic "./dist"

app.get "/get", (req, res) ->
    res.send htmlData

app.post "/save", (req, res) ->
    data = res.body
    console.log data

app.listen 3000

