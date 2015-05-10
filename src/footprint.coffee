create = (tag) -> $ "<#{tag}></#{tag}>"

buildWidget = ->
    create "div"
    .addClass "scrollbar-holder"
    .css
        position: "fixed"
        zIndex: 99999
        width: "130px"
        right: "-118px"
        top: 0
        bottom: 0
        backgroundColor: "#333"
    .append (create "div"
            .addClass "scrollbar"
            .css
                width: "100%"
                height: "100%"
        ),
        (create "div"
            .addClass "scroll"
            .css
                height: "100px"
                borderTop: "4px solid #EEE"
                borderBottom: "4px solid #EEE"
                position: "absolute"
                backgroundColor: "rgba(255,255,255,0)"
                top: 0
                right: 0
                width: "100%"
                pointerEvents: "none"
        )

###
$ ->
    $container = $ "#viewer"
    $container.append buildWidget()
    $scrollBarHolder = $container.find ".scrollbar-holder"
    $scrollBar = $container.find ".scrollbar"
    $scroll = $container.find ".scroll"

    heatmap = h337.create
        container: $scrollBar.get 0

    heatmap = new LinearHeatmap
    body = document.body
    html = document.documentElement
    pageHeight = Math.max $container.get(0).scrollHeight, $container.get(0).offsetHeight,
        html.clientHeight, html.scrollHeight, html.offsetHeight
    windowHeight = $(window).height()

    extendedData = []

    $.get host + "/get", (response) ->
        points = _.first response.result
        if points
            data = []
            _.each points.data, (item) ->
                a = item.a * windowHeight
                b = item.b * windowHeight
                data = data.concat _.map (_.range a, b, 20), (y) ->
                    value: 1
                    y: y

            _.each data, (item) ->
                xVals = (x for x in [-20..300] by 10)
                _.each xVals, (x) ->
                    newItem = _.clone item
                    newItem.x = x
                    extendedData.push newItem

            heatmap
                .setData points.data
                .draw()

            heatmap.setData
                max: 5
                data: extendedData

    scrollHeight = Math.floor(Math.pow(windowHeight, 2) / pageHeight) - 8
    $scroll.height _.max([scrollHeight, 18]) + "px"

    $container.scroll (e) ->
        $scroll.css top: Math.round(e.originalEvent.pageY / ((pageHeight - windowHeight)/(windowHeight - $scroll.outerHeight()))) + "px"

    windowWidth = $(window).width()
    isOpen = false

    $(window).on "mousemove", (e) ->
        isMouseClose = windowWidth - e.pageX < 150
        if isMouseClose and not isOpen
            console.log "open"
            $scrollBarHolder.animate right: 0
            isOpen = true
        if not isMouseClose and isOpen
            console.log "close"
            isOpen = false
            $scrollBarHolder.animate right: "-118px"

    $scrollBar.on "mousedown", (e) ->
        $(window).scrollTop (e.clientY - $scroll.outerHeight() / 2) * ((pageHeight - windowHeight)/(windowHeight - $scroll.outerHeight()))
        $scrollBar.on "mousemove", (e) ->
            $(window).scrollTop (e.clientY - $scroll.outerHeight() / 2) * ((pageHeight - windowHeight)/(windowHeight - $scroll.outerHeight()))

    $(window).on "mouseup", (e) ->
        $scrollBar.off "mousemove"

    #console.log $ ".content"
    #$(".content").annotator()
###

class Viewer

    constructor: (el = body) ->
        @el = $ el
        @host = @getHost()
        @data = null
        @initWidget()
        @initScroll()
        @heatmap = new LinearHeatmap
        @getData()
        .done =>
            @heatmap.setData @data
            @heatmap.draw()

    initWidget: ->
        { top } = @el.offset()
        contentHeight = @el.get(0).scrollHeight

        $scrollBarHolder = buildWidget()
        $scrollBarHolder.css { top }
        $scroll = $scrollBarHolder.find ".scroll"
        @el.append $scrollBarHolder

        scrollHeight = Math.floor(Math.pow($scrollBarHolder.height(), 2) / contentHeight) - 8
        $scroll.height _.max([scrollHeight, 18]) + "px"

    getHost: ->
        if location.hostname is "fp.dev"
            "http://localhost:3000"
        else
            "http://46.101.153.234:3000"

    getData: ->
        $.get @host + "/get", (response) =>
            @data = _.first(response.result)?.data

    initScroll: ->
        $scroll = @el.find ".scroll"
        @el.scroll =>
            scrollHeight = $scroll.outerHeight()
            contentHeight = @el.get(0).scrollHeight
            windowHeight = $(window).height()
            top = @el.scrollTop()

            top = top / ((contentHeight - windowHeight) / (windowHeight - scrollHeight))
            top = Math.round top
            top += "px"
            $scroll.css { top }

