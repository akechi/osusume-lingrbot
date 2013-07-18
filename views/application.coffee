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
          $(e.target).parents('tr').removeClass('enable')
          $(e.target).parents('tr').addClass('disable')
          $('#' + id).val('Enable')
        else
          $(e.target).parents('tr').removeClass('disable')
          $(e.target).parents('tr').addClass('enable')
          $('#' + id).val('Disable')
  # TODO: DRY
  $('.enable-filter').click (e) ->
    if $(self).attr('data-hide') == 0
      $('tr.enable').addClass('hide')
      $(self).attr('data-hide', 1)
    else
      $('tr.enable').removeClass('hide')
      $(self).attr('data-hide', 0)
  $('.disable-filter').click (e) ->
    if $(self).attr('data-hide') == 0
      $('tr.disable').addClass('hide')
      $(self).attr('data-hide', 1)
    else
      $('tr.disable').removeClass('hide')
      $(self).attr('data-hide', 0)


