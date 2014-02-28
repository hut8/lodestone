var xPtr = 0;
var yPtr = 0;

var updateLocation = function(magid,ev) {
    var mag = $("#" + ev.target.id);
    xPtr = parseInt(mag.css("left"));
    yPtr = parseInt(mag.css("top"));
    //xPtr = ev.pageY;
    //yPtr = ev.pageX;
    $.ajax({
	    url: 'efridge.cgi?M(' + ev.target.id.substr(4) + ',' + xPtr + ',' + yPtr+')',
	    dataType: 'script'
	});
    xPtr += 10;
};

var renderMagnets = function(objs) {
    /* objs is array of: magnet[id, letter, #rgb, x, y] */
    $("#door").find(".magnet").remove();
    /* magmap is magnetid -> 1 map (really a set) */
    for (var i=0; i < objs.length; i++) {
	var obj = objs[i];
	$("#door").append(
			  $("<span/>").addClass("magnet")
			  .attr("id", 'btn-'+obj[0])
			  .html(obj[1])
			  .css("cursor", "crosshair")
			  .css("left", obj[3])
			  .css("top", obj[4])
			  .css("color", obj[2])
			  .draggable({
				  stop: function(e) {
				      updateLocation(obj[0],e);
				  }
			      })
			  .noContext()
			  .rightClick(function(e) {
				  deleteObject(e);
			      })
			  );
    }
};

var nukeDatabase = function() {
        $.ajax({
	    url: 'efridge.cgi?R',
	    dataType: 'script'
	});
};

var getObjects = function() {
    $.ajax({
	    url: 'efridge.cgi?G',
	    dataType: 'script'
	});
};

var genObject = function(letter) {
    $.ajax({
	    url: 'efridge.cgi?P('+letter+','+Math.floor(Math.random()*200)+','
	    +Math.floor(Math.random()*200)+','+Math.floor(Math.random()*200)+','+xPtr+','+yPtr+')',
	    error: function() {alert('Segmentation fault') },
	    dataType: "script"
	});
    xPtr += 10;
};

var pollChange = function() {
    $.ajax({
	    url: 'efridge.cgi?N',
	    dataType: "script",
	    complete: function() { pollChange(); }
	});
};

var deleteObject = function(ev) {
    $.ajax({
	    url: 'efridge.cgi?D(' + ev.target.id.substr(4) + ')',
	    dataType: 'script'
	});    
};


$(function() {
	/* main service routine */
	letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
	/* create generator buttons */
	for (i=0;i<letters.length;i++) {
	    $("#letter-gen-buttons").append(
					    $("<span/>").addClass("gen-btn")
					    .html(letters.charAt(i))
					    .click(function() {
						    genObject($(this).text());
				
						})
					    );
	}
	/* initially retrieve objects without blocking */
	getObjects();
	/* repeatedly poll for changes */
	pollChange();
    });