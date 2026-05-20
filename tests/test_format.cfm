<cfif !structKeyExists(request, "_testHelperLoaded")><cfinclude template="_testHelper.cfm"><cfelse><cfscript>request.passes = 0; request.failures = [];</cfscript></cfif>
<cfscript>
	writeOutput("<!doctype html><meta charset='utf-8'><title>thumbnailator format</title><style>body{font-family:monospace}</style>");
	writeOutput("<h1>Thumbnailator - format tests</h1>");
	writeOutput("<div style='color:##666;font-size:0.9em'>" & encodeForHTML(serverInfo()) & "</div>");

	thumb = new Thumbnailator();
	srcPng = makeFixture("fmt-fixture", 400, 300, "png");

	/* JPEG magic FF D8 FF */
	dest = tempPath("jpg");
	r = thumb.convertFormat(srcPng, dest, "jpg");
	bytes = readMagicBytes(dest, 3);
	assert(bytes[1] eq "FF" && bytes[2] eq "D8" && bytes[3] eq "FF", "outputFormat('jpg') writes JPEG magic FF D8 FF");

	/* PNG magic 89 50 4E 47 */
	dest = tempPath("png");
	r = thumb.convertFormat(srcPng, dest, "png");
	bytes = readMagicBytes(dest, 4);
	assert(bytes[1] eq "89" && bytes[2] eq "50" && bytes[3] eq "4E" && bytes[4] eq "47", "outputFormat('png') writes PNG magic 89 50 4E 47");

	/* GIF magic */
	dest = tempPath("gif");
	r = thumb.convertFormat(srcPng, dest, "gif");
	bytes = readMagicBytes(dest, 4);
	assert(bytes[1] eq "47" && bytes[2] eq "49" && bytes[3] eq "46" && bytes[4] eq "38", "outputFormat('gif') writes GIF magic 47 49 46 38");

	/* BMP magic */
	dest = tempPath("bmp");
	r = thumb.convertFormat(srcPng, dest, "bmp");
	bytes = readMagicBytes(dest, 2);
	assert(bytes[1] eq "42" && bytes[2] eq "4D", "outputFormat('bmp') writes BMP magic 42 4D");

	/* useOriginalFormat() keeps source format */
	srcJpg = makeFixture("fmt-orig", 200, 150, "jpg");
	dest = tempPath("jpg");
	r = thumb.of(srcJpg).size(80, 60).useOriginalFormat().toFile(dest);
	bytes = readMagicBytes(dest, 3);
	assert(bytes[1] eq "FF" && bytes[2] eq "D8" && bytes[3] eq "FF", "useOriginalFormat() on JPEG source keeps JPEG output");

	/* outputQuality lower -> smaller file */
	destHi = tempPath("jpg");
	destLo = tempPath("jpg");
	thumb.of(srcJpg).size(800, 600).outputFormat("jpg").outputQuality(0.95).toFile(destHi);
	thumb.of(srcJpg).size(800, 600).outputFormat("jpg").outputQuality(0.5).toFile(destLo);
	szHi = createObject("java","java.io.File").init(destHi).length();
	szLo = createObject("java","java.io.File").init(destLo).length();
	assert(szLo lt szHi, "outputQuality(0.5) file (" & szLo & "b) is smaller than outputQuality(0.95) file (" & szHi & "b)");

	/* alias "jpeg" maps to "jpg" */
	dest = tempPath("jpg");
	r = thumb.convertFormat(srcPng, dest, "jpeg");
	assert(r.format contains "jpeg" || r.format contains "jpg", "outputFormat('jpeg') alias resolves to JPEG");

	/* bad format rejected */
	assertThrows(function() {
		thumb.convertFormat(srcPng, tempPath("xyz"), "tiff");
	}, "Thumbnailator.UnknownFormat", "outputFormat('tiff') throws Thumbnailator.UnknownFormat");

	summarize();
</cfscript>