# Inspired by https://github.com/mourner/simpleheat
class LinearHeatmap

    constructor: (canvas) ->
        canvas = create "canvas"
        .appendTo ".scrollbar"
        canvas = $(canvas).get 0
        @ctx = canvas.getContext "2d"
        { @width, @height } = canvas
        @data = []
        @stopPoints = []
        @max = 1
        @colorPalette = do @buildColorPalette
        @sampleLine = do @buildSampleLine

    defaultMaxStopPoint: 100

    defaultGradient:
        0.4: "blue"
        0.6: "cyan"
        0.7: "lime"
        0.8: "yellow"
        1.0: "red"

    clear: -> @ctx.clearRect 0, 0, @width, @height

    setData: (@data) ->
        do @prepareData
        @

    prepareData: ->
        @stopPoints = new Array @height
        _.fill @stopPoints, 0
        _.each @data, ({a, b, value}) =>
            from = Math.round a * @height
            to = Math.round b * @height
            @stopPoints[i] += value for i in [from...to]
        @maxStopPoint = _.max @stopPoints.concat [@defaultMaxStopPoint]

    draw: ->
        do @clear
        grd = @ctx.createLinearGradient 0, 0, 0, @height
        _.each @stopPoints, (value, point) =>
            grd.addColorStop point / @height, @getRGBAColor Math.round value * 255 / @maxStopPoint
        @ctx.fillStyle = grd
        @ctx.fillRect 0, 0, @width, @height

    buildColorPalette: ->
        canvas = document.createElement "canvas"
        ctx = canvas.getContext "2d"
        grd = ctx.createLinearGradient 0, 0, 0, 256
        canvas.width = 1
        canvas.height = 256
        _.forIn (_.invert @defaultGradient), grd.addColorStop.bind grd
        ctx.fillStyle = grd
        ctx.fillRect 0, 0, 1, 256
        _.map (_.chunk ctx.getImageData(0, 0, 1, 256).data, 4), ([r,g,b,a], i) ->
            a = Math.pow i/200, 2
            [r,g,b,a]

    buildSampleLine: ->
        canvas = document.createElement "canvas"
        ctx = canvas.getContext "2d"
        canvas.width = 1
        canvas.height = 100
        ctx.shadowOffsetX = 200
        ctx.shadowBlur = 15
        ctx.shadowColor = "black"

        ctx.beginPath()
        ctx.rect -300, 15, 100, 100
        ctx.closePath()
        ctx.fill()
        _.map _.chunk ctx.getImageData(0, 0, 1, 100).data, 4

    getRGBAColor: (index) -> "rgba(#{@colorPalette[index].join ","})"

class Observer

    constructor: ->
        body = document.body
        html = document.documentElement
        @pageHeight = Math.max body.scrollHeight, body.offsetHeight,
            html.clientHeight, html.scrollHeight, html.offsetHeight
        @initEvents()

    data: []

    initEvents: ->
        @tock = new Tock
            interval: 1000
            callback: @saveScrollPosition.bind @
        .start()
        $(window).on "unload", => do @sendData

    saveScrollPosition: ->
        p = @getCurrViewportPosition()
        @data.push
            value: 1
            a: p.top / @pageHeight
            b: p.bottom / @pageHeight

    getCurrViewportPosition: ->
        top = window.pageYOffset
        bottom = top + $(window).height()
        { top, bottom }

    sendData: ->
        $.post host + "/save",
            type: "html"
            data: @data

$ ->
    #new Observer
    setTimeout ->
        new Viewer "#viewerContainer"
    , 1000
