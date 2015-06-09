$ = require "jquery"
require "jquery-mousewheel"
require "./styles.less"

do ->

    getHost = ->
        if location.hostname is "fp.dev"
            "http://localhost:8080"
        else
            "http://46.101.153.234:8080"

    class Viewer

        constructor: (el, scrollEl) ->
            @el = $ el or "body"
            @scrollEl = $ scrollEl or el or window
            @scrollBarHolder = @scrollBtn = @scrollBar = @scroll = @top = null
            @host = getHost()
            @data = null
            @isOpen = false
            @docHeight = @getDocHeight()
            @initWidget()
            @setScrollPosition()
            @scrollEl.scroll => @setScrollPosition()
            @initEvents()
            @heatmap = new LinearHeatmap @scrollBar
            @getData()
            .done (response) =>
                @heatmap.setData @data
                    .setMaxValue response.result?.maxValue
                    .draw()

        initWidget: ->
            tpl = require "./scroll.jade"
            { @top } = @el.offset()
            contentHeight = @el.get(0).scrollHeight

            @scrollBarHolder = $ tpl()
            @scrollBarHolder.css top: @top
            @scrollBar = @scrollBarHolder.find ".fp-scrollbar"
            @scroll = @scrollBarHolder.find ".fp-scroll"
            @scrollBtn = @scrollBarHolder.find ".fp-scroll-btn"
            @el.append @scrollBarHolder
            @setScrollSize()

        getData: ->
            $.get @host + "/get", (response) =>
                @data = response.result?.data

        setScrollSize: ->
            contentHeight = @el.get(0).scrollHeight
            scrollHeight = Math.floor(Math.pow(@scrollBarHolder.height(), 2) / contentHeight) - 12
            @scroll.height Math.max(scrollHeight, 18) + "px"

        setScrollPosition: ->
            @setScrollSize()
            scrollHeight = @scroll.outerHeight()
            contentHeight = @scrollEl.get(0).scrollHeight or @docHeight
            windowHeight = @scrollBarHolder.height()
            top = @scrollEl.scrollTop()

            top = top / ((contentHeight - windowHeight) / (windowHeight - scrollHeight))
            top = Math.round top
            top += "px"
            @scroll.css { top }

        getDocHeight: ->
            d = document
            Math.max d.body.scrollHeight, d.documentElement.scrollHeight,
                d.body.offsetHeight, d.documentElement.offsetHeight,
                d.body.clientHeight, d.documentElement.clientHeight

        getElScrollPosition: (clientY) ->
            docHeight = @getDocHeight()
            windowHeight = @scrollBarHolder.height()
            contentHeight = @el.get(0).scrollHeight or @docHeight
            (clientY - @scroll.outerHeight() / 2) * ((contentHeight - windowHeight)/(windowHeight - @scroll.outerHeight()))

        destroy: -> @scrollBarHolder.remove()

        initEvents: ->
            @scrollEl
                .on "resize", => @setScrollSize()
                .on "mousemove", (e) =>
                    shouldOpen = $(window).width() - e.pageX < 20
                    shouldClose = $(window).width() - e.pageX < 50
                    if shouldOpen and not @isOpen
                        @scrollBarHolder.animate
                            right: 0
                        @scrollBtn.animate
                            opacity: 1
                        @scrollBtn.css opacity: 1
                        @isOpen = true
                    if not shouldClose and @isOpen
                        @isOpen = false
                        @scrollBarHolder.animate
                            right: "-38px"
                        @scrollBtn.animate
                            opacity: 0
                .on "mouseup", (e) =>
                    @scrollBar.off "mousemove"

            @scrollBarHolder.on "mousewheel", (e) =>
                @scrollEl.scrollTop()
                @scrollEl.scrollTop @scrollEl.scrollTop() - e.deltaY
                true

            @scrollBar.on "mousedown", (e) =>
                @scrollEl.scrollTop @getElScrollPosition e.clientY - @top
                @scrollBar.on "mousemove", (e) =>
                    @scrollEl.scrollTop @getElScrollPosition e.clientY - @top

            @scrollBtn.on "click", =>
                @destroy()

    class VideoViewer

        constructor: (video) ->
            tpl = require "./slider.jade"
            @el = $ tpl()
            @seekHandle = @el.find ".fp-seek-handle"
            @videoProgress = @el.find ".fp-video-progress"
            @isSeeking = false
            @video = $ video
            @host = getHost()
            @el.insertBefore @video
            setTimeout =>
                @refreshSize()
                @heatmap = new LinearHeatmap @el
                @getData()
                .done (response) =>
                    @heatmap.setData @data
                        .setMaxValue response.result?.maxValue
                        .draw()
                @initEvents()
            , 1000
            setInterval =>
                @refreshSize()
            , 1000

        getData: ->
            { currentSrc } = @video.get 0
            $.get @host + "/get?videoSrc=#{currentSrc}", (response) =>
                @data = response.result?.data

        refreshSize: ->
            @el.css
                width: @video.width()
                opacity: 1

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
                    if video.duration
                        video.currentTime = video.duration * point
                    else
                        video.play()

    # Inspired by https://github.com/mourner/simpleheat
    class LinearHeatmap

        constructor: (holder) ->
            $holder = $ holder
            canvas = $ "<canvas></canvas>"
            .appendTo $holder
            @canvas = canvas.get 0
            @ctx = @canvas.getContext "2d"
            @canvas.width = @width = $holder.width()
            @canvas.height = @height = $holder.height()
            @isLandscape = @width > @height
            @data = []
            @stopPoints = []
            @max = 10
            @colorPalette = do @buildColorPalette

        defaultMaxStopPoint: 100

        defaultGradient:
            0.4: "blue"
            0.6: "cyan"
            0.7: "lime"
            0.8: "yellow"
            1.0: "red"

        clear: -> @ctx.clearRect 0, 0, @width, @height

        setMaxValue: (maxValue) ->
            @max = Math.max @max, +maxValue
            @

        setData: (@data) -> @

        draw: ->
            do @clear
            heatmapLength = Math.max @width, @height
            ###
            for {a, b, value}, index in @data
                from = Math.round a * heatmapLength
                to = Math.round b * heatmapLength
                length = to - from
                delta = heatmapLength * 0.01
                from = from - delta
                if from < 0
                    from = 0
                to = to + delta
                if to > heatmapLength
                    to = heatmapLength
                @ctx.globalAlpha = value / @max

                @ctx.save()

                length = length + delta * 2

                if @isLandscape
                    grd = @ctx.createLinearGradient 0, 0, length, 0
                    @ctx.translate from, 0
                else
                    grd = @ctx.createLinearGradient 0, 0, 0, length
                    @ctx.translate 0, from

                if from is 0
                    grd.addColorStop 0, "black"
                else
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
            ###
            if @isLandscape
                grd = @ctx.createLinearGradient 0, 0, heatmapLength, 0
            else
                grd = @ctx.createLinearGradient 0, 0, 0, heatmapLength
            for {a, b, value}, index in @data
                grd.addColorStop a, "rgba(0,0,0,#{(value/@max).toFixed 2})"
                grd.addColorStop b, "rgba(0,0,0,#{(value/@max).toFixed 2})"
                if index is @data.length - 1
                    grd.addColorStop b + 0.01, "rgba(0,0,0,0)"
                if index < @data.length - 1
                    next = @data[index + 1]
                    nextA = Math.round next.a * 100
                    currB = Math.round b * 100
                    unless currB is nextA - 1
                        grd.addColorStop (currB + 1)/100, "rgba(0,0,0,0)"
                        grd.addColorStop (nextA - 1)/100, "rgba(0,0,0,0)"

            @ctx.fillStyle = grd
            if @isLandscape
                @ctx.fillRect 0, 0, heatmapLength, @height
            else
                @ctx.fillRect 0, 0, @width, heatmapLength
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
            for stopPoint, color of @defaultGradient
                grd.addColorStop stopPoint, color
            ctx.fillStyle = grd
            ctx.fillRect 0, 0, 1, paletteLength
            imageData = ctx.getImageData(0, 0, 1, paletteLength).data
            palette = []
            for color, i in imageData by 4
                palette.push [
                    imageData[i]
                    imageData[i + 1]
                    imageData[i + 2]
                    imageData[i + 3]
                ]
            palette

    class GenericObserver

        constructor: (@type = "html")->
            @host = getHost()
            @data = []
            @initEvents()

        initEvents: ->
            $(window).on "unload", =>
                @data = @prepareData()
                @sendData()

        prepareData: (length = 100) ->
            flatData = new Array length
            flatData[i] = 0 for i in [0...length]

            for {a, b, value} in @data
                from = Math.round a * length
                to = Math.round b * length
                flatData[i] += +value for i in [from..to]

            prevValue = obj = null
            preparedData = []
            for value, index in flatData
                if value isnt prevValue
                    if prevValue
                        obj.b = (index - 1)/length
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
                {a, b, length, value} = obj
                if length < 3
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

                else
                    optimizedData.push obj
                index++


            optimizedData

        getDocHeight: ->
            d = document
            Math.max d.body.scrollHeight, d.documentElement.scrollHeight,
                d.body.offsetHeight, d.documentElement.offsetHeight,
                d.body.clientHeight, d.documentElement.clientHeight

        sendData: ->
            $.post @host + "/save",
                data: @data
                type: @type

    class HtmlObserver extends GenericObserver

        constructor: (el = body, type) ->
            @el = $ el
            super type

        initEvents: ->
            setInterval =>
                @saveState()
            , 1000
            super()

        saveState: ->
            contentHeight = @el.get(0).scrollHeight or @getDocHeight()
            p = @getCurrViewportPosition()
            @data.push
                value: 0.1
                a: p.top / contentHeight
                b: p.bottom / contentHeight

        getCurrViewportPosition: ->
            top = @el.scrollTop()
            bottom = @el.height() + top
            { top, bottom }

    class VideoObserver extends GenericObserver

        constructor: (el) ->
            @el = $ el
            super "video"

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
                @data = @prepareData()
                @sendData()

        sendData: ->
            { currentSrc } = @el.get 0
            $.post @host + "/save?videoSrc=#{currentSrc}",
                type: @type
                data: @data

    window.Footprint = (options = {}) ->
        host = getHost()

        ###
        $ ->
            { currentSrc } = $("video").get 0
            $.get host + "/get?videoSrc=#{currentSrc}", (response) ->
                g = new GenericObserver
                g.data = response.result?.data
                console.log g.prepareData()
        ###

        typeMap =
            pdf: ->
                $container = $ options.container or "#viewerContainer"
                new Viewer $container
                new HtmlObserver $container, "pdf"
            html: ->
                $container = $ options.container or window
                new Viewer
                new HtmlObserver window, "html"
            video: ->
                $container = $ options.container or "video"
                new VideoViewer "video"
                new VideoObserver "video"

        $ -> typeMap[options.type or "html"]?()
