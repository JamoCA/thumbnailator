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
			var compat = "";
			try {
				compat = createObject("java", "java.lang.System").getenv(javacast("string", "BOXLANG_COMPAT_MODE"));
				if (isNull(compat)) compat = "";
			} catch (any e) {
				compat = "";
			}
			if (len(compat)) engine &= " (compat: " & compat & ")";
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
		.serverinfo { background:#f4f4f4; border:1px solid #ccc; padding:0.6em 0.8em; margin:0.6em 0 1.4em; font-size:0.95em; color:#333; font-family:monospace; }
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
		summary {cursor:pointer;}
		.toggle { background:#ddd; color:#444; border:1px solid #aaa; border-radius:3px; padding:2px 8px; cursor:pointer; font-family:monospace; font-size:0.85em; margin-right:0.5em; min-width:2.5em; }
		.toggle.on { background:#cfc; color:#070; border-color:#7a7; }
		.toggle.off { background:#f4f4f4; color:#888; }
		.field-row { display:inline; }
		.field-inactive input, .field-inactive select, .field-inactive textarea { opacity:0.4; }
		.field-inactive label { opacity:0.4; }
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
	<span class="field-row" data-field="insets">
		<button type="button" class="toggle on" data-target="insets" title="omit this option">on</button>
		<label>insets:</label> <input type="number" name="insets" value="#encodeForHTMLAttribute(ff('insets','10'))#" min="0">
	</span><br>
	<label>sourceRegion x,y,w,h:</label>
	<input type="number" name="rx" value="#encodeForHTMLAttribute(ff('rx','0'))#" style="width:5em">
	<input type="number" name="ry" value="#encodeForHTMLAttribute(ff('ry','0'))#" style="width:5em">
	<input type="number" name="rw" value="#encodeForHTMLAttribute(ff('rw','200'))#" style="width:5em">
	<input type="number" name="rh" value="#encodeForHTMLAttribute(ff('rh','150'))#" style="width:5em"><br>
	<span class="field-row" data-field="fmt">
		<button type="button" class="toggle on" data-target="fmt" title="omit this option">on</button>
		<label>outputFormat:</label>
		<select name="fmt">
			<cfloop array="#['(original)','jpg','png','gif','bmp']#" index="f">
				<option value="#f#"<cfif structKeyExists(form,'fmt') && form.fmt eq f> selected</cfif>>#f#</option>
			</cfloop>
		</select>
	</span><br>
	<span class="field-row" data-field="quality">
		<button type="button" class="toggle on" data-target="quality" title="omit this option">on</button>
		<label>quality (0-1):</label> <input type="number" step="0.01" name="quality" value="#encodeForHTMLAttribute(ff('quality','0.85'))#" min="0" max="1">
	</span><br>
	<span class="field-row" data-field="scaling">
		<button type="button" class="toggle on" data-target="scaling" title="omit this option">on</button>
		<label>scalingMode:</label>
		<select name="scaling">
			<cfloop array="#['default','quality','speed','bilinear','bicubic','progressive_bilinear']#" index="s">
				<option value="#s#"<cfif structKeyExists(form,'scaling') && form.scaling eq s> selected</cfif>>#s#</option>
			</cfloop>
		</select>
	</span><br>
	<span class="field-row" data-field="exif">
		<button type="button" class="toggle on" data-target="exif" title="omit this option">on</button>
		<label>useExifOrientation:</label>
		<select name="exif">
			<option value="yes"<cfif !structKeyExists(form,'exif') || form.exif eq 'yes'> selected</cfif>>yes</option>
			<option value="no"<cfif structKeyExists(form,'exif') && form.exif eq 'no'> selected</cfif>>no</option>
		</select>
	</span><br>
	<span class="field-row" data-field="exifPassthrough">
		<button type="button" class="toggle on" data-target="exifPassthrough" title="omit this option">on</button>
		<label>exifPassthrough:</label>
		<select name="exifPassthrough">
			<option value="1"<cfif structKeyExists(form,'exifPassthrough') && form.exifPassthrough eq '1'> selected</cfif>>yes</option>
			<option value="0"<cfif !structKeyExists(form,'exifPassthrough') || form.exifPassthrough eq '0'> selected</cfif>>no</option>
		</select>
	</span><br>
	<span class="field-row field-inactive" data-field="allowOverwrite">
		<button type="button" class="toggle off" data-target="allowOverwrite" title="omit this option">off</button>
		<label>allowOverwrite:</label>
		<select name="allowOverwrite" disabled>
			<option value="yes"<cfif structKeyExists(form,'allowOverwrite') && form.allowOverwrite eq 'yes'> selected</cfif>>yes</option>
			<option value="no"<cfif !structKeyExists(form,'allowOverwrite') || form.allowOverwrite eq 'no'> selected</cfif>>no</option>
		</select>
	</span><br>
	<span class="field-row field-inactive" data-field="keepAspectRatio">
		<button type="button" class="toggle off" data-target="keepAspectRatio" title="omit this option">off</button>
		<label>keepAspectRatio:</label>
		<select name="keepAspectRatio" disabled>
			<option value="yes"<cfif structKeyExists(form,'keepAspectRatio') && form.keepAspectRatio eq 'yes'> selected</cfif>>yes</option>
			<option value="no"<cfif !structKeyExists(form,'keepAspectRatio') || form.keepAspectRatio eq 'no'> selected</cfif>>no</option>
		</select>
	</span><br>
	<label>fluent chain (only for fluent-chain op):</label><br>
	<textarea name="chain" rows="6" cols="60">#encodeForHTML(ff('chain','size 320 240' & chr(10) & 'rotate 90' & chr(10) & 'outputFormat jpg' & chr(10) & 'outputQuality 0.8'))#</textarea><br>
	<button type="submit" name="run" value="1">Run transform</button>
</form>
</cfoutput>
<cfscript>
	function runFluentChain(required any builder, required string srcPath, required string chainText, required string wmFallbackPath) {
		arguments.builder.of(arguments.srcPath);
		var lines = listToArray(arguments.chainText, chr(10), false, false);
		var generated = ['thumb.of("' & arguments.srcPath & '")'];
		for (var raw in lines) {
			var line = trim(raw);
			if (!len(line)) continue;
			var parts = listToArray(line, " " & chr(9));
			if (!arrayLen(parts)) continue;
			var op = lcase(parts[1]);
			switch (op) {
				case "size":             arguments.builder.size(parts[2], parts[3]); arrayAppend(generated, ".size(" & parts[2] & "," & parts[3] & ")"); break;
				case "forcesize":        arguments.builder.forceSize(parts[2], parts[3]); arrayAppend(generated, ".forceSize(" & parts[2] & "," & parts[3] & ")"); break;
				case "width":            arguments.builder.width(parts[2]); arrayAppend(generated, ".width(" & parts[2] & ")"); break;
				case "height":           arguments.builder.height(parts[2]); arrayAppend(generated, ".height(" & parts[2] & ")"); break;
				case "scale":
					if (arrayLen(parts) gte 3) { arguments.builder.scale(parts[2], parts[3]); arrayAppend(generated, ".scale(" & parts[2] & "," & parts[3] & ")"); }
					else { arguments.builder.scale(parts[2]); arrayAppend(generated, ".scale(" & parts[2] & ")"); }
					break;
				case "rotate":           arguments.builder.rotate(parts[2]); arrayAppend(generated, ".rotate(" & parts[2] & ")"); break;
				case "crop":             arguments.builder.crop(parts[2]); arrayAppend(generated, ".crop(""" & parts[2] & """)"); break;
				case "watermark":
					if (arrayLen(parts) gte 4) { arguments.builder.watermark(arguments.wmFallbackPath, parts[2], parts[3], parts[4]); arrayAppend(generated, ".watermark(wmPath,""" & parts[2] & """," & parts[3] & "," & parts[4] & ")"); }
					else { arguments.builder.watermark(arguments.wmFallbackPath, parts[2], parts[3]); arrayAppend(generated, ".watermark(wmPath,""" & parts[2] & """," & parts[3] & ")"); }
					break;
				case "outputformat":     arguments.builder.outputFormat(parts[2]); arrayAppend(generated, ".outputFormat(""" & parts[2] & """)"); break;
				case "outputquality":    arguments.builder.outputQuality(parts[2]); arrayAppend(generated, ".outputQuality(" & parts[2] & ")"); break;
				case "scalingmode":      arguments.builder.scalingMode(parts[2]); arrayAppend(generated, ".scalingMode(""" & parts[2] & """)"); break;
				case "useexiforientation": arguments.builder.useExifOrientation(parts[2] eq "true" || parts[2] eq "yes" || parts[2] eq "1"); arrayAppend(generated, ".useExifOrientation(" & parts[2] & ")"); break;
				case "keepaspectratio":  arguments.builder.keepAspectRatio(parts[2] eq "true" || parts[2] eq "yes" || parts[2] eq "1"); arrayAppend(generated, ".keepAspectRatio(" & parts[2] & ")"); break;
				default:                 throw(type="Thumbnailator.DemoChainError", message="Unknown chain op '" & op & "' on line: " & line);
			}
		}
		return arrayToList(generated, "");
	}

	if (structKeyExists(form, "run")) {
		try {
			srcPath = demoImageDir & form.src;
			hasFmt = structKeyExists(form, "fmt") && len(form.fmt) && form.fmt neq "(original)";
			ext = hasFmt ? form.fmt : listLast(form.src, ".");
			destPath = demoOutputDir & "sandbox-" & createUUID() & "." & ext;

			opts = {};
			if (structKeyExists(form, "scaling") && len(form.scaling))            opts.scalingMode = form.scaling;
			if (structKeyExists(form, "quality") && len(form.quality))            opts.quality = form.quality;
			if (structKeyExists(form, "exif") && len(form.exif))                  opts.useExifOrientation = (form.exif eq "yes");
			if (hasFmt)                                                            opts.outputFormat = form.fmt;
			if (structKeyExists(form, "exifPassthrough") && form.exifPassthrough eq "1") opts.exifPassthrough = javacast("boolean", 1);
			if (structKeyExists(form, "allowOverwrite") && len(form.allowOverwrite))     opts.allowOverwrite = (form.allowOverwrite eq "yes");
			if (structKeyExists(form, "keepAspectRatio") && len(form.keepAspectRatio))   opts.keepAspectRatio = (form.keepAspectRatio eq "yes");

			generatedCode = "";
			wmPath = demoOutputDir & "watermark.png";

			switch (form.op) {
				case "resize":
					result = thumb.resize(srcPath, destPath, form.w, form.h, opts);
					generatedCode = 'thumb.resize(src, dest, ' & form.w & ', ' & form.h & ', ' & serializeJSON(opts) & ');';
					break;
				case "scale":
					result = thumb.scaleImage(srcPath, destPath, form.factor, opts);
					generatedCode = 'thumb.scaleImage(src, dest, ' & form.factor & ', ' & serializeJSON(opts) & ');';
					break;
				case "rotate":
					result = thumb.rotateImage(srcPath, destPath, form.degrees, opts);
					generatedCode = 'thumb.rotateImage(src, dest, ' & form.degrees & ', ' & serializeJSON(opts) & ');';
					break;
				case "crop":
					result = thumb.cropImage(srcPath, destPath, form.w, form.h, form.position, opts);
					generatedCode = 'thumb.cropImage(src, dest, ' & form.w & ', ' & form.h & ', "' & form.position & '", ' & serializeJSON(opts) & ');';
					break;
				case "watermark":
					wmOpts = duplicate(opts);
					if (structKeyExists(form, "insets") && len(form.insets)) {
						wmOpts.insets = form.insets;
						result = thumb.watermarkImage(srcPath, destPath, wmPath, form.position, form.opacity, form.insets, wmOpts);
						generatedCode = 'thumb.watermarkImage(src, dest, wmPath, "' & form.position & '", ' & form.opacity & ', ' & form.insets & ', ' & serializeJSON(wmOpts) & ');';
					} else {
						/* Call via argumentCollection to skip the positional insets arg cleanly. */
						wmArgs = ["srcPath": srcPath, "destPath": destPath, "wmPath": wmPath, "positionName": form.position, "opacity": form.opacity, "opts": wmOpts];
						result = thumb.watermarkImage(argumentCollection = wmArgs);
						generatedCode = 'thumb.watermarkImage(src, dest, wmPath, "' & form.position & '", ' & form.opacity & ', /*insets omitted*/ ' & serializeJSON(wmOpts) & ');';
					}
					break;
				case "sourceRegion":
					thumb.of(srcPath).sourceRegion(form.rx, form.ry, form.rw, form.rh).size(form.w, form.h);
					if (hasFmt) thumb.outputFormat(form.fmt);
					if (structKeyExists(form, "quality") && len(form.quality))  thumb.outputQuality(form.quality);
					if (structKeyExists(form, "scaling") && len(form.scaling))  thumb.scalingMode(form.scaling);
					if (structKeyExists(form, "exif") && len(form.exif))        thumb.useExifOrientation(form.exif eq "yes");
					if (structKeyExists(form, "keepAspectRatio") && len(form.keepAspectRatio)) thumb.keepAspectRatio(form.keepAspectRatio eq "yes");
					if (structKeyExists(form, "allowOverwrite") && len(form.allowOverwrite))   thumb.allowOverwrite(form.allowOverwrite eq "yes");
					result = thumb.toFile(destPath);
					generatedCode = 'thumb.of(src).sourceRegion(' & form.rx & ',' & form.ry & ',' & form.rw & ',' & form.rh & ').size(' & form.w & ',' & form.h & ').toFile(dest);';
					break;
				case "convertFormat":
					cfOpts = duplicate(opts);
					if (structKeyExists(cfOpts, "outputFormat")) structDelete(cfOpts, "outputFormat");
					cfFmt = hasFmt ? form.fmt : "jpg";
					result = thumb.convertFormat(srcPath, destPath, cfFmt, cfOpts);
					generatedCode = 'thumb.convertFormat(src, dest, "' & cfFmt & '", ' & serializeJSON(cfOpts) & ');';
					break;
				case "fluent-chain":
					generatedCode = runFluentChain(thumb, srcPath, form.chain, wmPath) & ".toFile(dest);";
					result = thumb.toFile(destPath);
					break;
				default:
					throw(type="Thumbnailator.DemoError", message="Unsupported operation: " & form.op);
			}

			srcInfo = thumb.inspect(srcPath);
			resultUrl = "demo-output/" & listLast(result.destPath, "/\");
			srcUrl    = "demo-images/" & form.src;

			writeOutput("<h2>Result</h2><div class='result'>");
			writeOutput("<div><div class='meta'>source: " & srcInfo.width & "x" & srcInfo.height & " - " & humanSize(srcInfo.sizeBytes) & " - " & encodeForHTML(srcInfo.format) & "</div><img src='" & encodeForHTMLAttribute(srcUrl) & "' alt=''></div>");
			writeOutput("<div><div class='meta'>result: " & result.width & "x" & result.height & " - " & humanSize(result.sizeBytes) & " - " & encodeForHTML(result.format) & " - " & result.durationMs & " ms</div><img src='" & encodeForHTMLAttribute(resultUrl) & "' alt=''></div>");
			writeOutput("</div>");
			writeOutput("<h3>Generated CFC code</h3><pre style='background:##2d2d2d;color:##eee;padding:0.8em;overflow-x:auto'>" & encodeForHTML(generatedCode) & "</pre>");
		} catch (any e) {
			writeOutput("<div class='error'><b>" & encodeForHTML(e.type) & ":</b> " & encodeForHTML(e.message) & "<br><small>" & encodeForHTML(e.detail) & "</small></div>");
		}
	}
</cfscript>
<script>
(function() {
	function setToggle(btn, on) {
		var row = btn.closest('.field-row');
		btn.classList.toggle('on', on);
		btn.classList.toggle('off', !on);
		btn.textContent = on ? 'on' : 'off';
		if (row) row.classList.toggle('field-inactive', !on);
		var inputs = row ? row.querySelectorAll('input, select, textarea') : [];
		for (var i = 0; i < inputs.length; i++) inputs[i].disabled = !on;
	}
	var btns = document.querySelectorAll('.toggle');
	for (var b = 0; b < btns.length; b++) {
		(function(btn) {
			setToggle(btn, btn.classList.contains('on'));
			btn.addEventListener('click', function(e) {
				e.preventDefault();
				setToggle(btn, !btn.classList.contains('on'));
			});
		})(btns[b]);
	}
})();
</script>
</body></html>
