<cfsetting requesttimeout="120">
<cfprocessingdirective pageEncoding="utf-8">
<cfcontent type="text/html; charset=utf-8">
<cfscript>
	setEncoding("form", "utf-8");
	setEncoding("url", "utf-8");

	demoImageDir = expandPath("./demo-images/");
	compareOutDir = expandPath("./demo-output/compare/");
	if (!directoryExists(compareOutDir)) createObject("java","java.io.File").init(javacast("string", compareOutDir)).mkdirs();

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

	function envOrDefault(required string name, required string fallback) {
		var sys = createObject("java", "java.lang.System");
		var v = "";
		try {
			v = sys.getenv(javacast("string", arguments.name));
			if (isNull(v)) v = "";
		} catch (any e) {
			v = "";
		}
		if (len(v)) return v;
		return arguments.fallback;
	}

	function nowNanos() {
		return createObject("java", "java.lang.System").nanoTime();
	}

	function elapsedMs(required numeric startNanos) {
		return numberFormat((nowNanos() - arguments.startNanos) / 1000000, "0.00");
	}

	function fileSizeOrZero(required string path) {
		if (!fileExists(arguments.path)) return 0;
		return createObject("java", "java.io.File").init(arguments.path).length();
	}

	imBin = envOrDefault("IMAGEMAGICK_BIN", "C:\CFusionExtra\ImageMagick\magick.exe");
	gmBin = envOrDefault("GRAPHICSMAGICK_BIN", "C:\CFusionExtra\GraphicsMagick\gm.exe");

	imAvailable = fileExists(imBin);
	gmAvailable = fileExists(gmBin);

	cfimageAvailable = true;
	cfimageReason = "";
	try {
		_probe = imageNew("", 1, 1, "rgb");
	} catch (any e) {
		cfimageAvailable = false;
		cfimageReason = e.message;
	}

	function listDemoImages(required string dir) {
		if (!directoryExists(arguments.dir)) return [];
		var raw = directoryList(arguments.dir, false, "name");
		var out = [];
		for (var n in raw) if (reFindNoCase("\.(png|jpe?g|gif|bmp)$", n)) arrayAppend(out, n);
		return out;
	}

	function runExternal(required string bin, required string argString) {
		var stdout = "";
		try {
			cfexecute(name=arguments.bin, arguments=arguments.argString, timeout=60, variable="stdout");
		} catch (any e) {
			return ["ok": false, "out": "EXEC ERROR: " & e.message];
		}
		return ["ok": true, "out": stdout];
	}

	function runThumbResize(required string src, required string dest) {
		var thumb = new Thumbnailator();
		var t0 = nowNanos();
		try {
			thumb.resize(arguments.src, arguments.dest, 320, 240, ["quality": 0.85, "outputFormat": "jpg"]);
		} catch (any e) {
			return ["ok": false, "ms": elapsedMs(t0), "size": 0, "path": arguments.dest, "note": "ERROR: " & e.message];
		}
		return ["ok": fileExists(arguments.dest), "ms": elapsedMs(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ""];
	}

	function runThumbRotate(required string src, required string dest) {
		var thumb = new Thumbnailator();
		var t0 = nowNanos();
		try {
			thumb.rotateImage(arguments.src, arguments.dest, 90);
		} catch (any e) {
			return ["ok": false, "ms": elapsedMs(t0), "size": 0, "path": arguments.dest, "note": "ERROR: " & e.message];
		}
		return ["ok": fileExists(arguments.dest), "ms": elapsedMs(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ""];
	}

	function runThumbConvert(required string src, required string dest) {
		var thumb = new Thumbnailator();
		var t0 = nowNanos();
		try {
			thumb.convertFormat(arguments.src, arguments.dest, "jpg", ["quality": 0.85]);
		} catch (any e) {
			return ["ok": false, "ms": elapsedMs(t0), "size": 0, "path": arguments.dest, "note": "ERROR: " & e.message];
		}
		return ["ok": fileExists(arguments.dest), "ms": elapsedMs(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ""];
	}

	function runCfimageResize(required string src, required string dest) {
		var t0 = nowNanos();
		try {
			var img = imageNew(arguments.src);
			imageResize(img, 320, 240, "highestQuality");
			imageWrite(img, arguments.dest, 0.85);
		} catch (any e) {
			return ["ok": false, "ms": elapsedMs(t0), "size": 0, "path": arguments.dest, "note": "n/a: " & e.message];
		}
		return ["ok": fileExists(arguments.dest), "ms": elapsedMs(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ""];
	}

	function runCfimageRotate(required string src, required string dest) {
		var t0 = nowNanos();
		try {
			var img = imageNew(arguments.src);
			imageRotate(img, 90);
			imageWrite(img, arguments.dest);
		} catch (any e) {
			return ["ok": false, "ms": elapsedMs(t0), "size": 0, "path": arguments.dest, "note": "n/a: " & e.message];
		}
		return ["ok": fileExists(arguments.dest), "ms": elapsedMs(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ""];
	}

	function runCfimageConvert(required string src, required string dest) {
		var t0 = nowNanos();
		try {
			imageWrite(imageNew(arguments.src), arguments.dest, 0.85);
		} catch (any e) {
			return ["ok": false, "ms": elapsedMs(t0), "size": 0, "path": arguments.dest, "note": "n/a: " & e.message];
		}
		return ["ok": fileExists(arguments.dest), "ms": elapsedMs(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ""];
	}

	function runImResize(required string bin, required string src, required string dest) {
		var t0 = nowNanos();
		var r = runExternal(arguments.bin, '"' & arguments.src & '" -resize 320x240 -quality 85 "' & arguments.dest & '"');
		var ok = r.ok && fileExists(arguments.dest);
		return ["ok": ok, "ms": elapsedMs(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ok ? "" : ("ERROR: " & r.out)];
	}

	function runImRotate(required string bin, required string src, required string dest) {
		var t0 = nowNanos();
		var r = runExternal(arguments.bin, '"' & arguments.src & '" -rotate 90 "' & arguments.dest & '"');
		var ok = r.ok && fileExists(arguments.dest);
		return ["ok": ok, "ms": elapsedMs(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ok ? "" : ("ERROR: " & r.out)];
	}

	function runImConvert(required string bin, required string src, required string dest) {
		var t0 = nowNanos();
		var r = runExternal(arguments.bin, '"' & arguments.src & '" -quality 85 "' & arguments.dest & '"');
		var ok = r.ok && fileExists(arguments.dest);
		return ["ok": ok, "ms": elapsedMs(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ok ? "" : ("ERROR: " & r.out)];
	}

	function runGmResize(required string bin, required string src, required string dest) {
		var t0 = nowNanos();
		var r = runExternal(arguments.bin, 'convert "' & arguments.src & '" -resize 320x240 -quality 85 "' & arguments.dest & '"');
		var ok = r.ok && fileExists(arguments.dest);
		return ["ok": ok, "ms": elapsedMs(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ok ? "" : ("ERROR: " & r.out)];
	}

	function runGmRotate(required string bin, required string src, required string dest) {
		var t0 = nowNanos();
		var r = runExternal(arguments.bin, 'convert "' & arguments.src & '" -rotate 90 "' & arguments.dest & '"');
		var ok = r.ok && fileExists(arguments.dest);
		return ["ok": ok, "ms": elapsedMs(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ok ? "" : ("ERROR: " & r.out)];
	}

	function runGmConvert(required string bin, required string src, required string dest) {
		var t0 = nowNanos();
		var r = runExternal(arguments.bin, 'convert "' & arguments.src & '" -quality 85 "' & arguments.dest & '"');
		var ok = r.ok && fileExists(arguments.dest);
		return ["ok": ok, "ms": elapsedMs(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ok ? "" : ("ERROR: " & r.out)];
	}

	demoImages = listDemoImages(demoImageDir);
	formSrc = (structKeyExists(form, "src") && len(form.src) && fileExists(demoImageDir & form.src)) ? form.src : "starter.png";
</cfscript>
<!doctype html>
<html><head>
	<meta charset="utf-8">
	<title>Thumbnailator - tool comparison</title>
	<style>
		body { font-family: -apple-system, Segoe UI, sans-serif; max-width: 1100px; margin: 1em auto; padding: 0 1em; }
		h1, h2 { border-bottom: 1px solid #ccc; padding-bottom: 0.3em; }
		.serverinfo { background:#f4f4f4; border:1px solid #ccc; padding:0.6em 0.8em; margin:0.6em 0 1.4em; font-size:0.95em; color:#333; font-family:monospace; }
		.tools { background:#f7f7f0; border:1px solid #ddd; padding:0.6em 0.8em; margin: 0.6em 0 1em; font-family:monospace; font-size:0.9em; }
		.tools .ok { color:#070; }
		.tools .no { color:#900; }
		form { background: #f0f0f0; padding: 1em; border-radius: 4px; }
		form label { display:inline-block; min-width:9em; }
		table { border-collapse: collapse; width: 100%; margin: 0.6em 0 1.4em; font-size: 0.92em; }
		th, td { border: 1px solid #ccc; padding: 0.35em 0.6em; text-align: left; }
		th { background: #eee; }
		td.num { text-align: right; font-variant-numeric: tabular-nums; }
		td.path { font-family: monospace; font-size: 0.85em; color: #555; word-break: break-all; }
		.err { color:#900; font-style:italic; }
		.note { color:#555; font-size:0.85em; }
	</style>
</head>
<body>
<h1>Thumbnailator - tool comparison</h1>
<div class="serverinfo"><cfoutput>#encodeForHTML(serverInfo())#</cfoutput></div>
<p class="note">Single-run snapshot, not a rigorous benchmark. Numbers vary across cold/warm runs and OS file-cache state. Each operation runs once.</p>

<div class="tools">
<cfoutput>
	<div>Thumbnailator: <span class="ok">available (bundled JAR)</span></div>
	<div>cfimage: <cfif cfimageAvailable><span class="ok">available</span><cfelse><span class="no">not available</span> <span class="note">(#encodeForHTML(cfimageReason)#)</span></cfif></div>
	<div>ImageMagick: <cfif imAvailable><span class="ok">#encodeForHTML(imBin)#</span><cfelse><span class="no">not available</span> <span class="note">(checked #encodeForHTML(imBin)#)</span></cfif></div>
	<div>GraphicsMagick: <cfif gmAvailable><span class="ok">#encodeForHTML(gmBin)#</span><cfelse><span class="no">not available</span> <span class="note">(checked #encodeForHTML(gmBin)#)</span></cfif></div>
</cfoutput>
</div>

<form method="post">
	<label for="src">Source image:</label>
	<select name="src" id="src">
		<cfoutput>
		<cfloop array="#demoImages#" index="img">
			<option value="#encodeForHTMLAttribute(img)#"<cfif img eq formSrc> selected</cfif>>#encodeForHTML(img)#</option>
		</cfloop>
		</cfoutput>
	</select>
	<button type="submit" name="run" value="1">Run comparison</button>
</form>

<cfif structKeyExists(form, "run")>
	<cfscript>
		srcPath = demoImageDir & formSrc;
		srcBase = listFirst(formSrc, ".");
		srcExt  = listLast(formSrc, ".");
		stamp   = createUUID();

		/* Build dest paths */
		resizeDest = [
			"thumb": compareOutDir & srcBase & "-" & stamp & "-resize-thumb.jpg",
			"cfimage": compareOutDir & srcBase & "-" & stamp & "-resize-cfimage.jpg",
			"im":      compareOutDir & srcBase & "-" & stamp & "-resize-im.jpg",
			"gm":      compareOutDir & srcBase & "-" & stamp & "-resize-gm.jpg"
		];
		rotateDest = [
			"thumb": compareOutDir & srcBase & "-" & stamp & "-rotate-thumb." & srcExt,
			"cfimage": compareOutDir & srcBase & "-" & stamp & "-rotate-cfimage." & srcExt,
			"im":      compareOutDir & srcBase & "-" & stamp & "-rotate-im." & srcExt,
			"gm":      compareOutDir & srcBase & "-" & stamp & "-rotate-gm." & srcExt
		];
		convertDest = [
			"thumb": compareOutDir & srcBase & "-" & stamp & "-convert-thumb.jpg",
			"cfimage": compareOutDir & srcBase & "-" & stamp & "-convert-cfimage.jpg",
			"im":      compareOutDir & srcBase & "-" & stamp & "-convert-im.jpg",
			"gm":      compareOutDir & srcBase & "-" & stamp & "-convert-gm.jpg"
		];

		/* Run each transformation across all four tools */
		results = [
			"resize": [
				"Thumbnailator":   runThumbResize(srcPath, resizeDest.thumb),
				"cfimage":         cfimageAvailable ? runCfimageResize(srcPath, resizeDest.cfimage) : ["ok": false, "ms": "-", "size": 0, "path": "", "note": "not supported on engine"],
				"ImageMagick":     imAvailable ? runImResize(imBin, srcPath, resizeDest.im) : ["ok": false, "ms": "-", "size": 0, "path": "", "note": "not available"],
				"GraphicsMagick":  gmAvailable ? runGmResize(gmBin, srcPath, resizeDest.gm) : ["ok": false, "ms": "-", "size": 0, "path": "", "note": "not available"]
			],
			"rotate": [
				"Thumbnailator":   runThumbRotate(srcPath, rotateDest.thumb),
				"cfimage":         cfimageAvailable ? runCfimageRotate(srcPath, rotateDest.cfimage) : ["ok": false, "ms": "-", "size": 0, "path": "", "note": "not supported on engine"],
				"ImageMagick":     imAvailable ? runImRotate(imBin, srcPath, rotateDest.im) : ["ok": false, "ms": "-", "size": 0, "path": "", "note": "not available"],
				"GraphicsMagick":  gmAvailable ? runGmRotate(gmBin, srcPath, rotateDest.gm) : ["ok": false, "ms": "-", "size": 0, "path": "", "note": "not available"]
			],
			"convert": [
				"Thumbnailator":   runThumbConvert(srcPath, convertDest.thumb),
				"cfimage":         cfimageAvailable ? runCfimageConvert(srcPath, convertDest.cfimage) : ["ok": false, "ms": "-", "size": 0, "path": "", "note": "not supported on engine"],
				"ImageMagick":     imAvailable ? runImConvert(imBin, srcPath, convertDest.im) : ["ok": false, "ms": "-", "size": 0, "path": "", "note": "not available"],
				"GraphicsMagick":  gmAvailable ? runGmConvert(gmBin, srcPath, convertDest.gm) : ["ok": false, "ms": "-", "size": 0, "path": "", "note": "not available"]
			]
		];

		labels = [
			"resize":  "Resize 320x240, JPEG q=0.85",
			"rotate":  "Rotate 90 degrees (keeps source format)",
			"convert": "Convert format: input -> JPEG q=0.85"
		];

		function renderTable(required string title, required struct rows) {
			writeOutput("<h2>" & encodeForHTML(arguments.title) & "</h2>");
			writeOutput("<table><thead><tr><th>Tool</th><th>Output path</th><th>Output size</th><th>Elapsed (ms)</th></tr></thead><tbody>");
			var order = ["Thumbnailator", "cfimage", "ImageMagick", "GraphicsMagick"];
			for (var tool in order) {
				var row = arguments.rows[tool];
				writeOutput("<tr>");
				writeOutput("<td>" & encodeForHTML(tool) & "</td>");
				if (row.ok) {
					var fileName = listLast(row.path, "/\");
					var rel = "demo-output/compare/" & fileName;
					writeOutput("<td class='path'><a href='" & encodeForHTMLAttribute(rel) & "' target='_blank'>" & encodeForHTML(fileName) & "</a></td>");
					writeOutput("<td class='num'>" & encodeForHTML(humanSize(row.size)) & "</td>");
					writeOutput("<td class='num'>" & encodeForHTML(row.ms) & "</td>");
				} else {
					writeOutput("<td class='err' colspan='3'>" & encodeForHTML(row.note) & "</td>");
				}
				writeOutput("</tr>");
			}
			writeOutput("</tbody></table>");
		}

		renderTable(labels.resize,  results.resize);
		renderTable(labels.rotate,  results.rotate);
		renderTable(labels.convert, results.convert);
	</cfscript>
</cfif>

</body></html>
