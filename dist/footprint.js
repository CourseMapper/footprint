var LinearHeatmap, Observer;

$(function() {
  var $body, $scroll, $scrollBar, $scrollBarHolder, body, extendedData, heatmap, html, isOpen, pageHeight, windowHeight, windowWidth;
  $body = $("body");
  $scrollBarHolder = $(".scrollbar-holder");
  $scrollBar = $(".scrollbar");
  $scroll = $(".scroll");
  heatmap = h337.create({
    container: $scrollBar.get(0)
  });
  body = document.body;
  html = document.documentElement;
  pageHeight = Math.max(body.scrollHeight, body.offsetHeight, html.clientHeight, html.scrollHeight, html.offsetHeight);
  windowHeight = $(window).height();
  extendedData = [];
  $.get("http://localhost:3000/get", function(response) {
    var data, points;
    points = _.first(response.result);
    if (points) {
      data = [];
      _.each(points.data, function(item) {
        var a, b;
        a = item.a * windowHeight;
        b = item.b * windowHeight;
        return data = data.concat(_.map(_.range(a, b, 20), function(y) {
          return {
            value: 1,
            y: y
          };
        }));
      });
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
      return heatmap.setData({
        max: 5,
        data: extendedData
      });
    }
  });
  console.log($(window).height());
  $scroll.height(Math.floor(Math.pow($(window).height(), 2) / pageHeight) - 16 + "px");
  $(window).scroll(function(e) {
    return $scroll.css({
      top: 100 * e.originalEvent.pageY / $body.height() + "%"
    });
  });
  windowWidth = $(window).width();
  isOpen = false;
  $(window).on("mousemove", function(e) {
    var isMouseClose;
    isMouseClose = windowWidth - e.pageX < 150;
    if (isMouseClose && !isOpen) {
      console.log("open");
      $scrollBarHolder.animate({
        right: 0
      });
      isOpen = true;
    }
    if (!isMouseClose && isOpen) {
      console.log("close");
      isOpen = false;
      return $scrollBarHolder.animate({
        right: "-118px"
      });
    }
  });
  console.log($(".content"));
  return $(".content").annotator();
});

LinearHeatmap = (function() {
  function LinearHeatmap(canvas) {
    canvas = $(canvas).get(0);
    this.ctx = canvas.getContext("2d");
    this.width = canvas.width, this.height = canvas.height;
    this.data = [];
    this.max = 1;
  }

  LinearHeatmap.prototype.defaultGradient = {
    0.4: "blue",
    0.6: "cyan",
    0.7: "lime",
    0.8: "yellow",
    1.0: "red"
  };

  LinearHeatmap.prototype.draw = function() {
    this.ctx.clearRect(0, 0, this.width, this.height);
    return _.each(data, function(_arg) {
      var a, b, value;
      a = _arg[0], b = _arg[1], value = _arg[2];
    });
  };

  return LinearHeatmap;

})();

Observer = (function() {
  function Observer() {
    var body, html;
    body = document.body;
    html = document.documentElement;
    this.pageHeight = Math.max(body.scrollHeight, body.offsetHeight, html.clientHeight, html.scrollHeight, html.offsetHeight);
    this.initEvents();
  }

  Observer.prototype.data = [];

  Observer.prototype.initEvents = function() {
    this.tock = new Tock({
      interval: 1000,
      callback: this.saveScrollPosition.bind(this)
    }).start();
    return $(window).on("unload", (function(_this) {
      return function() {
        return _this.sendData();
      };
    })(this));
  };

  Observer.prototype.saveScrollPosition = function() {
    var p;
    p = this.getCurrViewportPosition();
    return this.data.push({
      value: 1,
      a: p.top / this.pageHeight,
      b: p.bottom / this.pageHeight
    });
  };

  Observer.prototype.getCurrViewportPosition = function() {
    var bottom, top;
    top = window.pageYOffset;
    bottom = top + $(window).height();
    return {
      top: top,
      bottom: bottom
    };
  };

  Observer.prototype.sendData = function() {
    return $.post("http://localhost:3000/save", {
      type: "html",
      data: this.data
    });
  };

  return Observer;

})();

$(function() {
  return new Observer;
});
