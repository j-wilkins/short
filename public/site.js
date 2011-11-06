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
