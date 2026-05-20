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

	function elapsedMsFromNanos(required numeric startNanos) {
		return (nowNanos() - arguments.startNanos) / 1000000;
	}

	function formatMs(required numeric ms) {
		return numberFormat(arguments.ms, "0.00");
	}

	function fileSizeOrZero(required string path) {
		if (!fileExists(arguments.path)) return 0;
		return createObject("java", "java.io.File").init(arguments.path).length();
	}

	/* Create a 400x300 JPEG with three colored bars and "EXIF orientation test" text,
	   then splice in an EXIF APP1 segment carrying Orientation, Make, Model.
	   Falls back to single-tag (Orientation only) variant if the 3-tag splice fails. */
	function ensureStarterExifImage(required string dir) {
		var outPath = arguments.dir & "starter-exif.jpg";
		if (fileExists(outPath)) return outPath;
		if (!directoryExists(arguments.dir)) createObject("java","java.io.File").init(javacast("string", arguments.dir)).mkdirs();

		/* Draw a recognizable 400x300 JPEG that differs from starter.png */
		var bi = createObject("java", "java.awt.image.BufferedImage").init(javacast("int", 400), javacast("int", 300), javacast("int", 1));
		var g = bi.createGraphics();
		try {
			g.setColor(createObject("java", "java.awt.Color").init(javacast("int", 240), javacast("int", 240), javacast("int", 240)));
			g.fillRect(javacast("int", 0), javacast("int", 0), javacast("int", 400), javacast("int", 300));
			g.setColor(createObject("java", "java.awt.Color").init(javacast("int", 200), javacast("int", 50), javacast("int", 50)));
			g.fillRect(javacast("int", 0), javacast("int", 40), javacast("int", 400), javacast("int", 60));
			g.setColor(createObject("java", "java.awt.Color").init(javacast("int", 50), javacast("int", 160), javacast("int", 50)));
			g.fillRect(javacast("int", 0), javacast("int", 120), javacast("int", 400), javacast("int", 60));
			g.setColor(createObject("java", "java.awt.Color").init(javacast("int", 50), javacast("int", 90), javacast("int", 200)));
			g.fillRect(javacast("int", 0), javacast("int", 200), javacast("int", 400), javacast("int", 60));
			g.setColor(createObject("java", "java.awt.Color").BLACK);
			g.setFont(createObject("java", "java.awt.Font").init(javacast("string", "SansSerif"), javacast("int", 1), javacast("int", 22)));
			g.drawString(javacast("string", "EXIF orientation test"), javacast("int", 70), javacast("int", 30));
		} finally {
			g.dispose();
		}
		createObject("java", "javax.imageio.ImageIO").write(bi, javacast("string", "jpg"), createObject("java", "java.io.File").init(outPath));

		/* Try the 3-tag splicer first; if anything goes wrong, fall back to single-tag */
		var ok = false;
		try {
			spliceExifThreeTags(outPath);
			ok = true;
		} catch (any e) {
			ok = false;
		}
		if (!ok) {
			try {
				spliceExifOrientationOnly(outPath, 1);
			} catch (any e2) {
				/* If even the simple splice fails, the JPEG is still there without EXIF */
			}
		}
		return outPath;
	}

	/* Splice a multi-tag (Orientation, Make, Model) EXIF APP1 into a JPEG in place.
	   Throws on any I/O or layout error so the caller can fall back. */
	function spliceExifThreeTags(required string path) {
		var fis = createObject("java", "java.io.FileInputStream").init(arguments.path);
		var fLen = createObject("java", "java.io.File").init(arguments.path).length();
		var jReflectArray = createObject("java", "java.lang.reflect.Array");
		var orig = jReflectArray.newInstance(createObject("java", "java.lang.Byte").TYPE, javacast("int", fLen));
		fis.read(orig);
		fis.close();

		/* IFD layout (3 entries):
		     entry0 tag=0x0112 Orientation, SHORT, count=1, value=1 (inline)
		     entry1 tag=0x010F Make, ASCII, count=19, value="thumbnailator-demo\0" (offset)
		     entry2 tag=0x0110 Model, ASCII, count=12, value="synthesized\0" (offset)

		   TIFF header starts at segment offset 10 (after marker + length + "Exif\0\0").
		   IFD0 lives at TIFF-relative offset 8.
		     IFD: 2 (count) + 12*3 (entries) + 4 (next IFD) = 42 bytes
		     IFD occupies TIFF offsets 8..49 inclusive (end-exclusive = 50)
		   Value-data area starts at TIFF-relative offset 50.
		     Make value: 19 bytes (ASCII "thumbnailator-demo" + NUL), tiff offset 50, length 19
		     Model value: 12 bytes (ASCII "synthesized" + NUL), tiff offset 69, length 12
		   Total TIFF payload = 50 + 19 + 12 = 81 bytes.
		   APP1 segment size = 6 ("Exif\0\0") + 81 = 87 bytes of payload + 2 length bytes = 89
		   So segment length field = 89. Total APP1 segment incl. FF E1 marker = 91 bytes. */

		var makeStr = "thumbnailator-demo";
		var modelStr = "synthesized";
		var makeLen = len(makeStr) + 1;
		var modelLen = len(modelStr) + 1;

		var tiffMakeOffset = 50;
		var tiffModelOffset = tiffMakeOffset + makeLen;
		var tiffPayloadLen = tiffModelOffset + modelLen;
		var segLen = 6 + tiffPayloadLen + 2;

		var seg = [
			255, 225,
			bitAnd(int(segLen / 256), 255), bitAnd(segLen, 255),
			69, 120, 105, 102, 0, 0,
			73, 73, 42, 0,
			8, 0, 0, 0,
			3, 0,
			18, 1, 3, 0, 1, 0, 0, 0, 1, 0, 0, 0,
			15, 1, 2, 0,
				bitAnd(makeLen, 255), bitAnd(int(makeLen / 256), 255), bitAnd(int(makeLen / 65536), 255), bitAnd(int(makeLen / 16777216), 255),
				bitAnd(tiffMakeOffset, 255), bitAnd(int(tiffMakeOffset / 256), 255), bitAnd(int(tiffMakeOffset / 65536), 255), bitAnd(int(tiffMakeOffset / 16777216), 255),
			16, 1, 2, 0,
				bitAnd(modelLen, 255), bitAnd(int(modelLen / 256), 255), bitAnd(int(modelLen / 65536), 255), bitAnd(int(modelLen / 16777216), 255),
				bitAnd(tiffModelOffset, 255), bitAnd(int(tiffModelOffset / 256), 255), bitAnd(int(tiffModelOffset / 65536), 255), bitAnd(int(tiffModelOffset / 16777216), 255),
			0, 0, 0, 0
		];

		var i = 0;
		for (i = 1; i lte makeLen - 1; i++) arrayAppend(seg, asc(mid(makeStr, i, 1)));
		arrayAppend(seg, 0);
		for (i = 1; i lte modelLen - 1; i++) arrayAppend(seg, asc(mid(modelStr, i, 1)));
		arrayAppend(seg, 0);

		writeSplicedJpeg(arguments.path, orig, fLen, seg);
	}

	/* Splice a single-tag (Orientation only) EXIF APP1 (35-byte ported layout from _testHelper). */
	function spliceExifOrientationOnly(required string path, required numeric orientation) {
		var fis = createObject("java", "java.io.FileInputStream").init(arguments.path);
		var fLen = createObject("java", "java.io.File").init(arguments.path).length();
		var jReflectArray = createObject("java", "java.lang.reflect.Array");
		var orig = jReflectArray.newInstance(createObject("java", "java.lang.Byte").TYPE, javacast("int", fLen));
		fis.read(orig);
		fis.close();

		var orient = javacast("int", arguments.orientation);
		var orientLo = bitAnd(orient, 255);
		var orientHi = bitAnd(int(orient / 256), 255);

		var seg = [
			255, 225,
			0, 34,
			69, 120, 105, 102, 0, 0,
			73, 73, 42, 0,
			8, 0, 0, 0,
			1, 0,
			18, 1,
			3, 0,
			1, 0, 0, 0,
			orientLo, orientHi, 0, 0,
			0, 0, 0, 0
		];

		writeSplicedJpeg(arguments.path, orig, fLen, seg);
	}

	/* Strip the original APP0 (FFE0) and insert the supplied APP1 segment after SOI. */
	function writeSplicedJpeg(required string path, required any orig, required numeric fLen, required array seg) {
		var jReflectArray = createObject("java", "java.lang.reflect.Array");
		var app0Len = bitOr(bitShln(bitAnd(jReflectArray.getByte(arguments.orig, javacast("int", 4)), 255), 8), bitAnd(jReflectArray.getByte(arguments.orig, javacast("int", 5)), 255));

		var newLen = 2 + arrayLen(arguments.seg) + (arguments.fLen - 4 - app0Len);
		var out = jReflectArray.newInstance(createObject("java", "java.lang.Byte").TYPE, javacast("int", newLen));

		jReflectArray.setByte(out, javacast("int", 0), jReflectArray.getByte(arguments.orig, javacast("int", 0)));
		jReflectArray.setByte(out, javacast("int", 1), jReflectArray.getByte(arguments.orig, javacast("int", 1)));

		var idx = 2;
		var i = 0;
		for (i = 1; i lte arrayLen(arguments.seg); i++) {
			var b = arguments.seg[i];
			if (b gt 127) b = b - 256;
			jReflectArray.setByte(out, javacast("int", idx), javacast("byte", javacast("int", b)));
			idx++;
		}
		for (i = 4 + app0Len; i lt arguments.fLen; i++) {
			jReflectArray.setByte(out, javacast("int", idx), jReflectArray.getByte(arguments.orig, javacast("int", i)));
			idx++;
		}

		var fos = createObject("java", "java.io.FileOutputStream").init(arguments.path);
		try {
			fos.write(out);
		} finally {
			fos.close();
		}
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

	/* Probe for imageGetEXIFMetadata - BoxLang may not implement it.
	   Wrapped in a function so `var` is legal at any engine. */
	function probeExifFunction() {
		var result = ["available": true, "reason": ""];
		try {
			var probeImg = imageNew("", 1, 1, "rgb");
			imageGetEXIFMetadata(probeImg);
		} catch (any e) {
			var msg = lcase(e.message & " " & (structKeyExists(e, "detail") ? e.detail : ""));
			if (findNoCase("undefined function", msg) || findNoCase("not implemented", msg) || findNoCase("no such function", msg) || findNoCase("undefined method", msg) || findNoCase("could not find a method named", msg)) {
				result.available = false;
				result.reason = e.message;
			}
			/* Any other error (eg "no EXIF data on this image") means the function exists. */
		}
		return result;
	}
	exifProbe = probeExifFunction();
	exifFnAvailable = exifProbe.available;
	exifFnReason = exifProbe.reason;

	function readExifSafe(required string path) {
		if (!exifFnAvailable) return ["__error__": "fn-missing"];
		if (!fileExists(arguments.path)) return ["__error__": "file-missing"];
		try {
			var meta = imageGetEXIFMetadata(imageNew(arguments.path));
			if (isNull(meta) || !isStruct(meta)) return [:];
			return meta;
		} catch (any e) {
			return ["__error__": e.message];
		}
	}

	function normalizeExifKey(required string k) {
		return lcase(reReplace(arguments.k, "[^A-Za-z0-9]", "", "all"));
	}

	function exifSignificantPairs(required struct s) {
		var out = [:];
		var noise = "rawmetadata,exif_iddata,exifsubidd,nativemetadata,height,width,colormodel";
		for (var k in arguments.s) {
			if (k eq "__error__") continue;
			var nk = normalizeExifKey(k);
			if (listFindNoCase(noise, nk)) continue;
			var v = arguments.s[k];
			if (isSimpleValue(v)) {
				var sv = trim(toString(v));
				if (len(sv)) out[nk] = sv;
			}
		}
		return out;
	}

	function compareExif(required struct srcStruct, required struct destStruct) {
		if (structKeyExists(arguments.destStruct, "__error__") && arguments.destStruct.__error__ eq "fn-missing") return "n/a";
		var srcPairs = exifSignificantPairs(arguments.srcStruct);
		if (!structCount(srcPairs)) return "source-none";
		if (structKeyExists(arguments.destStruct, "__error__")) return "lost";
		var destPairs = exifSignificantPairs(arguments.destStruct);
		if (!structCount(destPairs)) return "lost";
		for (var k in srcPairs) {
			if (structKeyExists(destPairs, k) && destPairs[k] eq srcPairs[k]) return "preserved";
		}
		return "lost";
	}

	function exifCellHtml(required string status, required string engineLabel) {
		switch (arguments.status) {
			case "preserved": return "<span style='color:##070;font-weight:bold'>preserved</span>";
			case "lost":      return "<span style='color:##900;font-weight:bold'>lost</span>";
			case "source-none": return "<span style='color:##888'>source has none</span>";
			case "n/a":       return "<span style='color:##888'>n/a (" & encodeForHTML(arguments.engineLabel) & ")</span>";
		}
		return encodeForHTML(arguments.status);
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

	/* Each runner returns: ["ok": bool, "ms": numeric, "size": numeric, "path": string, "note": string] */

	function thumbExifFlagOn() {
		return structKeyExists(request, "thumbExifPassthrough") && request.thumbExifPassthrough;
	}

	function runThumbResize(required string src, required string dest) {
		var thumb = new Thumbnailator();
		var t0 = nowNanos();
		var opts = ["quality": 0.85, "outputFormat": "jpg"];
		if (thumbExifFlagOn()) opts["exifPassthrough"] = true;
		try {
			thumb.resize(arguments.src, arguments.dest, 320, 240, opts);
		} catch (any e) {
			return ["ok": false, "ms": elapsedMsFromNanos(t0), "size": 0, "path": arguments.dest, "note": "ERROR: " & e.message];
		}
		return ["ok": fileExists(arguments.dest), "ms": elapsedMsFromNanos(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ""];
	}

	function runThumbRotate(required string src, required string dest) {
		var thumb = new Thumbnailator();
		var t0 = nowNanos();
		var opts = {};
		if (thumbExifFlagOn()) opts["exifPassthrough"] = true;
		try {
			thumb.rotateImage(arguments.src, arguments.dest, 90, opts);
		} catch (any e) {
			return ["ok": false, "ms": elapsedMsFromNanos(t0), "size": 0, "path": arguments.dest, "note": "ERROR: " & e.message];
		}
		return ["ok": fileExists(arguments.dest), "ms": elapsedMsFromNanos(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ""];
	}

	function runThumbConvert(required string src, required string dest) {
		var thumb = new Thumbnailator();
		var t0 = nowNanos();
		var opts = ["quality": 0.85];
		if (thumbExifFlagOn()) opts["exifPassthrough"] = true;
		try {
			thumb.convertFormat(arguments.src, arguments.dest, "jpg", opts);
		} catch (any e) {
			return ["ok": false, "ms": elapsedMsFromNanos(t0), "size": 0, "path": arguments.dest, "note": "ERROR: " & e.message];
		}
		return ["ok": fileExists(arguments.dest), "ms": elapsedMsFromNanos(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ""];
	}

	function runCfimageResize(required string src, required string dest) {
		var t0 = nowNanos();
		try {
			var img = imageNew(arguments.src);
			imageResize(img, 320, 240, "highestQuality");
			imageWrite(img, arguments.dest, 0.85);
		} catch (any e) {
			return ["ok": false, "ms": elapsedMsFromNanos(t0), "size": 0, "path": arguments.dest, "note": "n/a: " & e.message];
		}
		return ["ok": fileExists(arguments.dest), "ms": elapsedMsFromNanos(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ""];
	}

	function runCfimageRotate(required string src, required string dest) {
		var t0 = nowNanos();
		try {
			var img = imageNew(arguments.src);
			imageRotate(img, 90);
			imageWrite(img, arguments.dest);
		} catch (any e) {
			return ["ok": false, "ms": elapsedMsFromNanos(t0), "size": 0, "path": arguments.dest, "note": "n/a: " & e.message];
		}
		return ["ok": fileExists(arguments.dest), "ms": elapsedMsFromNanos(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ""];
	}

	function runCfimageConvert(required string src, required string dest) {
		var t0 = nowNanos();
		try {
			imageWrite(imageNew(arguments.src), arguments.dest, 0.85);
		} catch (any e) {
			return ["ok": false, "ms": elapsedMsFromNanos(t0), "size": 0, "path": arguments.dest, "note": "n/a: " & e.message];
		}
		return ["ok": fileExists(arguments.dest), "ms": elapsedMsFromNanos(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ""];
	}

	function runImResize(required string bin, required string src, required string dest) {
		var t0 = nowNanos();
		var r = runExternal(arguments.bin, '"' & arguments.src & '" -resize 320x240 -quality 85 "' & arguments.dest & '"');
		var ok = r.ok && fileExists(arguments.dest);
		return ["ok": ok, "ms": elapsedMsFromNanos(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ok ? "" : ("ERROR: " & r.out)];
	}

	function runImRotate(required string bin, required string src, required string dest) {
		var t0 = nowNanos();
		var r = runExternal(arguments.bin, '"' & arguments.src & '" -rotate 90 "' & arguments.dest & '"');
		var ok = r.ok && fileExists(arguments.dest);
		return ["ok": ok, "ms": elapsedMsFromNanos(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ok ? "" : ("ERROR: " & r.out)];
	}

	function runImConvert(required string bin, required string src, required string dest) {
		var t0 = nowNanos();
		var r = runExternal(arguments.bin, '"' & arguments.src & '" -quality 85 "' & arguments.dest & '"');
		var ok = r.ok && fileExists(arguments.dest);
		return ["ok": ok, "ms": elapsedMsFromNanos(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ok ? "" : ("ERROR: " & r.out)];
	}

	function runGmResize(required string bin, required string src, required string dest) {
		var t0 = nowNanos();
		var r = runExternal(arguments.bin, 'convert "' & arguments.src & '" -resize 320x240 -quality 85 "' & arguments.dest & '"');
		var ok = r.ok && fileExists(arguments.dest);
		return ["ok": ok, "ms": elapsedMsFromNanos(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ok ? "" : ("ERROR: " & r.out)];
	}

	function runGmRotate(required string bin, required string src, required string dest) {
		var t0 = nowNanos();
		var r = runExternal(arguments.bin, 'convert "' & arguments.src & '" -rotate 90 "' & arguments.dest & '"');
		var ok = r.ok && fileExists(arguments.dest);
		return ["ok": ok, "ms": elapsedMsFromNanos(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ok ? "" : ("ERROR: " & r.out)];
	}

	function runGmConvert(required string bin, required string src, required string dest) {
		var t0 = nowNanos();
		var r = runExternal(arguments.bin, 'convert "' & arguments.src & '" -quality 85 "' & arguments.dest & '"');
		var ok = r.ok && fileExists(arguments.dest);
		return ["ok": ok, "ms": elapsedMsFromNanos(t0), "size": fileSizeOrZero(arguments.dest), "path": arguments.dest, "note": ok ? "" : ("ERROR: " & r.out)];
	}

	/* Inspect runners (no dest file produced).
	   Return shape: ["ok": bool, "ms": numeric, "size": numeric (source bytes), "path": "", "note": "" (unused),
	                  "info": "WxH FMT size", "exifInfo": display string] */

	function inspectRowOk(required numeric t0, required string info, required string exifInfo, required numeric srcSize) {
		return [
			"ok":       true,
			"ms":       elapsedMsFromNanos(arguments.t0),
			"size":     arguments.srcSize,
			"path":     "",
			"note":     "",
			"info":     arguments.info,
			"exifInfo": arguments.exifInfo
		];
	}

	function inspectRowErr(required numeric t0, required string message) {
		return [
			"ok":       false,
			"ms":       elapsedMsFromNanos(arguments.t0),
			"size":     0,
			"path":     "",
			"note":     "ERROR: " & arguments.message,
			"info":     "",
			"exifInfo": ""
		];
	}

	function runThumbInspect(required string src, required string ignored) {
		var thumb = new Thumbnailator();
		var t0 = nowNanos();
		try {
			var info = thumb.inspect(arguments.src);
		} catch (any e) {
			return inspectRowErr(t0, e.message);
		}
		var label = info.width & "x" & info.height & " " & ucase(info.format) & " " & humanSize(info.sizeBytes);
		return inspectRowOk(t0, label, "orientation=" & info.exifOrientation, info.sizeBytes);
	}

	function runCfimageInspect(required string src, required string ignored) {
		var t0 = nowNanos();
		try {
			var img = imageNew(arguments.src);
			var info = imageInfo(img);
		} catch (any e) {
			return inspectRowErr(t0, e.message);
		}
		var fLen = fileSizeOrZero(arguments.src);
		var fmt = ucase(listLast(arguments.src, "."));
		var w = structKeyExists(info, "width") ? info.width : 0;
		var h = structKeyExists(info, "height") ? info.height : 0;
		var label = w & "x" & h & " " & fmt & " " & humanSize(fLen);
		return inspectRowOk(t0, label, "n/a (imageInfo)", fLen);
	}

	function runImInspect(required string bin, required string src) {
		var t0 = nowNanos();
		var idResult = runExternal(arguments.bin, 'identify -format "%w %h %m %b" "' & arguments.src & '"');
		if (!idResult.ok) return inspectRowErr(t0, idResult.out);
		var idLine = listFirst(trim(idResult.out), chr(10) & chr(13));
		var parts = listToArray(trim(idLine), " ");
		var w = arrayLen(parts) gte 1 ? parts[1] : "?";
		var h = arrayLen(parts) gte 2 ? parts[2] : "?";
		var fmt = arrayLen(parts) gte 3 ? parts[3] : "?";
		var sz = arrayLen(parts) gte 4 ? parts[4] : "?";
		var label = w & "x" & h & " " & fmt & " " & sz;
		/* Count EXIF tags via -format '%[EXIF:*]' */
		var exifResult = runExternal(arguments.bin, 'identify -format "%[EXIF:*]" "' & arguments.src & '"');
		var exifCount = 0;
		if (exifResult.ok && len(trim(exifResult.out))) {
			var lines = listToArray(trim(exifResult.out), chr(10) & chr(13));
			exifCount = arrayLen(lines);
		}
		return inspectRowOk(t0, label, exifCount & " EXIF tag" & (exifCount eq 1 ? "" : "s"), fileSizeOrZero(arguments.src));
	}

	function runGmInspect(required string bin, required string src) {
		var t0 = nowNanos();
		var idResult = runExternal(arguments.bin, 'identify -format "%w %h %m %b" "' & arguments.src & '"');
		if (!idResult.ok) return inspectRowErr(t0, idResult.out);
		var idLine = listFirst(trim(idResult.out), chr(10) & chr(13));
		var parts = listToArray(trim(idLine), " ");
		var w = arrayLen(parts) gte 1 ? parts[1] : "?";
		var h = arrayLen(parts) gte 2 ? parts[2] : "?";
		var fmt = arrayLen(parts) gte 3 ? parts[3] : "?";
		var sz = arrayLen(parts) gte 4 ? parts[4] : "?";
		var label = w & "x" & h & " " & fmt & " " & sz;
		var exifResult = runExternal(arguments.bin, 'identify -format "%[EXIF:*]" "' & arguments.src & '"');
		var exifCount = 0;
		if (exifResult.ok && len(trim(exifResult.out))) {
			var lines = listToArray(trim(exifResult.out), chr(10) & chr(13));
			exifCount = arrayLen(lines);
		}
		return inspectRowOk(t0, label, exifCount & " EXIF tag" & (exifCount eq 1 ? "" : "s"), fileSizeOrZero(arguments.src));
	}

	/* Repeat a runner N times, average elapsed, capture min/max.
	   The runner is passed as a closure that accepts (src, dest) and returns a single-run struct. */
	function runRepeated(required any runFn, required string src, required string dest, required numeric iterations) {
		var n = max(1, javacast("int", arguments.iterations));
		var samples = [];
		var lastResult = ["ok": false, "ms": 0, "size": 0, "path": arguments.dest, "note": ""];
		var i = 0;
		for (i = 1; i lte n; i++) {
			lastResult = arguments.runFn(arguments.src, arguments.dest);
			arrayAppend(samples, javacast("double", lastResult.ms));
			if (!lastResult.ok) break;
		}
		var total = 0;
		var minMs = samples[1];
		var maxMs = samples[1];
		var j = 0;
		for (j = 1; j lte arrayLen(samples); j++) {
			total += samples[j];
			if (samples[j] lt minMs) minMs = samples[j];
			if (samples[j] gt maxMs) maxMs = samples[j];
		}
		var avg = total / arrayLen(samples);
		var out = [
			"ok":    lastResult.ok,
			"ms":    avg,
			"min":   minMs,
			"max":   maxMs,
			"count": arrayLen(samples),
			"size":  lastResult.size,
			"path":  lastResult.path,
			"note":  lastResult.note
		];
		if (structKeyExists(lastResult, "info"))     out["info"]     = lastResult.info;
		if (structKeyExists(lastResult, "exifInfo")) out["exifInfo"] = lastResult.exifInfo;
		return out;
	}

	function unsupportedRow(required string reason) {
		return ["ok": false, "ms": 0, "min": 0, "max": 0, "count": 0, "size": 0, "path": "", "note": arguments.reason, "info": "", "exifInfo": ""];
	}

	ensureStarterExifImage(demoImageDir);

	demoImages = listDemoImages(demoImageDir);
	formSrc = (structKeyExists(form, "src") && len(form.src) && fileExists(demoImageDir & form.src)) ? form.src : "starter-exif.jpg";
	if (!fileExists(demoImageDir & formSrc)) formSrc = "starter.png";

	formIterations = 1;
	if (structKeyExists(form, "iterations") && isNumeric(form.iterations)) {
		formIterations = javacast("int", val(form.iterations));
		if (formIterations lt 1) formIterations = 1;
		if (formIterations gt 20) formIterations = 20;
	}

	formThumbExifPassthrough = structKeyExists(form, "thumbExifPassthrough") && len(form.thumbExifPassthrough);
	request.thumbExifPassthrough = formThumbExifPassthrough;

	currentEngineLabel = structKeyExists(server, "boxlang") ? "BoxLang" : (structKeyExists(server, "lucee") ? "Lucee" : "Adobe");
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
		form input[type=number] { width: 5em; }
		table { border-collapse: collapse; width: 100%; margin: 0.6em 0 1.4em; font-size: 0.92em; }
		th, td { border: 1px solid #ccc; padding: 0.35em 0.6em; text-align: left; vertical-align: top; }
		th { background: #eee; }
		td.num { text-align: right; font-variant-numeric: tabular-nums; }
		td.path { font-family: monospace; font-size: 0.85em; color: #555; word-break: break-all; }
		td.thumb { width: 100px; }
		td.thumb a { display: inline-block; }
		td.thumb img { display: block; max-width: 80px; max-height: 80px; object-fit: contain; border: 1px solid #ddd; background: #fafafa; }
		td.thumb .fname { display: block; margin-top: 0.25em; font-family: monospace; font-size: 0.75em; color: #666; word-break: break-all; max-width: 130px; }
		.err { color:#900; font-style:italic; }
		.note { color:#555; font-size:0.85em; }
		.range { display:block; color:#888; font-size: 0.8em; font-variant-numeric: tabular-nums; }
	</style>
</head>
<body>
<h1>Thumbnailator - tool comparison</h1>
<div class="serverinfo"><cfoutput>#encodeForHTML(serverInfo())#</cfoutput></div>
<p class="note">Single-run snapshot, not a rigorous benchmark. Numbers vary across cold/warm runs and OS file-cache state. Bump iterations for an averaged view.</p>

<div class="tools">
<cfoutput>
	<div>Thumbnailator: <span class="ok">available (bundled JAR)</span></div>
	<div>cfimage: <cfif cfimageAvailable><span class="ok">available</span><cfelse><span class="no">not available</span> <span class="note">(#encodeForHTML(cfimageReason)#)</span></cfif></div>
	<div>imageGetEXIFMetadata: <cfif exifFnAvailable><span class="ok">available</span><cfelse><span class="no">not available</span> <span class="note">(#encodeForHTML(exifFnReason)#)</span></cfif></div>
	<div>ImageMagick: <cfif imAvailable><span class="ok">#encodeForHTML(imBin)#</span><cfelse><span class="no">not available</span> <span class="note">(checked #encodeForHTML(imBin)#)</span></cfif></div>
	<div>GraphicsMagick: <cfif gmAvailable><span class="ok">#encodeForHTML(gmBin)#</span><cfelse><span class="no">not available</span> <span class="note">(checked #encodeForHTML(gmBin)#)</span></cfif></div>
</cfoutput>
</div>

<form method="post">
	<div>
		<label for="src">Source image:</label>
		<select name="src" id="src">
			<cfoutput>
			<cfloop array="#demoImages#" index="img">
				<option value="#encodeForHTMLAttribute(img)#"<cfif img eq formSrc> selected</cfif>>#encodeForHTML(img)#</option>
			</cfloop>
			</cfoutput>
		</select>
	</div>
	<div style="margin-top: 0.6em;">
		<label for="iterations">Iterations:</label>
		<input type="number" name="iterations" id="iterations" value="<cfoutput>#encodeForHTMLAttribute(formIterations)#</cfoutput>" min="1" max="20">
		<span class="note">1 = single shot; 2-20 = run N times and average</span>
	</div>
	<div style="margin-top: 0.6em;">
		<label for="thumbExifPassthrough">Thumbnailator EXIF:</label>
		<input type="checkbox" name="thumbExifPassthrough" id="thumbExifPassthrough" value="1"<cfif formThumbExifPassthrough> checked</cfif>>
		<span class="note">pass <code>exifPassthrough: true</code> on Thumbnailator one-shots (flips its EXIF column from lost to preserved)</span>
	</div>
	<div style="margin-top: 0.8em;">
		<button type="submit" name="run" value="1">Run comparison</button>
	</div>
</form>

<cfif structKeyExists(form, "run")>
	<cfscript>
		srcPath = demoImageDir & formSrc;
		srcBase = listFirst(formSrc, ".");
		srcExt  = listLast(formSrc, ".");
		stamp   = createUUID();

		srcExif = readExifSafe(srcPath);

		resizeDest = [
			"thumb":   compareOutDir & srcBase & "-" & stamp & "-resize-thumb.jpg",
			"cfimage": compareOutDir & srcBase & "-" & stamp & "-resize-cfimage.jpg",
			"im":      compareOutDir & srcBase & "-" & stamp & "-resize-im.jpg",
			"gm":      compareOutDir & srcBase & "-" & stamp & "-resize-gm.jpg"
		];
		rotateDest = [
			"thumb":   compareOutDir & srcBase & "-" & stamp & "-rotate-thumb." & srcExt,
			"cfimage": compareOutDir & srcBase & "-" & stamp & "-rotate-cfimage." & srcExt,
			"im":      compareOutDir & srcBase & "-" & stamp & "-rotate-im." & srcExt,
			"gm":      compareOutDir & srcBase & "-" & stamp & "-rotate-gm." & srcExt
		];
		convertDest = [
			"thumb":   compareOutDir & srcBase & "-" & stamp & "-convert-thumb.jpg",
			"cfimage": compareOutDir & srcBase & "-" & stamp & "-convert-cfimage.jpg",
			"im":      compareOutDir & srcBase & "-" & stamp & "-convert-im.jpg",
			"gm":      compareOutDir & srcBase & "-" & stamp & "-convert-gm.jpg"
		];

		results = [
			"resize": [
				"Thumbnailator":  runRepeated(runThumbResize, srcPath, resizeDest.thumb, formIterations),
				"cfimage":        cfimageAvailable ? runRepeated(runCfimageResize, srcPath, resizeDest.cfimage, formIterations) : unsupportedRow("not supported on engine"),
				"ImageMagick":    imAvailable ? runRepeated(function(s,d){ return runImResize(imBin, s, d); }, srcPath, resizeDest.im, formIterations) : unsupportedRow("not available"),
				"GraphicsMagick": gmAvailable ? runRepeated(function(s,d){ return runGmResize(gmBin, s, d); }, srcPath, resizeDest.gm, formIterations) : unsupportedRow("not available")
			],
			"rotate": [
				"Thumbnailator":  runRepeated(runThumbRotate, srcPath, rotateDest.thumb, formIterations),
				"cfimage":        cfimageAvailable ? runRepeated(runCfimageRotate, srcPath, rotateDest.cfimage, formIterations) : unsupportedRow("not supported on engine"),
				"ImageMagick":    imAvailable ? runRepeated(function(s,d){ return runImRotate(imBin, s, d); }, srcPath, rotateDest.im, formIterations) : unsupportedRow("not available"),
				"GraphicsMagick": gmAvailable ? runRepeated(function(s,d){ return runGmRotate(gmBin, s, d); }, srcPath, rotateDest.gm, formIterations) : unsupportedRow("not available")
			],
			"convert": [
				"Thumbnailator":  runRepeated(runThumbConvert, srcPath, convertDest.thumb, formIterations),
				"cfimage":        cfimageAvailable ? runRepeated(runCfimageConvert, srcPath, convertDest.cfimage, formIterations) : unsupportedRow("not supported on engine"),
				"ImageMagick":    imAvailable ? runRepeated(function(s,d){ return runImConvert(imBin, s, d); }, srcPath, convertDest.im, formIterations) : unsupportedRow("not available"),
				"GraphicsMagick": gmAvailable ? runRepeated(function(s,d){ return runGmConvert(gmBin, s, d); }, srcPath, convertDest.gm, formIterations) : unsupportedRow("not available")
			],
			"inspect": [
				"Thumbnailator":  runRepeated(runThumbInspect, srcPath, "", formIterations),
				"cfimage":        cfimageAvailable ? runRepeated(runCfimageInspect, srcPath, "", formIterations) : unsupportedRow("not supported on engine"),
				"ImageMagick":    imAvailable ? runRepeated(function(s,d){ return runImInspect(imBin, s); }, srcPath, "", formIterations) : unsupportedRow("not available"),
				"GraphicsMagick": gmAvailable ? runRepeated(function(s,d){ return runGmInspect(gmBin, s); }, srcPath, "", formIterations) : unsupportedRow("not available")
			]
		];

		labels = [
			"resize":  "Resize 320x240, JPEG q=0.85",
			"rotate":  "Rotate 90 degrees (keeps source format)",
			"convert": "Convert format: input -> JPEG q=0.85",
			"inspect": "Inspect (read metadata)"
		];

		function renderElapsedCell(required struct row) {
			if (arguments.row.count lte 1) {
				return "<td class='num'>" & encodeForHTML(formatMs(arguments.row.ms)) & "</td>";
			}
			var main = formatMs(arguments.row.ms) & " ms";
			var sub = "avg of " & arguments.row.count & "; min " & formatMs(arguments.row.min) & ", max " & formatMs(arguments.row.max);
			return "<td class='num'>" & encodeForHTML(main) & "<span class='range'>" & encodeForHTML(sub) & "</span></td>";
		}

		function renderTable(required string title, required struct rows, required struct srcExif) {
			writeOutput("<h2>" & encodeForHTML(arguments.title) & "</h2>");
			writeOutput("<table><thead><tr><th>Tool</th><th>Output</th><th>Output size</th><th>Elapsed (ms)</th><th>EXIF</th></tr></thead><tbody>");
			var order = ["Thumbnailator", "cfimage", "ImageMagick", "GraphicsMagick"];
			for (var tool in order) {
				var row = arguments.rows[tool];
				writeOutput("<tr>");
				writeOutput("<td>" & encodeForHTML(tool) & "</td>");
				if (row.ok) {
					var fileName = listLast(row.path, "/\");
					var rel = "demo-output/compare/" & fileName;
					writeOutput("<td class='thumb'><a href='" & encodeForHTMLAttribute(rel) & "' target='_blank' rel='noopener' title='open full size'>");
					writeOutput("<img src='" & encodeForHTMLAttribute(rel) & "' alt='" & encodeForHTMLAttribute(fileName) & "'>");
					writeOutput("</a><span class='fname'>" & encodeForHTML(fileName) & "</span></td>");
					writeOutput("<td class='num'>" & encodeForHTML(humanSize(row.size)) & "</td>");
					writeOutput(renderElapsedCell(row));
					var destExif = readExifSafe(row.path);
					var status = compareExif(arguments.srcExif, destExif);
					var engineLabel = currentEngineLabel;
					if (status eq "n/a") engineLabel = exifFnAvailable ? engineLabel : engineLabel;
					writeOutput("<td>" & exifCellHtml(status, engineLabel) & "</td>");
				} else {
					writeOutput("<td class='err' colspan='4'>" & encodeForHTML(row.note) & "</td>");
				}
				writeOutput("</tr>");
			}
			writeOutput("</tbody></table>");
		}

		function renderInspectTable(required string title, required struct rows) {
			writeOutput("<h2>" & encodeForHTML(arguments.title) & "</h2>");
			writeOutput("<table><thead><tr><th>Tool</th><th>Result</th><th>Source size</th><th>Elapsed (ms)</th><th>EXIF</th></tr></thead><tbody>");
			var order = ["Thumbnailator", "cfimage", "ImageMagick", "GraphicsMagick"];
			for (var tool in order) {
				var row = arguments.rows[tool];
				writeOutput("<tr>");
				writeOutput("<td>" & encodeForHTML(tool) & "</td>");
				if (row.ok) {
					var info = structKeyExists(row, "info") ? row.info : "";
					var exifInfo = structKeyExists(row, "exifInfo") ? row.exifInfo : "";
					writeOutput("<td><span style='font-family:monospace'>" & encodeForHTML(info) & "</span></td>");
					writeOutput("<td class='num'>" & encodeForHTML("(source: " & humanSize(row.size) & ")") & "</td>");
					writeOutput(renderElapsedCell(row));
					writeOutput("<td><span style='font-family:monospace;font-size:0.9em'>" & encodeForHTML(exifInfo) & "</span></td>");
				} else {
					writeOutput("<td class='err' colspan='4'>" & encodeForHTML(row.note) & "</td>");
				}
				writeOutput("</tr>");
			}
			writeOutput("</tbody></table>");
		}

		function renderSourceExifBanner(required boolean exifFnAvailable, required struct srcExif) {
			writeOutput("<div class='note' style='margin: 0.5em 0 0.2em;'>Source EXIF: ");
			if (!arguments.exifFnAvailable) {
				writeOutput("<span style='color:##888'>imageGetEXIFMetadata not available on this engine (column will show n/a)</span>");
			} else if (structKeyExists(arguments.srcExif, "__error__")) {
				writeOutput("<span style='color:##900'>read error: " & encodeForHTML(arguments.srcExif.__error__) & "</span>");
			} else {
				var srcSig = exifSignificantPairs(arguments.srcExif);
				if (!structCount(srcSig)) {
					writeOutput("<span style='color:##888'>(none)</span>");
				} else {
					var parts = [];
					for (var k in srcSig) arrayAppend(parts, k & "=" & srcSig[k]);
					writeOutput("<span style='font-family:monospace'>" & encodeForHTML(arrayToList(parts, ", ")) & "</span>");
				}
			}
			writeOutput("</div>");
		}
		renderSourceExifBanner(exifFnAvailable, srcExif);

		renderTable(labels.resize,  results.resize,  srcExif);
		renderTable(labels.rotate,  results.rotate,  srcExif);
		renderTable(labels.convert, results.convert, srcExif);
		renderInspectTable(labels.inspect, results.inspect);
	</cfscript>
</cfif>

</body></html>
