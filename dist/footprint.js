$(function() {
  var $body, $scroll, $scrollBar, $scrollBarHolder, data, extendedData, heatmap;
  $body = $("body");
  $scrollBarHolder = $(".scrollbar-holder");
  $scrollBar = $(".scrollbar");
  $scroll = $(".scroll");
  heatmap = h337.create({
    container: $scrollBar.get(0)
  });
  data = [
    {
      y: 120,
      value: 1
    }, {
      y: 170,
      value: 3
    }, {
      y: 210,
      value: 2
    }, {
      y: 270,
      value: 3
    }, {
      y: 320,
      value: 1
    }, {
      y: 350,
      value: 3
    }, {
      y: 550,
      value: 5
    }
  ];
  extendedData = [];
  _.each(data, function(item) {
    var x, xVals;
    xVals = (function() {
      var _i, _results;
      _results = [];
      for (x = _i = -20; _i <= 300; x = _i += 10) {
        _results.push(x);
      }
      return _results;
    })();
    return _.each(xVals, function(x) {
      var newItem;
      newItem = _.clone(item);
      newItem.x = x;
      return extendedData.push(newItem);
    });
  });
  heatmap.setData({
    max: 5,
    data: extendedData
  });
  $scroll.height(96 * $(window).height() / $body.height() + "%");
  return $(window).scroll(function(e) {
    return $scroll.css({
      top: 100 * e.originalEvent.pageY / $body.height() + "%"
    });
  });
});
