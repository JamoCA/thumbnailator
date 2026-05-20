<cfinclude template="_testHelper.cfm">
<cfscript>
	writeOutput("<!doctype html><meta charset='utf-8'><title>thumbnailator rotate</title><style>body{font-family:monospace}</style>");
	writeOutput("<h1>Thumbnailator - rotate tests</h1>");
	writeOutput("<div style='color:##666;font-size:0.9em'>" & encodeForHTML(serverInfo()) & "</div>");

	thumb = new Thumbnailator();
	src = makeFixture("rotate-fixture", 400, 200, "png");

	/* rotate(90): landscape -> portrait */
	dest = tempPath("png");
	r = thumb.rotateImage(src, dest, 90);
	assert(r.width eq 200 && r.height eq 400, "rotate(90) of 400x200 produces 200x400");

	/* rotate(180): same dims */
	dest = tempPath("png");
	r = thumb.rotateImage(src, dest, 180);
	assert(r.width eq 400 && r.height eq 200, "rotate(180) keeps source dimensions");

	/* rotate(270): portrait */
	dest = tempPath("png");
	r = thumb.rotateImage(src, dest, 270);
	assert(r.width eq 200 && r.height eq 400, "rotate(270) of 400x200 produces 200x400");

	/* rotate(45): bounding box expands */
	dest = tempPath("png");
	r = thumb.rotateImage(src, dest, 45);
	assert(r.width gt 400 && r.height gt 200, "rotate(45) expands canvas (bounding box grows)");

	/* rotate(-90): same as 270 */
	dest = tempPath("png");
	r = thumb.rotateImage(src, dest, -90);
	assert(r.width eq 200 && r.height eq 400, "rotate(-90) of 400x200 produces 200x400");

	/* fluent: chained .of().rotate().size().toFile() */
	dest = tempPath("png");
	r = thumb.of(src).rotate(90).size(50, 100).toFile(dest);
	assert(r.width lte 50 && r.height lte 100, "chained rotate(90)+size(50,100) preserves aspect");

	/* EXIF orientation=6 (rotate CW 90 to display). With useExifOrientation(true), output should be portrait. */
	exifSrc = makeJpegWithExifOrientation(6);
	dest = tempPath("jpg");
	r = thumb.of(exifSrc).useExifOrientation(true).size(800, 800).toFile(dest);
	assert(r.height gt r.width, "useExifOrientation(true) on orientation=6 fixture: output is portrait");

	/* Without useExifOrientation, the same fixture stays landscape */
	dest = tempPath("jpg");
	r = thumb.of(exifSrc).useExifOrientation(false).size(800, 800).toFile(dest);
	assert(r.width gte r.height, "useExifOrientation(false): output remains landscape (no auto-rotate)");

	summarize();
</cfscript>
