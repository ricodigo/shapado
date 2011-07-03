var LayoutEditor = {
  initialize: function() {
    if(window.location.search.match(/edit_layout=1/)) {
      LayoutEditor.start();
    }
  },
  start: function() {
    LayoutEditor.sortable = $("#columns").sortable({
      connectWith: '#columns',
      stop: LayoutEditor.dropHandler
    });
  },
  stop: function() {
  },
  dropHandler: function(ev, ui) {
    var cols = [];
    $.each($("#columns").children("section"), function() {
      cols.push("columns[]="+$(this).attr("id"));
    });

    $.ajax({
      url: '/groups/'+AppConfig.g+'/set_columns.js',
      data: cols.join("&"),
      dataType: 'json',
      type: "POST",
      success: function(data) {
      }
    });
  }
};
