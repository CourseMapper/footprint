create = (tag) -> $ "<#{tag}></#{tag}>"

buildWidget = ->
    create "div"
    .addClass "scrollbar-holder"
    .css
        position: "fixed"
        zIndex: 99999
        width: "130px"
        right: "0px"
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

host = "http://46.101.153.234:3000"
if location.hostname is "fp.dev"
    host = "http://localhost:3000"

$ ->
    $body = $ "body"
    $body.append buildWidget()
    $scrollBarHolder = $ ".scrollbar-holder"
    $scrollBar = $ ".scrollbar"
    $scroll = $ ".scroll"
    ###
    heatmap = h337.create
        container: $scrollBar.get 0
    ###
    body = document.body
    html = document.documentElement
    pageHeight = Math.max body.scrollHeight, body.offsetHeight,
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

            ###
            heatmap.setData
                max: 5
                data: extendedData
            ###

    windowHeeight = $(window).height()
    scrollHeight = Math.floor(Math.pow(windowHeight, 2) / pageHeight) - 8
    $scroll.height _.max([scrollHeight, 18]) + "px"

    $(window).scroll (e) ->
        $scroll.css top: Math.round(e.originalEvent.pageY / ((pageHeight - windowHeight)/(windowHeight - $scroll.outerHeight()))) + "px"

    windowWidth = $(window).width()
    isOpen = false

    ###
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
    ###

    $scrollBar.on "mousedown", (e) ->
        $(window).scrollTop (e.clientY - $scroll.outerHeight() / 2) * ((pageHeight - windowHeight)/(windowHeight - $scroll.outerHeight()))
        $scrollBar.on "mousemove", (e) ->
            $(window).scrollTop (e.clientY - $scroll.outerHeight() / 2) * ((pageHeight - windowHeight)/(windowHeight - $scroll.outerHeight()))

    $(window).on "mouseup", (e) ->
        $scrollBar.off "mousemove"

    #console.log $ ".content"
    #$(".content").annotator()

# Inspired by https://github.com/mourner/simpleheat
class LinearHeatmap

    constructor: (canvas) ->
        canvas = create "canvas"
        .appendTo ".scrollbar"
        canvas = $(canvas).get 0
        @ctx = canvas.getContext "2d"
        { @width, @height } = canvas
        @data = []
        @max = 1
        @palette = do @buildPalette
        console.log @palette
        do @draw

    defaultGradient:
        0.4: "blue"
        0.6: "cyan"
        0.7: "lime"
        0.8: "yellow"
        1.0: "red"

    clear: -> @ctx.clearRect 0, 0, @width, @height

    draw: ->
        do @clear
        grd = @ctx.createLinearGradient 0, 0, 0, @height
        grd.addColorStop 0.5, @getRGBColor 255
        @ctx.fillStyle = grd
        @ctx.fillRect 0, 0, @width, @height

    buildPalette: ->
        canvas = document.createElement "canvas"
        ctx = canvas.getContext "2d"
        grd = ctx.createLinearGradient 0, 0, 0, 256
        canvas.width = 1
        canvas.height = 256
        _.forIn (_.invert @defaultGradient), grd.addColorStop.bind grd
        ctx.fillStyle = grd
        ctx.fillRect 0, 0, 1, 256
        _.chunk ctx.getImageData(0, 0, 1, 256).data, 4

    getRGBColor: (index) -> "rgb(#{@palette[index].slice(0, -1).join ","})"

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
        ###
        $.post host + "/save",
            type: "html"
            data: @data
        ###

$ -> new Observer
$ -> new LinearHeatmap
