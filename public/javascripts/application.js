$(document).ready(function() {
  $('ul.sf-menu').superfish();
  $('.auth-provider').click(function(){
      var authUrl = $(this).attr('href');
      $.cookie('pp', '1'); //set cookie popup to 1
      window.open(authUrl, 'openid_popup', 'width=790,height=580');
      return false;
  })
  init_geolocal();
  $("form.nestedAnswerForm").hide();
  $("#add_comment_form").hide();
  $("form").live('submit', function() {
    var textarea = $(this).find('textarea');
    removeFromLocalStorage(location.href, textarea.attr('id'));
    window.onbeforeunload = null;
  });

  $('.confirm-domain').submit(function(){
      var bool = confirm($(this).attr('data-confirm'));
      if(bool==false) return false;

  })
  $("#feedbackform").dialog({ title: "Feedback", autoOpen: false, modal: true, width:"420px" })
  $('#feedbackform .cancel-feedback').click(function(){
    $("#feedbackform").dialog('close');
    return false;
  })
  $('#feedback').click(function(){
    var isOpen = $("#feedbackform").dialog('isOpen');
    if (isOpen){
      $("#feedbackform").dialog('close');
    } else {
      $("#feedbackform").dialog('open');
    }
    return false;
  })

  $('.autocomplete_for_tags').ricodigoComplete();
  $('#quick_question').find('.tagwrapper').css({'margin-left':'18px',width:'68%'});
  if(supports_input_placeholder()){$('.hideifplaceholder').remove();};
  $(".quick-vote-button").live("click", function(event) {
    var btn = $(this);
    btn.hide();
    var src = btn.attr('src');
    if (src.indexOf('/images/dialog-ok.png') == 0){
      var btn_name = $(this).attr("name")
      var form = $(this).parents("form");
      $.post(form.attr("action"), form.serialize()+"&"+btn_name+"=1", function(data){
        if(data.success){
          btn.parents('.item').find('.votes .counter').text(data.average);
          btn.attr('src', '/images/dialog-ok-apply.png');
          showMessage(data.message, "notice")
        } else {
          showMessage(data.message, "error")
          if(data.status == "unauthenticate") {
            window.onbeforeunload = null;
            window.location="/users/login"
          }
        }
        btn.show();
      }, "json");
    }
    return false;
  });

  $("a#hide_announcement").click(function() {
    $("#announcement").fadeOut();
    $.post($(this).attr("href"), "format=js");
    return false;
  });

  $('textarea').live('keyup',function(){
      var value = $(this).val();
      var id = $(this).attr('id');
      addToLocalStorage(location.href, id, value);
  })

  initStorageMethods();
  fillTextareas();
  initFollowTags();
  $(".highlight_for_user").effect("highlight", {}, 2000);
  sortValues('#group_language', 'option', ':last', 'text', null);
  sortValues('#language_filter', 'option',  ':lt(2)', 'text', null);
  sortValues('#user_language', 'option',  false, 'text', null);
  sortValues('#lang_opts', '.radio_option', false, 'attr', 'id');
  sortValues('#question_language', 'option', false, 'text', null);

  $('.langbox.jshide').hide();
  $('.show-more-lang').click(function(){
      $('.langbox.jshide').toggle();
      return false;
  })
})

function manageAjaxError(XMLHttpRequest, textStatus, errorThrown) {
  showMessage("sorry, something went wrong.", "error");
}

function showMessage(message, t, delay) {
  $("#notifyBar").remove();
  $.notifyBar({
    html: "<div class='message "+t+"' style='width: 100%; height: 100%; padding: 5px'>"+message+"</div>",
    delay: delay||3000,
    animationSpeed: "normal",
    barClass: "flash"
  });
}

function hasStorage(){
  if (window.localStorage && typeof(Storage)!='undefined'){
    return true;
  } else {
      return false;
  }
}

function initStorageMethods(){
  if(hasStorage()){
    Storage.prototype.setObject = function(key, value) {
        this.setItem(key, JSON.stringify(value));
    }

    Storage.prototype.getObject = function(key) {
        return JSON.parse(this.getItem(key));
    }
  }
}

