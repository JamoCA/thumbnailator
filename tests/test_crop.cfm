<cfif !structKeyExists(request, "_testHelperLoaded")><cfinclude template="_testHelper.cfm"><cfelse><cfscript>request.passes = 0; request.failures = [];</cfscript></cfif>
<cfscript>
	writeOutput("<!doctype html><meta charset='utf-8'><title>thumbnailator crop</title><style>body{font-family:monospace}</style>");
	writeOutput("<h1>Thumbnailator - crop tests</h1>");
	writeOutput("<div style='color:##666;font-size:0.9em'>" & encodeForHTML(serverInfo()) & "</div>");

	thumb = new Thumbnailator();
	src = makeFixture("crop-fixture", 400, 300, "png");

	/* center crop to square */
	dest = tempPath("png");
	r = thumb.cropImage(src, dest, 100, 100, "center");
	assert(r.width eq 100 && r.height eq 100, "cropImage center 100x100 lands exact");

	/* all nine position names accepted */
	positions = ["center","top_left","top_center","top_right","left_center","right_center","bottom_left","bottom_center","bottom_right"];
	for (p in positions) {
		dest = tempPath("png");
		r = thumb.cropImage(src, dest, 80, 80, p);
		assert(r.width eq 80 && r.height eq 80, "cropImage position '" & p & "' produces 80x80");
	}

	/* sourceRegion(x,y,w,h) + size */
	dest = tempPath("png");
	r = thumb.of(src).sourceRegion(50, 25, 200, 150).size(100, 75).toFile(dest);
	assert(r.width eq 100 && r.height eq 75, "sourceRegion(50,25,200,150)+size(100,75) lands exact");

	/* sourceRegion(positionName, w, h) + size */
	dest = tempPath("png");
	r = thumb.of(src).sourceRegion("top_left", 200, 150).size(50, 50).toFile(dest);
	assert(r.width lte 50 && r.height lte 50, "sourceRegion(top_left,200,150)+size(50,50) within bounds");

	/* sourceRegion outside source bounds throws */
	assertThrows(function() {
		thumb.of(src).sourceRegion(500, 500, 100, 100).size(50, 50).toFile(tempPath("png"));
	}, "Thumbnailator.IOError", "sourceRegion outside bounds throws Thumbnailator.IOError");

	summarize();
</cfscript>
