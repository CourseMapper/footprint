express = require "express"
serveStatic = require "serve-static"
mongoose = require "mongoose"
bodyParser = require "body-parser"
cors = require "express-cors"
_ = require "lodash"

app = express()

# MongoDB configuration

connectionString = "mongodb://localhost:27017/fp"
mongoose.connect connectionString

rawDataSchema = new mongoose.Schema
    key: Number
    data: Array

HeatmapSchema = new mongoose.Schema
    url: String
    type: String
    videoSrc: String
    maxValue: Number
    data: Array
    rawData: [rawDataSchema]

Heatmap = mongoose.model "Heatmap", HeatmapSchema

# Application

app.use bodyParser.json()
app.use bodyParser.urlencoded extended: true

app.use cors
    allowedOrigins: [
        "fp.dev:*"
        "*.sabov.me:*"
    ]

app.use serveStatic "./dist"

# Helpers

getValueCoefficient = (a, b) -> Math.min Math.pow(a + (b - a) / 2, 1/2) * 4, 1

mergeData = (a, b) -> _.map _.zip(a, b), _.sum

prepareData = (data, length = 100) ->

    data = _.map data, ({value, a, b}) ->
        value = value * getValueCoefficient +a, +b
        value: value.toFixed 2
        a: +a
        b: +b

    flatData = new Array length
    flatData[i] = 0 for i in [0...length]

    for {a, b, value} in data
        from = Math.round a * length
        to = Math.round b * length
        break if to - from < 1 or not (isFinite(a) and isFinite(b))
        for i in [from..to]
            flatData[i] += +value

    flatData

# Routes

app.get "/get", (req, res) ->
    { videoSrc } = req.query
    searchObj =
        url: req.headers.referer
    if videoSrc
        searchObj.videoSrc = videoSrc
    Heatmap.find searchObj, (err, result) ->
        result = result[0]
        res.json {
            result
            code: 200
            status: "OK"
        }

app.post "/save", (req, res, next) ->
    data = req.body
    { videoSrc } = req.query
    data.url = req.headers.referer

    key = data.key
    delete data.key
    console.log data

    searchObj =
        url: data.url

    if data.videoSrc
        searchObj.videoSrc = data.videoSrc

    heatmap = new Heatmap data

    Heatmap.find searchObj, (err, result) ->
        if result.length > 1
            console.log "More than one object was found"
        else
            preparedData = prepareData data.data
            if result.length is 1
                heatmap = result[0]
                heatmap.data = mergeData heatmap.data, preparedData
            else
                heatmap.data = preparedData
            heatmap.maxValue = _.max heatmap.data

        rawData = _.find heatmap.rawData, key: +key
        if rawData
            rawData.data = mergeData rawData.data, preparedData
        else
            heatmap.rawData.push
                key: key
                data: preparedData

        if heatmap.data.length
            heatmap.save (err) ->
                res.json
                    code: 200
                    status: "OK"
                    id: heatmap.id
        else
            res.json
                code: 503
                status: "Bad request"

app.get "/calc", (req, res) ->
    Heatmap.find {}, (err, heatmaps) ->
        _.each heatmaps, (heatmap) ->
            data = _.pluck heatmap.rawData, "data"
            zipped = _.zip.apply _, data
            heatmap.data = _.map zipped, _.sum
            heatmap.save()
        res.json {
            result: _.pluck heatmaps, "url"
            code: 200
            status: "OK"
        }

app.listen 8080
