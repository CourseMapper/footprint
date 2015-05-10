create = (tag) -> $ "<#{tag}></#{tag}>"

buildWidget = ->
    create "div"
    .addClass "scrollbar-holder"
    .css
        position: "fixed"
        zIndex: 99999
        width: "50px"
        right: "-38px"
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
                backgroundColor: "rgba(255,255,255,0.1)"
                top: 0
                right: 0
                width: "100%"
                pointerEvents: "none"
        )

getHost = ->
    if location.hostname is "fp.dev"
        "http://localhost:3000"
    else
        "http://46.101.153.234:3000"
class Viewer

    constructor: (el = body) ->
        @el = $ el
        @scrollBarHolder = @scrollBar = @scroll = @top = null
        @host = getHost()
        @data = null
        @isOpen = false
        @initWidget()
        @initScroll()
        @initEvents()
        @heatmap = new LinearHeatmap @scrollBar
        @getData()
        .done =>
            @heatmap.setData @data
            @heatmap.draw()

    initWidget: ->
        { @top } = @el.offset()
        contentHeight = @el.get(0).scrollHeight

        @scrollBarHolder = buildWidget()
        @scrollBarHolder.css top: @top
        @scrollBar = @scrollBarHolder.find ".scrollbar"
        @scroll = @scrollBarHolder.find ".scroll"
        @el.append @scrollBarHolder
        @setScrollSize()

    getData: ->
        $.get @host + "/get", (response) =>
            @data = _.first(response.result)?.data

    setScrollSize: ->
        contentHeight = @el.get(0).scrollHeight
        scrollHeight = Math.floor(Math.pow(@scrollBarHolder.height(), 2) / contentHeight) - 12
        @scroll.height _.max([scrollHeight, 18]) + "px"

    initScroll: ->
        @el.scroll =>
            @setScrollSize()
            scrollHeight = @scroll.outerHeight()
            contentHeight = @el.get(0).scrollHeight
            windowHeight = @scrollBarHolder.height()
            top = @el.scrollTop()

            top = top / ((contentHeight - windowHeight) / (windowHeight - scrollHeight))
            top = Math.round top
            top += "px"
            @scroll.css { top }

    getElScrollPosition: (clientY) ->
        windowHeight = @scrollBarHolder.height()
        contentHeight = @el.get(0).scrollHeight
        (clientY - @scroll.outerHeight() / 2) * ((contentHeight - windowHeight)/(windowHeight - @scroll.outerHeight()))

    initEvents: ->
        $(window)
            .on "resize", => @setScrollSize()
            .on "mousemove", (e) =>
                isMouseClose = $(window).width() - e.pageX < 50
                if isMouseClose and not @isOpen
                    @scrollBarHolder.animate right: 0
                    @isOpen = true
                if not isMouseClose and @isOpen
                    @isOpen = false
                    @scrollBarHolder.animate right: "-38px"
            .on "mouseup", (e) =>
                @scrollBar.off "mousemove"

        @scrollBarHolder.on "mousewheel", (e) =>
            @el.scrollTop()
            @el.scrollTop @el.scrollTop() - e.deltaY
            true

        @scrollBar.on "mousedown", (e) =>
            @el.scrollTop @getElScrollPosition e.clientY - @top
            @scrollBar.on "mousemove", (e) =>
                @el.scrollTop @getElScrollPosition e.clientY - @top

# Inspired by https://github.com/mourner/simpleheat
class LinearHeatmap

    constructor: (holder) ->
        $holder = $ holder
        canvas = create "canvas"
        .appendTo $holder
        @canvas = canvas.get 0
        @ctx = @canvas.getContext "2d"
        @canvas.width = @width = $holder.width()
        @canvas.height = @height = $holder.height()
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
        _.each @data, ({a, b, value}) =>
            from = Math.round a * @height
            to = Math.round b * @height
            length = to - from + 1
            @ctx.lineWidth = 0.2
            _.each [from...to], (y) =>
                k = Math.floor ((y - from) / length) * 100
                @ctx.globalAlpha = 0.001 * @sampleLine[k][3]
                @ctx.beginPath()
                @ctx.moveTo 0, y
                @ctx.lineTo @width, y
                @ctx.stroke()
        grayHeatMap = @ctx.getImageData 0, 0, @width, @height
        @colorize grayHeatMap.data
        console.log "done"
        @ctx.putImageData grayHeatMap, 0, 0

    colorize: (pixels) ->
        for i in [3...pixels.length] by 4
            opacity = pixels[i]
            if opacity
                pixels[i - 3] = @colorPalette[opacity][0] # r
                pixels[i - 2] = @colorPalette[opacity][1] # g
                pixels[i - 1] = @colorPalette[opacity][2] # b

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
        ctx.shadowBlur = 25
        ctx.shadowColor = "black"

        ctx.beginPath()
        ctx.rect -300, 15, 100, 50
        ctx.closePath()
        ctx.fill()
        _.map _.chunk ctx.getImageData(0, 0, 1, 100).data, 4

    getRGBAColor: (index) -> "rgba(#{@colorPalette[index].join ","})"

class Observer

    constructor: (el = body) ->
        @el = $ el
        { @top } = @el.offset()
        @host = getHost()
        setTimeout =>
            @initEvents()
        , 1000

    data: []

    initEvents: ->
        @tock = new Tock
            interval: 1000
            callback: @saveScrollPosition.bind @
        .start()
        $(window).on "unload", => do @sendData

    saveScrollPosition: ->
        contentHeight = @el.get(0).scrollHeight
        p = @getCurrViewportPosition()
        @data.push
            value: 1
            a: p.top / contentHeight
            b: p.bottom / contentHeight

    getCurrViewportPosition: ->
        top = @el.scrollTop()
        bottom = @el.height() + top
        { top, bottom }

    sendData: ->
        $.post @host + "/save",
            type: "html"
            data: @data

$ ->
    new Observer "#viewerContainer"
    new Viewer "#viewerContainer"
