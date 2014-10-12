express = require "express"

app = express()

app.get "/get", (req, res) ->
    res.send {
        point: [1,2]
    }

app.listen 3000

