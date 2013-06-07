$ ->
  $('.content').each (i, e) ->
    text = $(e).text().replace /\bhttps?:\/\/\S+(?:jpg|png|gif|JPG|PNG|GIF)(\s.*|\?\S+)?$/, (match) ->
      '<img class="osusume-image" src="' + match.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;').replace('"', '&quot;').replace("'", '&apos;') + '">'
    $(e).html(text.replace(/\n/g, '<br/>'))
  $('input.delete').click (e) ->
    id = $(e.target).attr('id')
    $(e.target).parents("tr").slideUp()
    $.ajax '/osusume/delete',
      type: 'POST'
      data: {"name": id},
      error: (jqXHR, textStatus, errorThrown) ->
        alert "AJAX Error: #{textStatus}"
      success: (data, textStatus, jqXHR) ->
        $(e.target).parents("tr").fadeOut('slow')
