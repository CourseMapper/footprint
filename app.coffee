express = require "express"
htmlData = require "fixtures/html"
serveStatic = require "serve-static"
mongoose = require "mongoose"
bodyParser = require "body-parser"
cors = require "express-cors"

app = express()
connectionString = "mongodb://localhost:27017/fp"
mongoose.connect connectionString

DataSchema = new mongoose.Schema
    a: Number
    b: Number
    value: Number

PointSchema = new mongoose.Schema
    type: String
    data: [DataSchema]

Point = mongoose.model "Point", PointSchema

app.use bodyParser.json()
app.use bodyParser.urlencoded extended: true

app.use cors
    allowedOrigins: [
        "fp.dev:*"
    ]

app.use serveStatic "./dist"

app.get "/get", (req, res) ->
    console.log "GET"
    Point.find {}, (err, result) ->
        res.json {
            result
            code: 200
            status: "OK"
        }

app.post "/save", (req, res, next) ->
    data = req.body
    p = new Point data
    console.log p
    p.save (err) ->
        res.json
            code: 200
            status: "OK"
            id: p.id

app.listen 3000
