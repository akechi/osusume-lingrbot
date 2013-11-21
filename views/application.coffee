$ ->
  $('.content').each (i, e) ->
    text = $(e).text().replace /\bhttps?:\/\/\S+(?:jpg|png|gif|JPG|PNG|GIF)(\?[^< \t\r\n]+|$)/, (match) ->
      '<img class="osusume-image thumbnail lazy" src="./img/dummy.jpg" data-original="' + match.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", '&apos;') + '">'
    $(e).html(text.replace(/\n/g, '<br/>'))
  $('.lazy').lazyload({
    effect: 'fadeIn',
    effectspeed: 500
  })
  $('button.manage').click ->
    clicked = $(this)
    enable = clicked.text() == 'Enable'
    $.ajax '/manage',
      type: 'POST'
      data: {'name': clicked.attr('id'), 'enable': enable},
      error: (jqXHR, textStatus, errorThrown) ->
        alert "AJAX Error: #{textStatus}"
      success: (data, textStatus, jqXHR) ->
        tr = clicked.parents('td').parents('tr')
        if !enable
          tr.removeClass('enable')
          tr.addClass('disable')
          clicked.text('Enable')
        else
          tr.removeClass('disable')
          tr.addClass('enable')
          clicked.text('Disable')
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


