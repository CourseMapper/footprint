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
            @seekHandle = @el.find ".fp-seek-handle"
            @videoProgress = @el.find ".fp-video-progress"
            @isSeeking = false
            @video = $ "video"
            @host = getHost()
            @heatmap = new LinearHeatmap @el
            @getData()
            .done =>
                @heatmap.setData @data
                @heatmap.draw()
            @initEvents()

        getData: ->
            { currentSrc } = @video.get 0
            $.get @host + "/get?videoSrc=#{currentSrc}", (response) =>
                @data = _.first(response.result)?.data

        initEvents: ->

            @video.on "timeupdate", =>
                return if @isSeeking

                { duration, currentTime } = @video.get 0
                progressWidth = Math.floor (100 / duration) * currentTime
                @seekHandle.css "left", progressWidth + "%"
                @videoProgress.css "width", progressWidth + "%"

            @el.on "click", (e) =>
                video = @video.get 0
                point = (e.pageX - @el.offset().left) / @el.width()
                if video.duration
                    video.currentTime = video.duration * point
                else
                    video.play()

            @seekHandle.on "mousedown", (e) =>
                @isSeeking = true
                { clientX, clientY } = e
                { left } = @seekHandle.offset()
                @seekHandle.addClass "active"
                $(window).on "mousemove", (e) =>
                    @seekHandle.css "left", e.clientX - clientX + left + "px"
                    @videoProgress.css "width", e.clientX - clientX + left + "px"

                $(window).on "mouseup", (e) =>
                    $(window).off "mousemove"
                    $(window).off "mouseup"
                    @isSeeking = false
                    video = @video.get 0
                    @seekHandle.removeClass "active"
                    point = (@seekHandle.offset().left - @el.offset().left) / @el.width()
                    console.log point
                    if video.duration
                        video.currentTime = video.duration * point
                    else
                        video.play()

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
            #do @prepareData
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
                @ctx.globalAlpha = 0.1

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
            $.post @host + "/save",
                type: "html"
                data: @data

    class VideoObserver

        constructor: (el) ->
            @el = $ el
            @host = getHost()
            @initEvents()

        data: []

        initEvents: ->
            video = @el.get 0
            interval = start = end = prev = null

            @el.on "playing", =>
                start = video.currentTime / video.duration
                interval =
                    a: start
                    b: start
                    value: 1
                @data.push interval

            @el.on "timeupdate", ->
                if start >= 0 and end > start
                    interval.b = end
                end = prev
                prev = video.currentTime / video.duration

            @el.on "pause", ->
                if start >= 0 and end > start
                    interval.b = end
                    start = end = null

            $(window).on "unload", =>
                @el.get(0).pause()
                @sendData()

        sendData: ->
            { currentSrc } = @el.get 0
            $.post @host + "/save?videoSrc=#{currentSrc}",
                type: "html"
                data: @data

    window.Footprint = (options = {}) ->

        typeMap =
            pdf: ->
                $container = $ options.container or "#viewerContainer"
                new Viewer $container
                new Observer $container
            html: ->
                $container = $ options.container or "body"
                new Viewer $container
                new Observer $container
            video: ->
                $container = $ options.container or "video"
                new VideoViewer ".fp-video-heatmap"
                new VideoObserver "video"

        $ -> typeMap[options.type or "html"]?()
