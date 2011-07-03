Modernizr.load([{
  load: '//ajax.googleapis.com/ajax/libs/jquery/1.6.1/jquery.min.js',
  callback: function() {
    if (!window.jQuery) {
      Modernizr.load('/javascripts/vendor/jquery.js');
    }
  },
  complete: function() {
    Modernizr.load([{
      test: window.JSON,
      nope: jsassets.json
    }, {
      test: navigator.geolocation,
      nope: jsassets.geolocation
    }, {
      load: jsassets.base,
      complete: function(){
        Jqmath.initialize();
      }
    }, {
      load: $.merge(jsassets.jqueryui, cssassets.jqueryui),
      complete: function() {
        var fields = $('.lang-fields');
        if(fields.length > 0){
          fields.tabs();
        }
        if(typeof Effects !== 'undefined'){
          Effects.initialize();
        }
      }
    }])
   $(document).ready(function() {
     Modernizr.load([{
      test: ($('.offline').length == 0 || (location.pathname != '/' && location.pathname.indexOf('/questions' != 0))),
      yep: jsassets.extra
    }, {
      test: Modernizr.websockets,
      nope: jsassets.websocket,
      complete: function() {
        ShapadoSocket.initialize();
        }
    },{
      test: $('meta[data-js=show]').length > 0 && $('.auto-link').length > 0,
      yep: jsassets.jqueryautovideo,
      complete: function(){
        if($.fn.autoVideo)
          $('.auto-link').autoVideo();
      }
    }, {
      test: $('.autocomplete_for_tags').length > 0,
      yep: jsassets.jqautocomplete,
      callback: function() {
        $('.autocomplete_for_tags').ricodigoComplete();
      }
    },{
       test: $("input[type=color]").length>0,
       yep: jsassets.jpicker,
       complete: function(){
        if($.jPicker)
          Form.initialize();
       }
       }, {
          test: $("input[type=color]").length>0,
          yep: cssassets.jpicker
     }])
   })
  }
}]);