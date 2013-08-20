$ ->
  $('.content').each (i, e) ->
    text = $(e).text().replace /\bhttps?:\/\/\S+(?:jpg|png|gif|JPG|PNG|GIF)(\b|\?\S+|$)/, (match) ->
      '<img class="osusume-image" src="' + match.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", '&apos;') + '">'
    $(e).html(text.replace(/\n/g, '<br/>'))
  $('input.manage').click (e) ->
    id = $(e.target).attr('id')
    node = document.getElementById(id)
    enable = $(node).val() == 'Enable'
    $.ajax '/osusume/manage',
      type: 'POST'
      data: {'name': id, 'enable': enable},
      error: (jqXHR, textStatus, errorThrown) ->
        alert "AJAX Error: #{textStatus}"
      success: (data, textStatus, jqXHR) ->
        if !enable
          $(e.target).parents('tr').removeClass('enable')
          $(e.target).parents('tr').addClass('disable')
          $(node).val('Enable')
        else
          $(e.target).parents('tr').removeClass('disable')
          $(e.target).parents('tr').addClass('enable')
          $(node).val('Disable')
  # TODO: DRY
  $('.enable-filter').click (e) ->
    if $(this).attr('data-hide') == 'show'
      $('tr.enable').addClass('hide')
      $(this).attr('data-hide', 'hide')
    else
      $('tr.enable').removeClass('hide')
      $(this).attr('data-hide', 'show')
  $('.disable-filter').click (e) ->
    if $(this).attr('data-hide') == 'show'
      $('tr.disable').addClass('hide')
      $(this).attr('data-hide', 'hide')
    else
      $('tr.disable').removeClass('hide')
      $(this).attr('data-hide', 'show')


