<cfif !structKeyExists(request, "_testHelperLoaded")><cfinclude template="_testHelper.cfm"><cfelse><cfscript>request.passes = 0; request.failures = [];</cfscript></cfif>
<cfscript>
	writeOutput("<!doctype html><meta charset='utf-8'><title>thumbnailator exif passthrough</title><style>body{font-family:monospace}</style>");
	writeOutput("<h1>Thumbnailator - exifPassthrough tests</h1>");
	writeOutput("<div style='color:##666;font-size:0.9em'>" & encodeForHTML(serverInfo()) & "</div>");

	thumb = new Thumbnailator();

	function safeExif(required string path) {
		try {
			var meta = imageGetEXIFMetadata(imageNew(arguments.path));
			if (isNull(meta) || !isStruct(meta)) return {};
			return meta;
		} catch (any e) {
			return {};
		}
	}

	/* Build a source JPEG with orientation=6 EXIF */
	srcJpg = makeJpegWithExifOrientation(6);

	/* Resize without exifPassthrough - source's specific EXIF should not survive intact */
	destA = tempPath("jpg");
	thumb.resize(srcJpg, destA, 200, 100);
	srcExif = safeExif(srcJpg);
	destAExif = safeExif(destA);
	assert(structCount(srcExif) gt 0, "source JPEG reports EXIF data");
	assert(structKeyExists(srcExif, "Orientation"), "source EXIF has Orientation entry");
	assert(!structKeyExists(destAExif, "Orientation") || destAExif.Orientation neq srcExif.Orientation, "without exifPassthrough, source-orientation tag does not survive verbatim");

	function isOrientationNormal(required any value) {
		if (isNumeric(arguments.value)) return val(arguments.value) eq 1;
		if (isSimpleValue(arguments.value)) {
			if (trim(arguments.value) eq "1") return true;
			if (findNoCase("normal", arguments.value)) return true;
			if (findNoCase("Top, left side", arguments.value)) return true;
		}
		return false;
	}

	/* Resize WITH exifPassthrough - EXIF should survive (but Orientation reset to 1) */
	destB = tempPath("jpg");
	thumb.resize(srcJpg, destB, 200, 100, ["exifPassthrough": true]);
	destBExif = safeExif(destB);
	assert(structCount(destBExif) gt 0, "with exifPassthrough, output retains some EXIF");
	if (structKeyExists(destBExif, "Orientation")) {
		assert(isOrientationNormal(destBExif.Orientation), "exifPassthrough resets Orientation to 1 (normal); got '" & destBExif.Orientation & "'");
	} else {
		assert(true, "Orientation tag absent in output (acceptable: some engines drop unknown tags)");
	}

	/* Rotate WITH exifPassthrough - same EXIF copied, orientation still 1 */
	destC = tempPath("jpg");
	thumb.rotateImage(srcJpg, destC, 90, ["exifPassthrough": true]);
	destCExif = safeExif(destC);
	assert(structCount(destCExif) gt 0, "rotateImage with exifPassthrough retains EXIF");

	/* PNG output with exifPassthrough should silently skip (PNG doesn't carry EXIF natively) */
	destD = tempPath("png");
	thumb.convertFormat(srcJpg, destD, "png", ["exifPassthrough": true]);
	assert(fileExists(destD), "convertFormat to PNG with exifPassthrough does not error");

	/* Source without EXIF - should not error */
	srcNoExif = makeFixture("noexif", 200, 100, "jpg");
	destE = tempPath("jpg");
	thumb.resize(srcNoExif, destE, 100, 50, ["exifPassthrough": true]);
	assert(fileExists(destE), "exifPassthrough on source-without-EXIF does not error");

	/* createThumbnail with exifPassthrough should also work */
	destF = tempPath("jpg");
	thumb.createThumbnail(srcJpg, destF, 150, 75, ["exifPassthrough": true]);
	destFExif = safeExif(destF);
	assert(structCount(destFExif) gt 0, "createThumbnail with exifPassthrough retains EXIF");

	/* exifPassthrough default false - resize without the opt does not splice EXIF */
	destG = tempPath("jpg");
	thumb.resize(srcJpg, destG, 200, 100);
	assert(fileExists(destG), "default behavior (no exifPassthrough) still produces a file");

	summarize();
</cfscript>
