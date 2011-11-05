$(function(){

  /* pretty much yoinked exactly from jQuery site */
  $("#add-form").submit(function(event) {

    /* stop form from submitting normally */
    event.preventDefault();

    /* get some values from elements on the page: */
    var $form = $( this ),
        term = $form.find( 'input[name="shortener[url]"]' ).val(),
        url = $form.attr( 'action' );

    /* Send the data using post and put the results in a div */
    $.post( url + '.json', { shortener: {url: term} },
      function( data ) {
        $( "#main" ).append( data );
      }
    );

  });
});
