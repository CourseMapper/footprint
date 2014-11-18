$ ->
    $body = $ "body"
    $scrollBarHolder = $ ".scrollbar-holder"
    $scrollBar = $ ".scrollbar"
    $scroll = $ ".scroll"
    heatmap = h337.create
        container: $scrollBar.get 0

    data = [
        {y: 120, value: 1}
        {y: 170, value: 3}
        {y: 210, value: 2}
        {y: 270, value: 3}
        {y: 320, value: 1}
        {y: 350, value: 3}
        {y: 550, value: 5}
    ]

    extendedData = []
    _.each data, (item) ->
        xVals = (x for x in [-20..300] by 10)
        _.each xVals, (x) ->
            newItem = _.clone item
            newItem.x = x
            extendedData.push newItem

    heatmap.setData
        max: 5
        data: extendedData

    $scroll.height 96 * $(window).height() / $body.height() + "%"

    $(window).scroll (e) ->
        $scroll.css top: 100*  e.originalEvent.pageY / $body.height() + "%"
