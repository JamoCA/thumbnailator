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
	if (!directoryExists(variables.outDir)) directoryCreate(variables.outDir, true);

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
</cfscript>
