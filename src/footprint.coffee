create = (tag) -> $ "<#{tag}></#{tag}>"

buildWidget = ->
    create "div"
    .addClass "scrollbar-holder"
    .css
        position: "fixed"
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
            .append create "canvas"
        ),
        (create "div"
            .addClass "scroll"
        )
host = "http://sabov.me:3000"
if location.hostname is "fp.dev"
    host = "http://localhost:3000"

$ ->
    $body = $ "body"
    $body.append buildWidget()
    $scrollBarHolder = $ ".scrollbar-holder"
    $scrollBar = $ ".scrollbar"
    $scroll = $ ".scroll"
    heatmap = h337.create
        container: $scrollBar.get 0
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

            heatmap.setData
                max: 5
                data: extendedData

    console.log $(window).height()
    $scroll.height Math.floor(Math.pow($(window).height(), 2) / pageHeight) - 16 + "px"

    $(window).scroll (e) ->
        $scroll.css top: 100 *  e.originalEvent.pageY / $body.height() + "%"

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

    console.log $ ".content"
    $(".content").annotator()

# Inspired by https://github.com/mourner/simpleheat
class LinearHeatmap

    constructor: (canvas) ->
        canvas = $(canvas).get 0
        @ctx = canvas.getContext "2d"
        { @width, @height } = canvas
        @data = []
        @max = 1

    defaultGradient:
        0.4: "blue"
        0.6: "cyan"
        0.7: "lime"
        0.8: "yellow"
        1.0: "red"

    draw: ->
        @ctx.clearRect 0, 0, @width, @height
        _.each data, ([a, b, value]) ->


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

$ -> new Observer
