<cfsetting requesttimeout="60">
<cfprocessingdirective pageEncoding="utf-8">
<cfcontent type="text/html; charset=utf-8">
<cfscript>
	setEncoding("form", "utf-8");
	setEncoding("url", "utf-8");

	thumb = new Thumbnailator();

	demoImageDir = expandPath("./demo-images/");
	demoOutputDir = expandPath("./demo-output/");
	if (!directoryExists(demoOutputDir)) createObject("java","java.io.File").init(javacast("string", demoOutputDir)).mkdirs();

	function ensureStarterImage(required string dir) {
		if (!directoryExists(arguments.dir)) createObject("java","java.io.File").init(javacast("string", arguments.dir)).mkdirs();
		var existing = directoryList(arguments.dir, false, "name");
		var hasImage = false;
		for (var n in existing) {
			if (reFindNoCase("\.(png|jpe?g|gif|bmp)$", n)) { hasImage = true; break; }
		}
		if (hasImage) return;
		var path = arguments.dir & "starter.png";
		var bi = createObject("java", "java.awt.image.BufferedImage").init(javacast("int", 800), javacast("int", 600), javacast("int", 1));
		var g = bi.createGraphics();
		try {
			var gp = createObject("java", "java.awt.GradientPaint").init(
				javacast("float", 0), javacast("float", 0),
				createObject("java", "java.awt.Color").init(javacast("int", 30), javacast("int", 80), javacast("int", 180)),
				javacast("float", 800), javacast("float", 600),
				createObject("java", "java.awt.Color").init(javacast("int", 230), javacast("int", 200), javacast("int", 80))
			);
			g.setPaint(gp);
			g.fillRect(javacast("int", 0), javacast("int", 0), javacast("int", 800), javacast("int", 600));
			g.setColor(createObject("java", "java.awt.Color").init(javacast("int", 220), javacast("int", 60), javacast("int", 60)));
			g.fillRect(javacast("int", 80), javacast("int", 80), javacast("int", 160), javacast("int", 160));
			g.setColor(createObject("java", "java.awt.Color").init(javacast("int", 60), javacast("int", 180), javacast("int", 100)));
			g.fillOval(javacast("int", 400), javacast("int", 120), javacast("int", 200), javacast("int", 200));
			var poly = createObject("java", "java.awt.Polygon").init();
			poly.addPoint(javacast("int", 200), javacast("int", 500));
			poly.addPoint(javacast("int", 400), javacast("int", 360));
			poly.addPoint(javacast("int", 600), javacast("int", 500));
			g.setColor(createObject("java", "java.awt.Color").WHITE);
			g.fillPolygon(poly);
			g.setColor(createObject("java", "java.awt.Color").BLACK);
			g.setFont(createObject("java", "java.awt.Font").init(javacast("string", "SansSerif"), javacast("int", 1), javacast("int", 36)));
			g.drawString(javacast("string", "Thumbnailator Demo"), javacast("int", 200), javacast("int", 50));
		} finally {
			g.dispose();
		}
		createObject("java", "javax.imageio.ImageIO").write(bi, javacast("string", "png"), createObject("java", "java.io.File").init(path));
	}

	ensureStarterImage(demoImageDir);

	function serverInfo() {
		var engine = "Unknown";
		var version = "?";
		if (structKeyExists(server, "boxlang")) {
			engine = "BoxLang";
			version = server.boxlang.version;
		} else if (structKeyExists(server, "lucee")) {
			engine = "Lucee";
			version = server.lucee.version;
		} else if (structKeyExists(server, "coldfusion")) {
			engine = "Adobe ColdFusion";
			version = replace(server.coldfusion.productversion, ",", ".", "all");
		}
		var iso = "";
		try { iso = dateTimeFormat(now(), "iso"); }
		catch (any e) { iso = dateTimeFormat(now(), "yyyy-mm-dd'T'HH:nn:ss"); }
		return engine & " " & version & " / Java " & createObject("java", "java.lang.System").getProperty("java.version") & " / " & iso;
	}

	function humanSize(required numeric bytes) {
		if (arguments.bytes lt 1024) return arguments.bytes & " B";
		if (arguments.bytes lt 1048576) return numberFormat(arguments.bytes / 1024, "0.0") & " KB";
		return numberFormat(arguments.bytes / 1048576, "0.00") & " MB";
	}

	function cleanOldOutput(required string dir, required numeric ageSeconds) {
		if (!directoryExists(arguments.dir)) return;
		var cutoff = dateAdd("s", -arguments.ageSeconds, now());
		var files = directoryList(arguments.dir, false, "query");
		for (var i = 1; i lte files.recordCount; i++) {
			if (files.type[i] eq "File" && dateCompare(files.dateLastModified[i], cutoff) lt 0) {
				try { fileDelete(files.directory[i] & "/" & files.name[i]); } catch (any e) {}
			}
		}
	}

	if (structKeyExists(url, "clear")) cleanOldOutput(demoOutputDir, 0);
	else cleanOldOutput(demoOutputDir, 600);

	starter = demoImageDir & "starter.png";
	starterUrl = "demo-images/starter.png";
