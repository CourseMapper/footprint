express = require "express"
htmlData = require "fixtures/html"

app = express()

app.get "/get", (req, res) ->
    res.send htmlData

app.listen 3000

