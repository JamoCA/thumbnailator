<cfinclude template="_testHelper.cfm">
<cfscript>
	writeOutput("<!doctype html><meta charset='utf-8'><title>thumbnailator smoke</title><style>body{font-family:monospace}</style>");
	writeOutput("<h1>Thumbnailator - smoke test</h1>");
	writeOutput("<div style='color:##666;font-size:0.9em'>" & encodeForHTML(serverInfo()) & "</div>");

	thumb = new Thumbnailator();
	assert(isObject(thumb), "new Thumbnailator() returns a CFC instance");

	jClass = createObject("java", "net.coobird.thumbnailator.Thumbnails");
	assert(!isNull(jClass), "net.coobird.thumbnailator.Thumbnails Java class is reachable");

	srcPath = makeFixture("smoke", 400, 300, "png");
	destPath = tempPath("jpg");
	result = thumb.resize(srcPath, destPath, 100, 75);
	assert(isStruct(result), "resize() returns a struct");
	assert(structKeyExists(result, "ok") && result.ok, "resize() result has ok=true");
	assert(structKeyExists(result, "destPath") && fileExists(result.destPath), "resize() created the destination file");
	assert(structKeyExists(result, "width") && result.width lte 100, "resize() result width within bound");
	assert(structKeyExists(result, "height") && result.height lte 75, "resize() result height within bound");
	assert(structKeyExists(result, "sizeBytes") && result.sizeBytes gt 0, "resize() result reports non-zero sizeBytes");
	assert(structKeyExists(result, "durationMs") && result.durationMs gte 0, "resize() result reports durationMs");

	info = thumb.inspect(srcPath);
	assert(isStruct(info) && info.width eq 400 && info.height eq 300, "inspect() reports correct source dimensions");

	summarize();
</cfscript>
