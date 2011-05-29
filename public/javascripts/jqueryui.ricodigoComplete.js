(function($) {
  $.fn.ricodigoComplete = function(opts){
    this.each(function(){
            function addTag(tag, input, code){
              if(code) {hiddenTag = code;} else {hiddenTag=tag;}
              var tag = $.trim(tag.replace(',',''));
              if(!input.parent().find('.added-tag[data-caption="'+hiddenTag+'"]').length){
                input.val('');
                input.removeAttr('data-init')
                var tag =  $('<ul style="margin-left:4px;margin-right:4px;margin-top:6px;" class="ui-menu ui-widget ui-widget-content ui-corner-all" role="listbox" aria-activedescendant="ui-active-menuitem"><li class="ui-menu-item" role="menuitem"><a class="ui-corner-all added-tag" tabindex="-1" id="ui-active-menuitem" data-caption="'+hiddenTag+'">'+tag+'&nbsp;<span style="font-weight:bold;cursor:pointer;" class="remove-tag">x</span></a></li></ul>');
                input.before(tag);
                input.css({width: '30px'});
                input.attr({placeholder: ''});
                var tags = [];
                input.parent().find('.added-tag').map(function(){tags.push($(this).attr('data-caption'))})
                input.parent().next('.ac-tags').val(tags.join(','));
                input.focus();
              }
            }
      $(".remove-tag").live('click',function(){$(this).parents('ul:first').remove();})
      $(".added-tag").live('mouseenter',function(){$(this).addClass('ui-state-hover')})
      $(".added-tag").live('mouseleave',function(){$(this).removeClass('ui-state-hover')})
      tagInput = $(this);
      tagInput.addClass('ui-menu');
      tagInput.attr({'data-init': '1'})
      var name = tagInput.attr('name');
      tagInput.attr('name','tag_input');
      tagInput.after('<input type="hidden" class="ac-tags" name="'+name+'">');
      var tagwrapper=$('<div class="tagwrapper" style="background:#FFF;"></div>');
      tagwrapper.css({border: '2px solid #CCCCCC', width: '99%'});
      tagwrapper.css('float', 'left');
      tagwrapper.css('min-height', '40px');
      tagwrapper.css('margin-top', '0px');

      dataOpts = tagInput.attr('data-opts');
      if(dataOpts){opts = $.evalJSON(dataOpts)}else{opts={allowNewTags: true}};

      tagInput.wrap(tagwrapper);
      var tagwrapper = tagInput.parent('.tagwrapper');
      tagwrapper.click(function (){tagwrapper.children('.autocomplete_for_tags').focus();});
      tagInput.css({outline: 'none', border: 0, padding: '10px', width: '90%'});
      tagInput.keydown(function(event){
        var key = event.keyCode;
        var tag = $(this).prev('ul');
        var tagLink = tag.find('a')
        if($(this).val()==',') //empty the field it if it has a comma
          $(this).val('');
        if(key==8 && $(this).val()==''){
          if(tagLink.hasClass('ui-state-hover')){
            $(this).prev('ul').remove();
            $(this).width(30);
            $(this).removeAttr('data-init');
            var tags = [];
            $(this).parent().find('.added-tag').map(function(){tags.push($(this).attr('data-caption'))})
            $(this).parent().next('.ac-tags').val(tags.join(','));
            $(this).autocomplete( "close" );
          } else {
              tagLink.addClass('ui-state-hover');
          }
        } else if(key == 8 && $(this).val()!=''){
          tagLink.removeClass('ui-state-hover');
          if($(this).width()>38 && !$(this).attr('data-init'))
            $(this).width($(this).width()-7);
        } else if (opts.allowNewTags && (key == 9 || key == 32 || key == 188 || key == 13) && $.trim($(this).val().replace(',','')) != '') {
            tagLink.removeClass('ui-state-hover');
            addTag($(this).val(), $(this));
            $(this).focus();
            $(this).autocomplete( "close" );
            return false;
        } else {
            if(!$(this).attr('data-init'))
              $(this).width($(this).width()+9);
        }
      });
      var ac = $(this);
      var tags = $(this).val();
      if(tags!=''){
        tags = tags.split(',')
        $.each(tags,function(i, tag){
          if(tag.indexOf(':')!=-1){
            addTag(tag.split(':')[0], ac, tag.split(':')[1]);
          } else {
              addTag(tag, ac);
          }
        })
        $(this).val('');
      }
      var cache = {},
                  lastXhr;
      tagInput.autocomplete({
        autoFocus: true,
        select: function(event, ui) {
          addTag(ui.item.label, $(this), ui.item.code)
          return false;
        },
        minLength: 1,
        source:  (opts.source)?  opts.source : function( request, response ) {
          //if(!opts.source){
          var term = request.term;
          if( $.trim(term.replace(',','')) == '' )
            return;
          if ( term in cache ) {
            response( cache[ term ] );
            return;
          }
          lastXhr = $.getJSON( "/questions/tags_for_autocomplete.js", request, function( data, status, xhr ) {
            cache[ term ] = data;
            $.merge([{label:term.replace(',',''),caption:term.replace(',','')}],data);
            if ( xhr === lastXhr ) {
              response( data );
            }
          });/*} else {
            opts.source
              }*/
        }
      }).data( "autocomplete" )._renderItem = function( ul, item ) {
          return $( '<li></li>' )
              .data( "item.autocomplete", item )
              .append( "<a>" + item.caption + "</a>" )
              .appendTo( ul );
      };
    })
  }
})(jQuery);