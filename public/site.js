$(function(){

  /* pretty much yoinked exactly from jQuery site */
  $("#add-form").submit(function(event) {

    /* stop form from submitting normally */
    event.preventDefault();

    /* get some values from elements on the page: */
    var $form = $( this ),
        fUrl = $form.find( 'input[name="shortener[url]"]' ).val(),
        fMaxClick = $form.find( 'input[name="shortener[max-clicks]"]' ).val(),
        fExpire = $form.find( 'input[name="shortener[expire]"]' ).val(),
        fDesiredShort = $form.find( 'input[name="shortener[desired-short]"]' ).val(),
        fAllowOverride = $form.find( 'input[name="shortener[allow-override]"]' ).is(':checked'),
        url = $form.attr( 'action' );

    /* Send the data using post and put the results in a div */
    $.post( url + '.json', 
      { shortener: {url: fUrl, 'max-clicks': fMaxClick, expire: fExpire, 
       'desired-short': fDesiredShort, 'allow-override': fAllowOverride} },
      function( data ) {
        $( "#main" ).append( data );
      }
    );

  });

  $('.delete-button').click(function(event){
    event.preventDefault();
    var btn = $(this);
    $.get(this.href + '.json', function(data){
      if (data.success === true) {
        // fadeOut on a tr doesn't work, but on td it does.
        btn.parent().parent('tr').find('td').fadeOut();
        // we don't explicitly need to do this, because next time the page
        // loads it won't be there. plus, it breaks our fadeout
        //btn.parent().parent('tr').remove();
      }
    });
  });
});
