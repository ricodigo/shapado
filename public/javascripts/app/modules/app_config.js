var AppConfig = {
  initialize: function() {
    var config = $("#appconfig");

    $.each(config[0].attributes, function() {
      var att = this;
      var m = att.name.match("^data-(.+)");
      if(m && m[1]) {
        AppConfig[m[1]] = att.value;
      }
    });
  }
};
