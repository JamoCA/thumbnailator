<cfif !structKeyExists(request, "_testHelperLoaded")><cfinclude template="_testHelper.cfm"><cfelse><cfscript>request.passes = 0; request.failures = [];</cfscript></cfif>
<cfscript>
	writeOutput("<!doctype html><meta charset='utf-8'><title>thumbnailator resize</title><style>body{font-family:monospace}</style>");
	writeOutput("<h1>Thumbnailator - resize tests</h1>");
	writeOutput("<div style='color:##666;font-size:0.9em'>" & encodeForHTML(serverInfo()) & "</div>");

	thumb = new Thumbnailator();
	src = makeFixture("resize-fixture", 400, 300, "png");

	/* size() preserves aspect ratio (default) */
	dest = tempPath("png");
	r = thumb.resize(src, dest, 100, 100);
	assert(r.width lte 100 && r.height lte 100, "size(100,100) lands within 100x100");
	assert((r.width eq 100 && r.height lte 100) || (r.height eq 100 && r.width lte 100), "size(100,100) preserves aspect ratio");

	/* forceSize() lands exact */
	dest = tempPath("png");
	r = thumb.of(src).forceSize(150, 150).toFile(dest);
	assert(r.width eq 150 && r.height eq 150, "forceSize(150,150) lands exactly 150x150");

	/* width() */
	dest = tempPath("png");
	r = thumb.of(src).width(50).toFile(dest);
	assert(r.width eq 50, "width(50) lands exactly width=50");
	assert(r.height eq 38 || r.height eq 37, "width(50) preserves aspect (height ~ 37 or 38)");

	/* height() */
	dest = tempPath("png");
	r = thumb.of(src).height(60).toFile(dest);
	assert(r.height eq 60, "height(60) lands exactly height=60");
	assert(r.width eq 80, "height(60) preserves aspect (width = 80 for 400x300 source)");

	/* scale() single factor */
	dest = tempPath("png");
	r = thumb.of(src).scale(0.5).toFile(dest);
	assert(r.width eq 200 && r.height eq 150, "scale(0.5) halves both dimensions");

	/* scale() two factors */
	dest = tempPath("png");
	r = thumb.of(src).scale(0.5, 0.25).toFile(dest);
	assert(r.width eq 200 && r.height eq 75, "scale(0.5, 0.25) independent w/h scaling");

	/* keepAspectRatio(false) + size */
	dest = tempPath("png");
	r = thumb.of(src).size(200, 200).keepAspectRatio(false).toFile(dest);
	assert(r.width eq 200 && r.height eq 200, "size(200,200) + keepAspectRatio(false) matches forceSize");

	/* scalingMode all preset names accepted */
	modes = ["default", "quality", "speed", "bilinear", "bicubic", "progressive_bilinear"];
	for (m in modes) {
		dest = tempPath("png");
		r = thumb.of(src).size(80, 60).scalingMode(m).toFile(dest);
		assert(r.width gt 0 && r.height gt 0, "scalingMode('" & m & "') produces a non-empty file");
	}

	/* one-shot scaleImage() */
	dest = tempPath("png");
	r = thumb.scaleImage(src, dest, 0.25);
	assert(r.width eq 100 && r.height eq 75, "scaleImage(0.25) one-shot lands at 100x75");

	/* one-shot resize() with opts */
	dest = tempPath("jpg");
	r = thumb.resize(src, dest, 80, 60, ["quality": 0.7, "outputFormat": "jpg"]);
	assert(r.format contains "jpeg" || r.format contains "jpg", "resize() with outputFormat=jpg writes JPEG");

	summarize();
</cfscript>
