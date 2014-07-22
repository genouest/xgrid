$(document).ready(function() {
 
    // select ref when rel attribute is tooltip
    $('a[rel=tooltip]').mouseover(function(e) {
 
        var tip = $(this).attr('title');   
        $(this).attr('title','');
 
        // insert the tooltip inside the page
        $(this).append('<div id="tooltip"><div class="tipBody">' + tip + '</div></div>');    
 
        // tooltip coordinates
        $('#tooltip').css('top', e.pageY + 10 );
        $('#tooltip').css('left', e.pageX + 20 );
 
        // fadeIn effect
        $('#tooltip').fadeIn('500');
        $('#tooltip').fadeTo('10',0.8);
 
    }).mousemove(function(e) {
 
        // ajust tooltip with mouse moves
        $('#tooltip').css('top', e.pageY + 10 );
        $('#tooltip').css('left', e.pageX + 20 );
 
    }).mouseout(function() {
 
        // reset the title attribute
        $(this).attr('title',$('.tipBody').html());
 
        // delete the tooltip
        $(this).children('div#tooltip').remove();
 
    });
 
});
