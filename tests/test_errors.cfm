<cfinclude template="_testHelper.cfm">
<cfscript>
	writeOutput("<!doctype html><meta charset='utf-8'><title>thumbnailator errors</title><style>body{font-family:monospace}</style>");
	writeOutput("<h1>Thumbnailator - error tests</h1>");
	writeOutput("<div style='color:##666;font-size:0.9em'>" & encodeForHTML(serverInfo()) & "</div>");

	thumb = new Thumbnailator();
	src = makeFixture("err-fixture", 200, 150, "png");

	/* missing source */
	assertThrows(function() {
		thumb.resize("C:\does-not-exist.png", tempPath("png"), 50, 50);
	}, "Thumbnailator.SourceNotFound", "missing source -> SourceNotFound");

	/* bad outputFormat */
	assertThrows(function() {
		thumb.convertFormat(src, tempPath("xyz"), "tiff");
	}, "Thumbnailator.UnknownFormat", "bad outputFormat -> UnknownFormat");

	/* bad crop position */
	assertThrows(function() {
		thumb.of(src).crop("middle_middle");
	}, "Thumbnailator.UnknownPosition", "bad position -> UnknownPosition");

	/* bad scalingMode */
	assertThrows(function() {
		thumb.of(src).scalingMode("ultra");
	}, "Thumbnailator.UnknownScalingMode", "bad scalingMode -> UnknownScalingMode");

	/* outputQuality out of range */
	assertThrows(function() {
		thumb.of(src).outputQuality(1.5);
	}, "Thumbnailator.InvalidArgument", "outputQuality(1.5) -> InvalidArgument");

	assertThrows(function() {
		thumb.of(src).outputQuality(-0.1);
	}, "Thumbnailator.InvalidArgument", "outputQuality(-0.1) -> InvalidArgument");

	/* allowOverwrite(false) + existing dest */
	dest = tempPath("png");
	thumb.resize(src, dest, 50, 50);
	assertThrows(function() {
		thumb.of(src).size(60, 60).allowOverwrite(false).toFile(dest);
	}, "Thumbnailator.OverwriteBlocked", "allowOverwrite(false) on existing dest -> OverwriteBlocked");

	/* zero-byte input */
	emptyPath = tempPath("png");
	fileWrite(emptyPath, "");
	assertThrows(function() {
		thumb.resize(emptyPath, tempPath("png"), 50, 50);
	}, "Thumbnailator.", "zero-byte input throws a Thumbnailator.* error");

	/* very large dimensions still succeeds */
	dest = tempPath("png");
	r = thumb.of(src).width(2000).toFile(dest);
	assert(r.width eq 2000, "upscale to width 2000 succeeds without OOM");

	/* terminal call twice on same builder is idempotent */
	thumb.of(src).size(40, 30);
	a = tempPath("png");
	b = tempPath("png");
	r1 = thumb.toFile(a);
	r2 = thumb.toFile(b);
	assert(r1.width eq r2.width && r1.height eq r2.height, "terminal called twice produces identical dimensions");

	/* batchResize */
	srcDir = expandPath("../demo-output/test/batch-src/");
	if (directoryExists(srcDir)) directoryDelete(srcDir, true);
	createObject("java","java.io.File").init(javacast("string", srcDir)).mkdirs();
	for (i = 1; i lte 3; i++) {
		p = srcDir & "img" & i & ".png";
		makeBytes = makeFixture("batch-" & i, 300, 200, "png");
		fileCopy(makeBytes, p);
	}
	destDir = expandPath("../demo-output/test/batch-dest/");
	if (directoryExists(destDir)) directoryDelete(destDir, true);

	summary = thumb.batchResize(srcDir, destDir, 100, 75);
	assert(summary.count eq 3, "batchResize processed 3 files");
	assert(summary.totalBytes gt 0, "batchResize reports totalBytes");
	assert(summary.totalMs gte 0, "batchResize reports totalMs");

	summarize();
</cfscript>
