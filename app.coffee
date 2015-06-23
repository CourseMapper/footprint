express = require "express"
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
    url: String
    type: String
    videoSrc: String
    maxValue: Number
    data: [DataSchema]

Point = mongoose.model "Point", PointSchema

app.use bodyParser.json()
app.use bodyParser.urlencoded extended: true

app.use cors
    allowedOrigins: [
        "fp.dev:*"
        "*.sabov.me:*"
    ]

app.use serveStatic "./dist"


prepareData = (data, length = 100) ->
    flatData = new Array length
    flatData[i] = 0 for i in [0...length]
    console.log "================="
    console.log "INPUT"
    console.log data

    maxValue = 0
    for {a, b, value} in data
        from = Math.round a * length
        to = Math.round b * length
        console.log "From - to"
        console.log [a, b]
        console.log [from, to]
        console.log to - from < 1
        console.log not (isFinite(a) and isFinite(b))
        break if to - from < 1 or not (isFinite(a) and isFinite(b))
        for i in [from..to]
            flatData[i] += +value
            if flatData[i] > maxValue
                maxValue = flatData[i]

    prevValue = obj = null
    preparedData = []
    for value, index in flatData
        if value isnt prevValue
            if prevValue
                obj.b = index/length
                obj.length = Math.round (obj.b - obj.a) * length
                preparedData.push obj
            obj = {
                a: index/length
                value
            }
            prevValue = value

    optimizedData = []

    index = 0
    while index < preparedData.length
        obj = preparedData[index]
        { a, b, length, value } = obj
        if length < 1
            ###
            prev = next = value: Number.POSITIVE_INFINITY
            if index < preparedData.length - 1
                next = preparedData[index + 1]
            if index > 0
                prev = preparedData[index - 1]

            prevDiff = Math.abs prev.value - value
            nextDiff = Math.abs next.value - value

            if prevDiff < nextDiff
                prev.b = b
                prev.value = Math.round (prev.value + value) / 2
                optimizedData.pop()
                optimizedData.push prev
            else
                next.a = a
                next.value = Math.round (next.value + value) / 2
                optimizedData.push next
                index++

            ###
        else
            optimizedData.push obj
        index++

    { preparedData: optimizedData, maxValue }

app.get "/get", (req, res) ->
    { videoSrc } = req.query
    searchObj =
        url: req.headers.referer
    if videoSrc
        searchObj.videoSrc = videoSrc
    Point.find searchObj, (err, result) ->
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
    console.log data

    searchObj =
        url: data.url

    if videoSrc
        data.videoSrc = videoSrc
        searchObj.videoSrc = videoSrc

    p = new Point data

    Point.find searchObj, (err, result) ->
        if result.length > 1
            console.log "More than one object was found"
        else if result.length is 1
            p = result[0]
            console.log data.data
            if data.data
                { preparedData, maxValue } = prepareData p.data.concat data.data
                p.data = preparedData
                p.maxValue = maxValue
        else
            if data.data
                { preparedData, maxValue } = prepareData data.data
                p.data = preparedData
                p.maxValue = maxValue

        if p.data.length
            p.save (err) ->
                res.json
                    code: 200
                    status: "OK"
                    id: p.id

app.listen 8080
