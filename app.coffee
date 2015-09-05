express = require "express"
serveStatic = require "serve-static"
mongoose = require "mongoose"
bodyParser = require "body-parser"
cors = require "express-cors"
_ = require "lodash"

app = express()
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

app.use bodyParser.json()
app.use bodyParser.urlencoded extended: true

app.use cors
    allowedOrigins: [
        "fp.dev:*"
        "*.sabov.me:*"
    ]

app.use serveStatic "./dist"

getValueCoefficient = (a, b) -> Math.min Math.pow(a + (b - a) / 2, 1/2) * 4, 1

prepareData = (data, length = 100) ->
    flatData = new Array length
    flatData[i] = 0 for i in [0...length]

    for {a, b, value} in data
        from = Math.round a * length
        to = Math.round b * length
        break if to - from < 2 or not (isFinite(a) and isFinite(b))
        for i in [from..to]
            flatData[i] += +value

    flatData

mergeData = (a, b) -> _.map _.zip(a, b), _.sum

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

    searchObj = url: data.url

    if videoSrc
        searchObj.videoSrc = videoSrc

    heatmap = new Heatmap data

    Heatmap.find searchObj, (err, result) ->
        if result.length > 1
            console.log "More than one object was found"
        else
            preparedData = prepareData data.data
            if result.length is 1 and data.data
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

app.listen 8080
