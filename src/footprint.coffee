do ->

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
                    backgroundColor: "rgba(255,255,255,0.05)"
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

    class VideoViewer

        constructor: (el) ->
            @el = $ el
            @heatmap = new LinearHeatmap @el
            @heatmap.setData [
                {
                    a: 0.1
                    b: 0.5
                    value: 1
                }
                {
                    a: 0.7
                    b: 0.9
                    value: 1
                }
            ]
            @heatmap.draw()


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
            @isLandscape = @width > @height
            @data = []
            @stopPoints = []
            @max = 1
            @colorPalette = do @buildColorPalette

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
            heatmapLength = Math.max @width, @height
            _.each @data, ({a, b, value}) =>
                from = Math.round a * heatmapLength
                to = Math.round b * heatmapLength
                length = to - from + 1
                @ctx.globalAlpha = 1

                @ctx.save()

                if @isLandscape
                    grd = @ctx.createLinearGradient 0, 0, length, 0
                    @ctx.translate from, 0
                else
                    grd = @ctx.createLinearGradient 0, 0, 0, length
                    @ctx.translate 0, from

                grd.addColorStop 0, "transparent"
                grd.addColorStop 0.2, "black"
                grd.addColorStop 0.8, "black"
                grd.addColorStop 1, "transparent"
                @ctx.fillStyle = grd

                if @isLandscape
                    @ctx.fillRect 0, 0, length, @height
                else
                    @ctx.fillRect 0, 0, @width, length

                @ctx.restore()
            grayHeatMap = @ctx.getImageData 0, 0, @width, @height
            @colorize grayHeatMap.data
            @ctx.putImageData grayHeatMap, 0, 0

        colorize: (pixels) ->
            for i in [3...pixels.length] by 4
                opacity = pixels[i]
                if opacity
                    pixels[i - 3] = @colorPalette[opacity][0] # r
                    pixels[i - 2] = @colorPalette[opacity][1] # g
                    pixels[i - 1] = @colorPalette[opacity][2] # b

        buildColorPalette: ->
            paletteLength = 256
            canvas = document.createElement "canvas"
            ctx = canvas.getContext "2d"
            grd = ctx.createLinearGradient 0, 0, 0, paletteLength
            canvas.width = 1
            canvas.height = paletteLength
            _.forIn (_.invert @defaultGradient), grd.addColorStop.bind grd
            ctx.fillStyle = grd
            ctx.fillRect 0, 0, 1, paletteLength
            _.chunk ctx.getImageData(0, 0, 1, paletteLength).data, 4

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
            ###
            $.post @host + "/save",
                type: "html"
                data: @data
            ###

    window.Footprint = (options = {}) ->

        typeMap =
            pdf: -> $ "#viewerContainer"
            html: -> $ "body"
            video: -> $ "video"

        if container = options.container
            $container = $ container
        else
            $container = typeMap[options.type or "html"]?()

        new VideoViewer ".fp-video-heatmap"
        #new Viewer $container
        #new Observer $container
