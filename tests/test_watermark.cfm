<cfinclude template="_testHelper.cfm">
<cfscript>
	writeOutput("<!doctype html><meta charset='utf-8'><title>thumbnailator watermark</title><style>body{font-family:monospace}</style>");
	writeOutput("<h1>Thumbnailator - watermark tests</h1>");
	writeOutput("<div style='color:##666;font-size:0.9em'>" & encodeForHTML(serverInfo()) & "</div>");

	thumb = new Thumbnailator();
	src = makeFixture("wm-fixture", 400, 300, "png");
	wm  = makeFixture("wm-mark", 100, 50, "png");

	/* all nine positions */
	positions = ["center","top_left","top_center","top_right","left_center","right_center","bottom_left","bottom_center","bottom_right"];
	for (p in positions) {
		dest = tempPath("png");
		r = thumb.watermarkImage(src, dest, wm, p, 0.5);
		assert(r.width gt 0 && r.height gt 0 && r.sizeBytes gt 0, "watermark position '" & p & "' writes non-empty file");
	}

	/* opacity 0.0 and 1.0 */
	dest = tempPath("png");
	r = thumb.watermarkImage(src, dest, wm, "center", 0.0);
	assert(r.sizeBytes gt 0, "watermark opacity 0.0 produces a file");

	dest = tempPath("png");
	r = thumb.watermarkImage(src, dest, wm, "center", 1.0);
	assert(r.sizeBytes gt 0, "watermark opacity 1.0 produces a file");

	/* insets parameter accepted */
	dest = tempPath("png");
	r = thumb.watermarkImage(src, dest, wm, "bottom_right", 0.5, 20);
	assert(r.sizeBytes gt 0, "watermark with insets=20 produces a file");

	/* missing watermark file -> SourceNotFound */
	assertThrows(function() {
		thumb.watermarkImage(src, tempPath("png"), "C:\does-not-exist-watermark.png", "center", 0.5);
	}, "Thumbnailator.SourceNotFound", "missing watermark file throws Thumbnailator.SourceNotFound");

	/* bad opacity rejected */
	assertThrows(function() {
		thumb.of(src).watermark(wm, "center", 1.5);
	}, "Thumbnailator.InvalidArgument", "watermark opacity 1.5 throws Thumbnailator.InvalidArgument");

	/* bad position rejected */
	assertThrows(function() {
		thumb.of(src).watermark(wm, "not_a_position", 0.5);
	}, "Thumbnailator.UnknownPosition", "watermark bad position throws Thumbnailator.UnknownPosition");

	summarize();
</cfscript>
