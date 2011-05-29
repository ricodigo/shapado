
$(document).ready(function() {
  $("label#rqlabel").hide();

  $(".text_field#question_title").focus( function() {
    highlightEffect($("#sidebar .help"));
  });

  $("#related_questions").hide();

  $(".ask_question #ask_question").searcher({url : "/questions/related_questions.js",
                              target : $("#related_questions"),
                              fields : $("form#ask_question input[type=text][name*=question]"),
                              behaviour : "focusout",
                              timeout : 2500,
                              extraParams : { 'format' : 'js',
                                              'per_page' : 5,
                                              mini: true
                              },
                              before_query: function(target) {
                                target.show();
                              },
                              success: function(data) {
                                if(!data.html) {
                                  $("#related_questions").hide();
                                  // TODO: show a message
                                }
                                $("label#rqlabel").show();
                              }
  });

  $("#ask_question").bind("keypress", function(e) {
    if (e.keyCode == 13) {
       return false;
     }
  });

  var fields = $("#attachments #fields");
  var template = fields.find(".template");
  template.find("input").attr("name", "question[attachments[id]]");
  template.hide();

  $("#attachments #fields .attachment_field .remove_attachment").live("click", function(e) {
    $(this).parent().remove();
    return false;
  });

  $(".remove_attachment_link").live("click", function(e) {
    var url = $(this).attr("href");
    var remove = confirm("are you sure?"); //TODO; i18n
    if (remove) {
      $.ajax({url: url, dataType: 'json', context: $(this), success: function(data, textStatus, XMLHttpRequest){
        $(this).parent().remove();
      }});
    }
    return false;
  });

  var count = -1;
  $("#attachments .add_attachment").live("click", function(e) {
    var template = fields.find(".template");
    var new_field = template.clone();
    new_field.removeClass("template");
    count++;
    var new_name = new_field.find("input").attr("name").replace(/(id)/, count);
    new_field.find("input").attr("name",new_name)

    new_field.show();

    fields.append(new_field);

    return false;
  });


});
