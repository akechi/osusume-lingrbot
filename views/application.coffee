$ ->
  $('.content').each (i, e) ->
    text = $(e).text().replace /\bhttps?:\/\/\S+(?:jpg|png|gif|JPG|PNG|GIF)(\b|\?\S+|$)/, (match) ->
      '<img class="osusume-image" src="' + match.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", '&apos;') + '">'
    $(e).html(text.replace(/\n/g, '<br/>'))
  $('input.manage').click (e) ->
    id = $(e.target).attr('id')
    enable = $('#' + id).val() == 'Enable'
    $.ajax '/osusume/manage',
      type: 'POST'
      data: {'name': id, 'enable': enable},
      error: (jqXHR, textStatus, errorThrown) ->
        alert "AJAX Error: #{textStatus}"
      success: (data, textStatus, jqXHR) ->
        if !enable
          $(e.target).parents('tr').addClass('disable')
          $('#' + id).val('Enable')
        else
          $(e.target).parents('tr').removeClass('disable')
          $('#' + id).val('Disable')