function fillTextareas(){
   if(hasStorage() && localStorage[location.href]!=null && localStorage[location.href]!='null'){
       localStorageArr = localStorage.getObject(location.href);
       $.each(localStorageArr, function(i, n){
           $("#"+n.id).val(n.value);
           $("#"+n.id).parents('form.commentForm').show();
           $("#"+n.id).parents('form.nestedAnswerForm').show();
       })
    }
}

function addToLocalStorage(key, id, value){
  if(hasStorage()){
    var ls = localStorage[key];
    if($.trim(value)!=""){
      if(ls == null || ls == "null" || typeof(ls)=="undefined"){
          localStorage.setObject(key,[{id: id, value: value}]);
      } else {
          var storageArr = localStorage.getObject(key);
          var isIn = false;
          storageArr = $.map(storageArr, function(n, i){
              if(n.id == id){
                n.value = value;
                isIn = true;
              }
          return n;
        })
      if(!isIn)
        storageArr = $.merge(storageArr, [{id: id, value: value}]);
      localStorage.setObject(key, storageArr);
    }
    } else {removeFromLocalStorage(key, id);}
  }
}

function removeFromLocalStorage(key, id){
  if(hasStorage()){
    var ls = localStorage[key];
    if(typeof(ls)=='string'){
      var storageArr = localStorage.getObject(key);

      storageArr = $.map(storageArr, function(n, i){
          if(n.id == id){
            return null;
          } else {
              return n;
          }
      })
      localStorage.setObject(key, storageArr);
    }
  }
}


function sortValues(selectID, child, keepers, method, arg){
  if(keepers){
    var any = $(selectID+' '+child+keepers);
    any.remove();
  }
  var sortedVals = $.makeArray($(selectID+' '+child)).sort(function(a,b){
    return $(a)[method](arg) > $(b)[method](arg) ? 1: -1;
  });
  $(selectID).html(sortedVals);
  if(keepers)
    $(selectID).prepend(any);
  // needed for firefox:
  $(selectID).val($(selectID+' '+child+'[selected=selected]').val());
};

function highlightEffect(object) {
  if(typeof object != "undefined") {
    object.fadeOut(400, function() {
      object.fadeIn(400)
    });
  }
}


function supports_input_placeholder() {
  var i = document.createElement('input');
  return 'placeholder' in i;
}

function init_geolocal(){
  if (navigator.geolocation) {
    $('textarea, #question_title').live('focus', function(){
      navigator.geolocation.getCurrentPosition(function(position){
          $('.lat_input').val(position.coords.latitude)
          $('.long_input').val(position.coords.longitude)
      }, function(){});
    });
  } else {
      //error('not supported');
  }
}

function initFollowTags(){
  console.log('beep')
  $(".follow-tag, .unfollow-tag").live("click", function(event) {
    var link = $(this);
    if(!link.hasClass('busy')){
      link.addClass('busy');
      var href = link.attr("href");
      var title = link.text();
      var dataTitle = link.attr("data-title");
      var dataUndo = link.attr("data-undo");
      var linkClass = link.attr('class');
      var dataClass = link.attr('data-class');
      var tag = link.attr('data-tag');
      $.ajax({
        url: href+'.js',
        dataType: 'json',
        type: "POST",
        data: "tags="+tag,
        success: function(data){
          if(data.success){
            link.attr({href: dataUndo, 'data-undo': href, 'data-title': title, 'class': dataClass, 'data-class': linkClass });
            showMessage(data.message, "notice");
          } else {
            showMessage(data.message, "error");

            if(data.status == "unauthenticate") {
                window.location="/users/login";
            }
        }
        },
        error: manageAjaxError,
        complete: function(XMLHttpRequest, textStatus) {
            link.removeClass('busy');
            link.text(dataTitle);
        }
        })
    }
    return false;
  })
}

// Script for HTML5 tags, so IE will see it and use it
document.createElement('header');
document.createElement('footer');
document.createElement('section');
document.createElement('aside');
document.createElement('nav');
document.createElement('article');
document.createElement('hgroup');





