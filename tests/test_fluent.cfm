<cfif !structKeyExists(request, "_testHelperLoaded")><cfinclude template="_testHelper.cfm"><cfelse><cfscript>request.passes = 0; request.failures = [];</cfscript></cfif>
<cfscript>
	writeOutput("<!doctype html><meta charset='utf-8'><title>thumbnailator fluent</title><style>body{font-family:monospace}</style>");
	writeOutput("<h1>Thumbnailator - fluent tests</h1>");
	writeOutput("<div style='color:##666;font-size:0.9em'>" & encodeForHTML(serverInfo()) & "</div>");

	thumb = new Thumbnailator();
	src = makeFixture("fluent-fixture", 600, 400, "png");
	wm  = makeFixture("fluent-wm", 80, 40, "png");

	/* Reusable builder: same .of()+.size() pipeline written to two destinations */
	thumb.of(src).size(200, 150);
	a = tempPath("png");
	b = tempPath("png");
	r1 = thumb.toFile(a);
	r2 = thumb.toFile(b);
	assert(r1.width gt 0 && r2.width gt 0, "Builder is reusable across multiple terminal calls");

	/* Long chain */
	dest = tempPath("jpg");
	r = thumb.of(src).size(300, 200).rotate(90).watermark(wm, "bottom_right", 0.5, 10).outputFormat("jpg").outputQuality(0.8).toFile(dest);
	assert(r.sizeBytes gt 0, "long fluent chain produces a non-empty file");
	assert(r.format contains "jpeg" || r.format contains "jpg", "long fluent chain output is JPEG");

	/* toFiles with two sources */
	src2 = makeFixture("fluent-fixture-2", 200, 200, "png");
	destDir = expandPath("../demo-output/test/fluent-batch/");
	if (directoryExists(destDir)) directoryDelete(destDir, true);
	results = thumb.of([src, src2]).size(100, 100).toFiles(destDir, "t-");
	assert(arrayLen(results) eq 2, "toFiles with two sources returns two result structs");
	for (rr in results) assert(fileExists(rr.destPath), "toFiles wrote " & rr.destPath);

	/* asBufferedImage */
	bi = thumb.of(src).size(50, 50).asBufferedImage();
	assert(!isNull(bi), "asBufferedImage() returns a non-null Java object");
	assert(bi.getWidth() lte 50 && bi.getHeight() lte 50, "asBufferedImage() dimensions within bounds");

	/* createThumbnail */
	dest = tempPath("jpg");
	r = thumb.createThumbnail(src, dest, 120, 90);
	assert(r.width lte 120 && r.height lte 90, "createThumbnail() lands within target");
	assert(r.format contains "jpeg" || r.format contains "jpg", "createThumbnail() defaults to JPEG");

	summarize();
</cfscript>
