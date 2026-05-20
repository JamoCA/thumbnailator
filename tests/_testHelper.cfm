<cfsetting enablecfoutputonly="true" requesttimeout="120">
<cfscript>
	request.passes = 0;
	request.failures = [];

	function assert(required boolean condition, required string label) {
		if (arguments.condition) {
			request.passes++;
			writeOutput("<div style='color:green'>PASS " & encodeForHTML(arguments.label) & "</div>");
		} else {
			arrayAppend(request.failures, arguments.label);
			writeOutput("<div style='color:red;font-weight:bold'>FAIL " & encodeForHTML(arguments.label) & "</div>");
		}
	}

	function assertThrows(required any cb, required string typeMatch, required string label) {
		var caught = false;
		var actualType = "";
		try {
			arguments.cb();
		} catch (any e) {
			caught = true;
			actualType = e.type;
		}
		if (caught && actualType contains arguments.typeMatch) {
			request.passes++;
			writeOutput("<div style='color:green'>PASS " & encodeForHTML(arguments.label) & " (threw " & encodeForHTML(actualType) & ")</div>");
		} else {
			arrayAppend(request.failures, arguments.label & " (expected type matching '" & arguments.typeMatch & "', got '" & actualType & "')");
			writeOutput("<div style='color:red;font-weight:bold'>FAIL " & encodeForHTML(arguments.label) & "</div>");
		}
	}

	function summarize() {
		writeOutput("<hr><h2>" & request.passes & " passed, " & arrayLen(request.failures) & " failed</h2>");
		if (arrayLen(request.failures)) {
			getPageContext().getResponse().setStatus(500);
			writeOutput("<ul>");
			for (var f in request.failures) writeOutput("<li>" & encodeForHTML(f) & "</li>");
			writeOutput("</ul>");
		}
	}

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

	variables.outDir = expandPath("../demo-output/test/");
	if (!directoryExists(variables.outDir)) {
		createObject("java", "java.io.File").init(javacast("string", variables.outDir)).mkdirs();
	}

	function tempPath(required string suffix) {
		return variables.outDir & createUUID() & "." & arguments.suffix;
	}

	function makeFixture(required string label, required numeric w, required numeric h, string format = "png") {
		var path = tempPath(arguments.format);
		var bi = createObject("java", "java.awt.image.BufferedImage").init(
			javacast("int", arguments.w),
			javacast("int", arguments.h),
			javacast("int", 1)
		);
		var g = bi.createGraphics();
		try {
			g.setColor(createObject("java", "java.awt.Color").init(javacast("int", 220), javacast("int", 230), javacast("int", 255)));
			g.fillRect(javacast("int", 0), javacast("int", 0), javacast("int", arguments.w), javacast("int", arguments.h));
			g.setColor(createObject("java", "java.awt.Color").init(javacast("int", 200), javacast("int", 50), javacast("int", 50)));
			g.fillRect(javacast("int", 10), javacast("int", 10), javacast("int", int(arguments.w / 4)), javacast("int", int(arguments.h / 4)));
			g.setColor(createObject("java", "java.awt.Color").init(javacast("int", 50), javacast("int", 150), javacast("int", 50)));
			g.fillOval(javacast("int", int(arguments.w / 2)), javacast("int", int(arguments.h / 2)), javacast("int", int(arguments.w / 4)), javacast("int", int(arguments.h / 4)));
			g.setColor(createObject("java", "java.awt.Color").init(javacast("int", 0), javacast("int", 0), javacast("int", 0)));
			g.drawString(javacast("string", arguments.label), javacast("int", 20), javacast("int", arguments.h - 20));
		} finally {
			g.dispose();
		}
		createObject("java", "javax.imageio.ImageIO").write(
			bi,
			javacast("string", arguments.format),
			createObject("java", "java.io.File").init(path)
		);
		return path;
	}

	function readSize(required string path) {
		var img = createObject("java", "javax.imageio.ImageIO").read(createObject("java", "java.io.File").init(arguments.path));
		return ["width": img.getWidth(), "height": img.getHeight()];
	}

	function readMagicBytes(required string path, required numeric count) {
		var fis = createObject("java", "java.io.FileInputStream").init(arguments.path);
		try {
			var buf = createObject("java", "java.lang.reflect.Array").newInstance(createObject("java", "java.lang.Byte").TYPE, javacast("int", arguments.count));
			fis.read(buf);
			var out = [];
			for (var i = 0; i lt arrayLen(buf); i++) {
				var v = bitAnd(buf[i + 1], 255);
				arrayAppend(out, ucase(right("0" & formatBaseN(v, 16), 2)));
			}
			return out;
		} finally {
			fis.close();
		}
	}

	function makeJpegWithExifOrientation(required numeric orientation) hint="Writes a small JPEG with an EXIF APP1 segment carrying the given orientation tag (1-8)" {
		var path = tempPath("jpg");

		/* Build a 200x100 JPEG (landscape, red with a white left bar) */
		var bi = createObject("java", "java.awt.image.BufferedImage").init(javacast("int", 200), javacast("int", 100), javacast("int", 1));
		var g = bi.createGraphics();
		try {
			g.setColor(createObject("java", "java.awt.Color").RED);
			g.fillRect(javacast("int", 0), javacast("int", 0), javacast("int", 200), javacast("int", 100));
			g.setColor(createObject("java", "java.awt.Color").WHITE);
			g.fillRect(javacast("int", 0), javacast("int", 0), javacast("int", 20), javacast("int", 100));
		} finally {
			g.dispose();
		}
		createObject("java", "javax.imageio.ImageIO").write(bi, javacast("string", "jpg"), createObject("java", "java.io.File").init(path));

		/* Read the original file as a Java byte[] so we can splice in an APP1 segment */
		var fis = createObject("java", "java.io.FileInputStream").init(path);
		var fLen = createObject("java", "java.io.File").init(path).length();
		var orig = createObject("java", "java.lang.reflect.Array").newInstance(createObject("java", "java.lang.Byte").TYPE, javacast("int", fLen));
		fis.read(orig);
		fis.close();

		/* Compose an APP1/Exif segment with one IFD0 entry: Orientation (0x0112) = arguments.orientation.
		   Layout (offsets relative to segment start, including marker bytes; total = 36 bytes):
		     [0..1]   FF E1 (APP1 marker)
		     [2..3]   00 22 (segment length = 34; length includes itself but not the marker)
		     [4..9]   "Exif" 00 00
		     [10..13] 49 49 2A 00 (little-endian TIFF header)
		     [14..17] 08 00 00 00 (offset to IFD0 = 8 bytes from start of TIFF header)
		     [18..19] 01 00 (1 IFD0 entry)
		     [20..21] 12 01 (tag 0x0112)
		     [22..23] 03 00 (type SHORT)
		     [24..27] 01 00 00 00 (count = 1)
		     [28..29] <orient_lo> <orient_hi> (orientation value, little-endian)
		     [30..31] 00 00 (padding for 4-byte value slot)
		     [32..35] 00 00 00 00 (next IFD offset = 0, no more IFDs)
		   The 4-byte next IFD offset is required by Thumbnailator's ExifUtils.readIFD;
		   without it the buffer underflows. Total content after length field = 32 bytes,
		   plus 2 length bytes = 34 (the declared length). */

		var orient = javacast("int", arguments.orientation);
		var orientLo = bitAnd(orient, 255);
		var orientHi = bitAnd(int(orient / 256), 255);

		var seg = [
			255, 225,                       /* APP1 marker */
			0, 34,                          /* segment length (big-endian) = 34 (includes self) */
			69, 120, 105, 102, 0, 0,        /* "Exif" then 00 00 */
			73, 73, 42, 0,                  /* TIFF "II*\0" little-endian */
			8, 0, 0, 0,                     /* IFD0 offset = 8 */
			1, 0,                           /* 1 entry */
			18, 1,                          /* tag = 0x0112 */
			3, 0,                           /* type = SHORT */
			1, 0, 0, 0,                     /* count = 1 */
			orientLo, orientHi, 0, 0,       /* value (4 bytes; SHORT in low 2, pad 0 0) */
			0, 0, 0, 0                      /* next IFD offset = 0 */
		];

		/* Find the length of the original APP0 (FFE0) segment after SOI (FFD8).
		   bytes[0..1] = FFD8, bytes[2..3] = FFE0, bytes[4..5] = APP0 length (big-endian). */
		var jReflectArray = createObject("java", "java.lang.reflect.Array");
		var app0Len = bitOr(bitShln(bitAnd(jReflectArray.getByte(orig, javacast("int", 4)), 255), 8), bitAnd(jReflectArray.getByte(orig, javacast("int", 5)), 255));

		/* New file layout: SOI (2) + our APP1 (30) + rest after old APP0 starting at offset 4 + app0Len */
		var newLen = 2 + arrayLen(seg) + (fLen - 4 - app0Len);
		var out = jReflectArray.newInstance(createObject("java", "java.lang.Byte").TYPE, javacast("int", newLen));

		/* Copy SOI (FF D8) using reflection setByte (0-based Java indices) */
		jReflectArray.setByte(out, javacast("int", 0), jReflectArray.getByte(orig, javacast("int", 0)));
		jReflectArray.setByte(out, javacast("int", 1), jReflectArray.getByte(orig, javacast("int", 1)));

		/* Copy our APP1 segment, converting unsigned ints 0..255 to signed Java bytes */
		var idx = 2;
		for (var i = 1; i lte arrayLen(seg); i++) {
			var b = seg[i];
			if (b gt 127) b = b - 256;
			jReflectArray.setByte(out, javacast("int", idx), javacast("byte", javacast("int", b)));
			idx++;
		}

		/* Copy the rest of the original file after the old APP0.
		   Original 0-based offsets: [0..1]=SOI, [2..3]=APP0 marker, [4..5]=APP0 length, [6..(3+app0Len)]=APP0 body.
		   Continue from offset 4+app0Len = first byte after APP0. */
		for (var i = 4 + app0Len; i lt fLen; i++) {
			jReflectArray.setByte(out, javacast("int", idx), jReflectArray.getByte(orig, javacast("int", i)));
			idx++;
		}

		/* Write the spliced file back */
		var fos = createObject("java", "java.io.FileOutputStream").init(path);
		try {
			fos.write(out);
		} finally {
			fos.close();
		}

		return path;
	}
</cfscript>
