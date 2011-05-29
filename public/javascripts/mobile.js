$(document).ready(function() {
  $.mobile.page.prototype.options.addBackBtn = true;

  $('div[data-role*="page"]').live('pageshow',function(event, ui){
    var internal = $("a").filter(function() {
      return (this.hostname == location.hostname && !this.href.match("mobile"));
    });

    $.each(internal, function() {
      var link = $(this);
      var href = link.attr("href");

      if(href.match('\\?')) {
        link.attr("href", href+"&format=mobile");
      } else {
        link.attr("href", href+"?format=mobile");
      }
    });
  });
});