</cfscript>
<!doctype html>
<html><head>
	<meta charset="utf-8">
	<title>Thumbnailator CFML Demo</title>
	<style>
		body { font-family: -apple-system, Segoe UI, sans-serif; max-width: 1100px; margin: 1em auto; padding: 0 1em; }
		h1, h2 { border-bottom: 1px solid #ccc; padding-bottom: 0.3em; }
		.serverinfo { color:#666; font-size:0.9em; margin: 0.4em 0 1.5em; }
		.gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 1em; }
		.card { border: 1px solid #ddd; border-radius: 4px; padding: 0.8em; background: #fafafa; }
		.card h3 { margin: 0 0 0.5em; font-size: 1em; }
		.card img { max-width: 100%; height: auto; display: block; margin: 0.4em 0; border: 1px solid #ccc; background: #fff; }
		.meta { font-family: monospace; font-size: 0.85em; color: #555; }
		details { margin-top: 0.5em; }
		details pre { background: #2d2d2d; color: #eee; padding: 0.6em; overflow-x: auto; font-size: 0.8em; }
		form { background: #f0f0f0; padding: 1em; border-radius: 4px; }
		form label { display: inline-block; min-width: 9em; margin: 0.2em 0; }
		.error { background: #fee; color: #900; padding: 0.6em; margin: 1em 0; border: 1px solid #faa; }
		.result { display: grid; grid-template-columns: 1fr 1fr; gap: 1em; margin-top: 1em; }
		.result img { max-width: 100%; height: auto; border: 1px solid #ccc; }
	</style>
</head>
<body>
<h1>Thumbnailator CFML Demo</h1>
<div class="serverinfo"><cfoutput>#encodeForHTML(serverInfo())#</cfoutput></div>
<p><a href="?clear=1">Clear demo-output now</a> (auto-cleans files older than 10 minutes)</p>
<cfscript>
	function renderCard(required string title, required string srcUrl, required struct result, required string code) {
		var resultUrl = "demo-output/" & listLast(arguments.result.destPath, "/\");
		writeOutput("<div class='card'>");
		writeOutput("<h3>" & encodeForHTML(arguments.title) & "</h3>");
		writeOutput("<div style='display:flex;gap:0.4em'>");
		writeOutput("<div><div class='meta'>source</div><img src='" & encodeForHTMLAttribute(arguments.srcUrl) & "' alt=''></div>");
		writeOutput("<div><div class='meta'>result</div><img src='" & encodeForHTMLAttribute(resultUrl) & "' alt=''></div>");
		writeOutput("</div>");
		writeOutput("<div class='meta'>" & arguments.result.width & "x" & arguments.result.height & " - " & humanSize(arguments.result.sizeBytes) & " - " & arguments.result.durationMs & " ms</div>");
		writeOutput("<details><summary>CFC code</summary><pre>" & encodeForHTML(arguments.code) & "</pre></details>");
		writeOutput("</div>");
	}

	writeOutput("<h2>Preset gallery</h2><div class='gallery'>");

	/* Preset 1: resize 320x240 */
	d = demoOutputDir & "gallery-1-resize.jpg";
	r = thumb.resize(starter, d, 320, 240, ["quality": 0.85, "outputFormat": "jpg"]);
	renderCard("resize 320x240, JPEG q=0.85", starterUrl, r, 'thumb.resize(src, dest, 320, 240, ["quality": 0.85, "outputFormat": "jpg"]);');

	/* Preset 2: forceSize 200x200 */
	d = demoOutputDir & "gallery-2-forcesize.jpg";
	r = thumb.of(starter).forceSize(200, 200).outputFormat("jpg").outputQuality(0.85).toFile(d);
	renderCard("forceSize 200x200 (squashed)", starterUrl, r, 'thumb.of(src).forceSize(200,200).outputFormat("jpg").outputQuality(0.85).toFile(dest);');

	/* Preset 3: crop center 200x200 */
	d = demoOutputDir & "gallery-3-crop.jpg";
	r = thumb.cropImage(starter, d, 200, 200, "center", ["outputFormat": "jpg", "quality": 0.85]);
	renderCard("crop center 200x200 (square thumbnail done right)", starterUrl, r, 'thumb.cropImage(src, dest, 200, 200, "center", ["outputFormat":"jpg","quality":0.85]);');

	/* Preset 4: rotate 45 */
	d = demoOutputDir & "gallery-4-rotate.png";
	r = thumb.of(starter).size(300, 300).rotate(45).useExifOrientation(true).toFile(d);
	renderCard("rotate 45 deg with useExifOrientation(true)", starterUrl, r, 'thumb.of(src).size(300,300).rotate(45).useExifOrientation(true).toFile(dest);');

	/* Preset 5: watermark - generate watermark.png on demand */
	wmPath = demoOutputDir & "watermark.png";
	if (!fileExists(wmPath)) {
		wbi = createObject("java","java.awt.image.BufferedImage").init(javacast("int",150),javacast("int",50),javacast("int",2));
		wg = wbi.createGraphics();
		wg.setColor(createObject("java","java.awt.Color").init(javacast("int",255),javacast("int",255),javacast("int",255),javacast("int",180)));
		wg.fillRect(javacast("int",0),javacast("int",0),javacast("int",150),javacast("int",50));
		wg.setColor(createObject("java","java.awt.Color").BLACK);
		wg.setFont(createObject("java","java.awt.Font").init(javacast("string","SansSerif"),javacast("int",1),javacast("int",18)));
		wg.drawString(javacast("string","WATERMARK"),javacast("int",10),javacast("int",32));
		wg.dispose();
		createObject("java","javax.imageio.ImageIO").write(wbi, javacast("string","png"), createObject("java","java.io.File").init(wmPath));
	}
	d = demoOutputDir & "gallery-5-watermark.png";
	r = thumb.watermarkImage(starter, d, wmPath, "bottom_right", 0.5, 10, ["outputFormat":"png"]);
	renderCard("watermark bottom_right opacity 0.5 inset 10", starterUrl, r, 'thumb.watermarkImage(src, dest, wmPath, "bottom_right", 0.5, 10);');

	/* Preset 6: convertFormat to PNG with scalingMode quality */
	d = demoOutputDir & "gallery-6-png.png";
	r = thumb.convertFormat(starter, d, "png", ["scalingMode": "quality"]);
	renderCard("convertFormat PNG with scalingMode 'quality'", starterUrl, r, 'thumb.convertFormat(src, dest, "png", ["scalingMode":"quality"]);');

	writeOutput("</div>");
</cfscript>
<cfscript>
	function listDemoImages(required string dir) {
		if (!directoryExists(arguments.dir)) return [];
		var raw = directoryList(arguments.dir, false, "name");
		var out = [];
		for (var n in raw) if (reFindNoCase("\.(png|jpe?g|gif|bmp)$", n)) arrayAppend(out, n);
		return out;
	}

	demoImages = listDemoImages(demoImageDir);
	formSrc = (structKeyExists(form, "src") && len(form.src) && fileExists(demoImageDir & form.src)) ? form.src : "starter.png";
	formOp = (structKeyExists(form, "op") && len(form.op)) ? form.op : "resize";

	function ff(required string key, required string fallback) {
		return (structKeyExists(form, arguments.key) && len(form[arguments.key])) ? form[arguments.key] : arguments.fallback;
	}
</cfscript>
<cfoutput>
<h2>Interactive sandbox</h2>
<form method="post">
	<label>Source image:</label>
	<select name="src">
		<cfloop array="#demoImages#" index="img">
			<option value="#encodeForHTMLAttribute(img)#"<cfif img eq formSrc> selected</cfif>>#encodeForHTML(img)#</option>
		</cfloop>
	</select><br>

	<label>Operation:</label>
	<select name="op">
		<cfloop array="#['resize','scale','rotate','crop','watermark','sourceRegion','convertFormat','fluent-chain']#" index="o">
			<option value="#o#"<cfif o eq formOp> selected</cfif>>#o#</option>
		</cfloop>
	</select><br>

	<label>width:</label> <input type="number" name="w" value="#encodeForHTMLAttribute(ff('w','200'))#" min="1" max="5000"><br>
	<label>height:</label> <input type="number" name="h" value="#encodeForHTMLAttribute(ff('h','150'))#" min="1" max="5000"><br>
	<label>factor (for scale):</label> <input type="number" step="0.01" name="factor" value="#encodeForHTMLAttribute(ff('factor','0.5'))#"><br>
	<label>degrees (for rotate):</label> <input type="number" name="degrees" value="#encodeForHTMLAttribute(ff('degrees','90'))#"><br>
	<label>position:</label>
	<select name="position">
		<cfloop array="#['center','top_left','top_center','top_right','left_center','right_center','bottom_left','bottom_center','bottom_right']#" index="p">
			<option value="#p#"<cfif structKeyExists(form,'position') && form.position eq p> selected</cfif>>#p#</option>
		</cfloop>
	</select><br>
	<label>opacity:</label> <input type="number" step="0.01" name="opacity" value="#encodeForHTMLAttribute(ff('opacity','0.5'))#" min="0" max="1"><br>
	<label>insets:</label> <input type="number" name="insets" value="#encodeForHTMLAttribute(ff('insets','10'))#" min="0"><br>
	<label>sourceRegion x,y,w,h:</label>
	<input type="number" name="rx" value="#encodeForHTMLAttribute(ff('rx','0'))#" style="width:5em">
	<input type="number" name="ry" value="#encodeForHTMLAttribute(ff('ry','0'))#" style="width:5em">
	<input type="number" name="rw" value="#encodeForHTMLAttribute(ff('rw','200'))#" style="width:5em">
	<input type="number" name="rh" value="#encodeForHTMLAttribute(ff('rh','150'))#" style="width:5em"><br>
	<label>outputFormat:</label>
	<select name="fmt">
		<cfloop array="#['(original)','jpg','png','gif','bmp']#" index="f">
			<option value="#f#"<cfif structKeyExists(form,'fmt') && form.fmt eq f> selected</cfif>>#f#</option>
		</cfloop>
	</select><br>
	<label>quality (0-1):</label> <input type="number" step="0.01" name="quality" value="#encodeForHTMLAttribute(ff('quality','0.85'))#" min="0" max="1"><br>
	<label>scalingMode:</label>
	<select name="scaling">
		<cfloop array="#['default','quality','speed','bilinear','bicubic','progressive_bilinear']#" index="s">
			<option value="#s#"<cfif structKeyExists(form,'scaling') && form.scaling eq s> selected</cfif>>#s#</option>
		</cfloop>
	</select><br>
	<label>useExifOrientation:</label>
	<select name="exif">
		<option value="yes"<cfif !structKeyExists(form,'exif') || form.exif eq 'yes'> selected</cfif>>yes</option>
		<option value="no"<cfif structKeyExists(form,'exif') && form.exif eq 'no'> selected</cfif>>no</option>
	</select><br>
	<label>fluent chain (only for fluent-chain op):</label><br>
	<textarea name="chain" rows="6" cols="60">#encodeForHTML(ff('chain','size 320 240' & chr(10) & 'rotate 90' & chr(10) & 'outputFormat jpg' & chr(10) & 'outputQuality 0.8'))#</textarea><br>
	<button type="submit" name="run" value="1">Run transform</button>
</form>
</cfoutput>
</body></html>
