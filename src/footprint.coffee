$ = require "jquery"
window.jQuery = $
require "jquery-mousewheel"
require "jquery.idle"
{ plyr } = require "../bower_components/plyr/dist/plyr.js"
sprite = require "../bower_components/plyr/dist/sprite.svg"
require "../bower_components/plyr/dist/plyr.css"
require "./styles.less"
config = require "./config"

$("body").prepend $ "<div style='display:none;'>#{sprite}</div>"

do ->

    getHost = -> config?.host || "http://localhost:8080"

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
                @el.find(".fp-scale-from").text 1
                if @data
                    @heatmap.setData @data
                        .setMaxValue response.result?.maxValue
                        .draw()
                @el.find(".fp-scale-to").text Math.round @heatmap.max

        initWidget: ->
            tpl = require "./scroll.jade"
            { @top } = @el.offset()
            contentHeight = @el.get(0).scrollHeight

            @scrollBarHolder = $ tpl()
            @scrollBarHolder.css top: @top
            @scrollBar = @scrollBarHolder.find ".fp-scrollbar"
            @scroll = @scrollBarHolder.find ".fp-scroll"
            @scrollBtn = @scrollBarHolder.find ".fp-btn_close"
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
                    shouldOpen = $(window).width() - e.pageX < 15
                    shouldClose = $(window).width() - e.pageX < 70
                    if shouldOpen and not @isOpen
                        @scrollBarHolder.animate
                            right: 0
                        @isOpen = true
                    if not shouldClose and @isOpen
                        @isOpen = false
                        @scrollBarHolder.animate
                            right: "-38px"
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

            @scrollBtn.on "click", => @destroy()

    class VideoViewer

        constructor: (video, { controls, timeupdate, infoHolder, sliderHolder }) ->
            tpl = require "./slider.jade"
            @el = $ tpl()
            @seekHandle = @el.find ".fp-seek-handle"
            @videoProgress = @el.find ".fp-video-progress"
            @isSeeking = false
            @video = $ video
            @host = getHost()
            if controls
                $("<div></div>").addClass("player").insertBefore(@video).append(@video)
                plyr.setup()
                @video.closest(".player").find(".player-progress").empty().append @el
            else if sliderHolder
                setTimeout =>
                    @el.appendTo $ sliderHolder
                    if sliderHolder
                        @el.find(".fp-btn_close").remove()
                        @el.find(".fp-info-holder").appendTo $ infoHolder
                , 100
            else
                @el.insertBefore @video
            setTimeout =>
                @refreshSize()
                @heatmap = new LinearHeatmap @el
                @getData()
                .done (response) =>
                    @el.find(".fp-scale-from").text 1
                    if @data
                        @heatmap.setData @data
                            .setMaxValue response.result?.maxValue
                            .draw()
                    @el.find(".fp-scale-to").text Math.round @heatmap.max
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
                width: @el.parent().width()
                opacity: 1

        destroy: -> @el.remove()

        onTimeUpdate: (fn) ->
            if @timeupdate
                @el.on "timeupdate", fn
            else
                setInterval fn, 500

        initEvents: ->
            @onTimeUpdate =>
                return if @isSeeking

                { duration, currentTime } = @video.get 0
                progressWidth = currentTime / duration
                progressWidth = Math.round(progressWidth * (@el.width() - 4))
                @seekHandle.css "left", progressWidth + "px"
                @videoProgress.css "width", progressWidth + "px"

            @el.on "click", (e) =>
                video = @video.get 0
                point = (e.pageX - @el.offset().left) / @el.width()
                if video.duration
                    video.currentTime = video.duration * point

            @el.find(".fp-btn_close").on "click", =>
                @el.find(".fp-info-holder").remove()
                @el.find("canvas").remove()
                false

            @seekHandle.on "mousedown", (e) =>
                @isSeeking = true
                { clientX, clientY } = e
                elOffset = @el.offset()
                { left } = @seekHandle.offset()
                @seekHandle.addClass "active"
                $(window).on "mousemove", (e) =>
                    maxLeft = @el.width() - 4
                    newLeft = e.clientX - clientX + left - elOffset.left + 6
                    newLeft = 0 if newLeft < 0
                    newLeft = maxLeft if newLeft > maxLeft
                    @seekHandle.css "left", newLeft + "px"
                    @videoProgress.css "width", newLeft + "px"

                $(window).on "mouseup", (e) =>
                    $(window).off "mousemove"
                    $(window).off "mouseup"
                    @isSeeking = false
                    video = @video.get 0
                    @seekHandle.removeClass "active"
                    width = @el.width() - 4
                    console.log [@seekHandle.offset().left, @el.offset().left, width]
                    point = (@seekHandle.offset().left - @el.offset().left) / width
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
            @max = 4
            @colorPalette = @buildColorPalette()

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
            return unless @data
            @clear()
            heatmapLength = Math.max @width, @height
            if @isLandscape
                grd = @ctx.createLinearGradient 0, 0, heatmapLength, 0
            else
                grd = @ctx.createLinearGradient 0, 0, 0, heatmapLength

            for value, index in @data
                grd.addColorStop index / 100, "rgba(0,0,0,#{(value/@max).toFixed 2})"

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
            @key = @createKey()
            @initEvents()

        createKey: -> Date.now() - Math.floor(Math.random() * 1000)

        initEvents: -> $(window).on "unload", => @sendData()

        getDocHeight: ->
            d = document
            Math.max d.body.scrollHeight, d.documentElement.scrollHeight,
                d.body.offsetHeight, d.documentElement.offsetHeight,
                d.body.clientHeight, d.documentElement.clientHeight

        sendData: ->
            $.post @host + "/save",
                data: @data
                type: @type
                key: @key
            .done => @data = []

    class HtmlObserver extends GenericObserver

        constructor: (el = body, type) ->
            @el = $ el
            @active = true
            @visible = true
            super type

        initEvents: ->
            setInterval =>
                @saveState() if @active and @visible
            , 3000
            setInterval =>
                if @data.length > 0
                    @sendData()
            , 10000

            $(document).idle
                onIdle: => @active = true
                onActive: => @active = false
                onHide: => @visible = false
                onShow: => @visible = true
                idle: 10000 # 10s
            super()

        saveState: ->
            contentHeight = @el.get(0).scrollHeight or @getDocHeight()
            p = @getCurrViewportPosition()
            @data.push
                value: 0.3
                a: p.top / contentHeight
                b: p.bottom / contentHeight

        getCurrViewportPosition: ->
            top = @el.scrollTop()
            bottom = @el.height() + top
            { top, bottom }

    class VideoObserver extends GenericObserver

        constructor: (el, @timeupdate = true) ->
            @el = $ el
            super "video"

        onTimeUpdate: (fn) ->
            if @timeupdate
                @el.on "timeupdate", fn
            else
                setInterval fn, 500

        initEvents: ->
            video = @el.get 0
            start = curr = prev = 0

            @onTimeUpdate =>
                prev = curr
                curr = video.currentTime
                if Math.abs(curr - prev) > 1
                    @saveState start, prev
                    start = curr

            $(window).on "unload", =>
                @saveState start, curr

        saveState: (start, end) ->
            video = @el.get 0
            value = 1
            a = (start / video.duration).toFixed 3
            b = (end / video.duration).toFixed 3
            if +a >= 0 and +b >= 0
                @data.push { a, b, value }
                @sendData()

        sendData: ->
            { currentSrc } = @el.get 0
            $.post @host + "/save",
                videoSrc: currentSrc
                type: @type
                data: @data
                key: @key
            .done => @data = []

    window.Footprint = (options = {}) ->

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
                $container.each (i, video) ->
                    if options.timeupdate isnt false
                        options.timeupdate = true
                    new VideoViewer video, options
                    new VideoObserver video, options.timeupdate

        $ -> typeMap[options.type or "html"]?()
