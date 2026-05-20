component displayname="Thumbnailator" hint="ColdFusion wrapper for the Thumbnailator Java library (net.coobird.thumbnailator:thumbnailator:0.4.21)" {

	public any function init() hint="Instantiates Java refs and builds enum lookup tables" {
		variables.JThumbnails  = createObject("java", "net.coobird.thumbnailator.Thumbnails");
		variables.JFile        = createObject("java", "java.io.File");
		variables.JImageIO     = createObject("java", "javax.imageio.ImageIO");
		variables.JPositions   = createObject("java", "net.coobird.thumbnailator.geometry.Positions");
		variables.JScalingMode = createObject("java", "net.coobird.thumbnailator.resizers.configurations.ScalingMode");

		variables._positions = [
			"center":        variables.JPositions.CENTER,
			"top_left":      variables.JPositions.TOP_LEFT,
			"top_center":    variables.JPositions.TOP_CENTER,
			"top_right":     variables.JPositions.TOP_RIGHT,
			"left_center":   variables.JPositions.CENTER_LEFT,
			"right_center":  variables.JPositions.CENTER_RIGHT,
			"bottom_left":   variables.JPositions.BOTTOM_LEFT,
			"bottom_center": variables.JPositions.BOTTOM_CENTER,
			"bottom_right":  variables.JPositions.BOTTOM_RIGHT
		];

		variables._scalingModes = [
			"default":              variables.JScalingMode.PROGRESSIVE_BILINEAR,
			"quality":              variables.JScalingMode.PROGRESSIVE_BILINEAR,
			"speed":                variables.JScalingMode.BILINEAR,
			"bilinear":             variables.JScalingMode.BILINEAR,
			"bicubic":              variables.JScalingMode.BICUBIC,
			"progressive_bilinear": variables.JScalingMode.PROGRESSIVE_BILINEAR
		];

		variables._formats = ["jpg": "jpg", "jpeg": "jpg", "png": "png", "gif": "gif", "bmp": "bmp"];

		variables._ops = [];

		return this;
	}

	/* ---------- Fluent builder ---------- */

	public any function of(required any source) hint="Set the source path, array of paths, or directory" {
		variables._ops = [];
		arrayAppend(variables._ops, ["op": "of", "args": [arguments.source]]);
		return this;
	}

	public any function size(required numeric width, required numeric height) hint="Resize preserving aspect ratio (default)" {
		arrayAppend(variables._ops, ["op": "size", "args": [arguments.width, arguments.height]]);
		return this;
	}

	public any function forceSize(required numeric width, required numeric height) hint="Resize without preserving aspect ratio" {
		arrayAppend(variables._ops, ["op": "forceSize", "args": [arguments.width, arguments.height]]);
		return this;
	}

	public any function rotate(required numeric degrees) hint="Rotate clockwise by degrees" {
		arrayAppend(variables._ops, ["op": "rotate", "args": [arguments.degrees]]);
		return this;
	}

	public any function width(required numeric value) hint="Set width, height proportional" {
		arrayAppend(variables._ops, ["op": "width", "args": [arguments.value]]);
		return this;
	}

	public any function height(required numeric value) hint="Set height, width proportional" {
		arrayAppend(variables._ops, ["op": "height", "args": [arguments.value]]);
		return this;
	}

	public any function scale(required numeric factor, numeric factorY) hint="Uniform scale or independent w/h scale" {
		if (structKeyExists(arguments, "factorY")) {
			arrayAppend(variables._ops, ["op": "scale2", "args": [arguments.factor, arguments.factorY]]);
		} else {
			arrayAppend(variables._ops, ["op": "scale1", "args": [arguments.factor]]);
		}
		return this;
	}

	public any function scalingMode(required string name) hint="Set the scaling algorithm preset" {
		_resolveScalingMode(arguments.name);
		arrayAppend(variables._ops, ["op": "scalingMode", "args": [arguments.name]]);
		return this;
	}

	public any function keepAspectRatio(required boolean value) hint="Preserve aspect ratio (true) or stretch (false)" {
		arrayAppend(variables._ops, ["op": "keepAspectRatio", "args": [arguments.value]]);
		return this;
	}

	public any function useExifOrientation(required boolean value) hint="Honor EXIF orientation tag when reading JPEGs" {
		arrayAppend(variables._ops, ["op": "useExifOrientation", "args": [arguments.value]]);
		return this;
	}

	public any function allowOverwrite(required boolean value) hint="Permit overwriting an existing destination file" {
		arrayAppend(variables._ops, ["op": "allowOverwrite", "args": [arguments.value]]);
		return this;
	}

	public any function outputFormat(required string format) hint="Output format name (jpg/jpeg/png/gif/bmp)" {
		_resolveFormat(arguments.format);
		arrayAppend(variables._ops, ["op": "outputFormat", "args": [arguments.format]]);
		return this;
	}

	public any function outputFormatType(required string formatType) hint="Output format subtype" {
		arrayAppend(variables._ops, ["op": "outputFormatType", "args": [arguments.formatType]]);
		return this;
	}

	public any function outputQuality(required numeric quality) hint="Output quality 0.0..1.0" {
		if (arguments.quality lt 0 || arguments.quality gt 1) {
			_throw("InvalidArgument", "outputQuality must be between 0.0 and 1.0, got " & arguments.quality, "");
		}
		arrayAppend(variables._ops, ["op": "outputQuality", "args": [arguments.quality]]);
		return this;
	}

	public any function useOriginalFormat() hint="Output in the source image's format" {
		arrayAppend(variables._ops, ["op": "useOriginalFormat", "args": []]);
		return this;
	}

	public any function crop(required string positionName) hint="Crop at the specified position after resize" {
		_resolvePosition(arguments.positionName);
		arrayAppend(variables._ops, ["op": "crop", "args": [arguments.positionName]]);
		return this;
	}

	public any function sourceRegion(required any arg1, required numeric arg2, required numeric arg3, numeric arg4) hint="Either (x,y,w,h) or (positionName,w,h)" {
		if (structKeyExists(arguments, "arg4")) {
			arrayAppend(variables._ops, ["op": "sourceRegion4", "args": [arguments.arg1, arguments.arg2, arguments.arg3, arguments.arg4]]);
		} else {
			_resolvePosition(arguments.arg1);
			arrayAppend(variables._ops, ["op": "sourceRegionPos", "args": [arguments.arg1, arguments.arg2, arguments.arg3]]);
		}
		return this;
	}

	/* ---------- One-shot helpers ---------- */

	public struct function resize(required string srcPath, required string destPath, required numeric width, required numeric height, struct opts = {}) hint="Resize srcPath to width x height preserving aspect by default" {
		of(arguments.srcPath).size(arguments.width, arguments.height);
		_applyOpts(arguments.opts);
		var r = toFile(arguments.destPath);
		_maybePassthroughExif(arguments.srcPath, arguments.destPath, arguments.opts);
		return r;
	}

	public struct function scaleImage(required string srcPath, required string destPath, required numeric factor, struct opts = {}) hint="One-shot scale by factor" {
		of(arguments.srcPath).scale(arguments.factor);
		_applyOpts(arguments.opts);
		var r = toFile(arguments.destPath);
		_maybePassthroughExif(arguments.srcPath, arguments.destPath, arguments.opts);
		return r;
	}

	public struct function rotateImage(required string srcPath, required string destPath, required numeric degrees, struct opts = {}) hint="One-shot rotation" {
		of(arguments.srcPath).rotate(arguments.degrees).scale(1.0);
		_applyOpts(arguments.opts);
		var r = toFile(arguments.destPath);
		_maybePassthroughExif(arguments.srcPath, arguments.destPath, arguments.opts);
		return r;
	}

	public struct function cropImage(required string srcPath, required string destPath, required numeric width, required numeric height, string positionName = "center", struct opts = {}) hint="One-shot center-crop or positioned crop to width x height" {
		of(arguments.srcPath).crop(arguments.positionName).size(arguments.width, arguments.height);
		_applyOpts(arguments.opts);
		var r = toFile(arguments.destPath);
		_maybePassthroughExif(arguments.srcPath, arguments.destPath, arguments.opts);
		return r;
	}

	public any function watermark(required string wmPath, required string positionName, required numeric opacity, numeric insets) hint="Apply watermark image at the named position with opacity 0..1 and optional pixel insets" {
		if (!fileExists(arguments.wmPath)) _throw("SourceNotFound", "Watermark file not found: " & arguments.wmPath, "");
		_resolvePosition(arguments.positionName);
		if (arguments.opacity lt 0 || arguments.opacity gt 1) _throw("InvalidArgument", "watermark opacity must be 0.0..1.0, got " & arguments.opacity, "");
		if (structKeyExists(arguments, "insets")) {
			arrayAppend(variables._ops, ["op": "watermark", "args": [arguments.wmPath, arguments.positionName, arguments.opacity, arguments.insets]]);
		} else {
			arrayAppend(variables._ops, ["op": "watermark", "args": [arguments.wmPath, arguments.positionName, arguments.opacity]]);
		}
		return this;
	}

	public struct function convertFormat(required string srcPath, required string destPath, required string formatName, struct opts = {}) hint="One-shot format conversion" {
		_resolveFormat(arguments.formatName);
		of(arguments.srcPath).outputFormat(arguments.formatName).scale(1.0);
		_applyOpts(arguments.opts);
		var r = toFile(arguments.destPath);
		_maybePassthroughExif(arguments.srcPath, arguments.destPath, arguments.opts);
		return r;
	}

	public struct function watermarkImage(required string srcPath, required string destPath, required string wmPath, required string positionName, required numeric opacity, numeric insets, struct opts = {}) hint="One-shot watermark" {
		of(arguments.srcPath);
		if (structKeyExists(arguments, "insets")) {
			watermark(arguments.wmPath, arguments.positionName, arguments.opacity, arguments.insets);
		} else {
			watermark(arguments.wmPath, arguments.positionName, arguments.opacity);
		}
		scale(1.0);
		_applyOpts(arguments.opts);
		var r = toFile(arguments.destPath);
		_maybePassthroughExif(arguments.srcPath, arguments.destPath, arguments.opts);
		return r;
	}

	public struct function batchResize(required string srcDir, required string destDir, required numeric width, required numeric height, struct opts = {}) hint="Resizes every image file in srcDir to destDir; returns aggregate summary plus per-file results" {
		if (!directoryExists(arguments.srcDir)) _throw("SourceNotFound", "Source directory not found: " & arguments.srcDir, "");
		if (!directoryExists(arguments.destDir)) createObject("java","java.io.File").init(javacast("string", arguments.destDir)).mkdirs();
		var files = directoryList(arguments.srcDir, false, "path");
		var results = [];
		var totalBytes = 0;
		var totalMs = 0;
		for (var f in files) {
			var leaf = listLast(f, "/\");
			var dest = arguments.destDir & leaf;
			try {
				var r = resize(f, dest, arguments.width, arguments.height, arguments.opts);
				arrayAppend(results, r);
				totalBytes += r.sizeBytes;
				totalMs += r.durationMs;
			} catch (any e) {
				arrayAppend(results, ["ok": javacast("boolean", false), "srcPath": f, "error": e.message]);
			}
		}
		return [
			"results":    results,
			"count":      javacast("int", arrayLen(results)),
			"totalBytes": javacast("long", totalBytes),
			"totalMs":    javacast("long", totalMs)
		];
	}

	public struct function inspect(required string srcPath) hint="ImageIO-backed info about an image file" {
		if (!fileExists(arguments.srcPath)) _throw("SourceNotFound", "Source file not found: " & arguments.srcPath, "");
		var img = variables.JImageIO.read(variables.JFile.init(javacast("string", arguments.srcPath)));
		if (isNull(img)) _throw("UnsupportedImage", "Could not read image: " & arguments.srcPath, "");
		var hasAlpha = img.getColorModel().hasAlpha();
		var fmt = "unknown";
		var stream = variables.JImageIO.createImageInputStream(variables.JFile.init(javacast("string", arguments.srcPath)));
		try {
			var readers = variables.JImageIO.getImageReaders(stream);
			if (readers.hasNext()) fmt = lcase(readers.next().getFormatName());
		} finally {
			stream.close();
		}
		var fLen = createObject("java", "java.io.File").init(javacast("string", arguments.srcPath)).length();
		return [
			"width":           javacast("int", img.getWidth()),
			"height":          javacast("int", img.getHeight()),
			"format":          fmt,
			"sizeBytes":       javacast("long", fLen),
			"hasAlpha":        javacast("boolean", hasAlpha),
			"exifOrientation": javacast("int", 0)
		];
	}

	/* ---------- Terminal: toFile ---------- */

	public array function toFiles(required string destDir, string prefix = "thumb-") hint="Batch terminal. Writes one file per source. Returns array of result structs." {
		if (!directoryExists(arguments.destDir)) createObject("java","java.io.File").init(javacast("string", arguments.destDir)).mkdirs();
		if (!arrayLen(variables._ops) || variables._ops[1].op neq "of") {
			_throw("InvalidArgument", "Builder requires of() to be called before toFiles", "");
		}
		var src = variables._ops[1].args[1];
		var sources = [];
		if (isArray(src)) {
			sources = src;
		} else if (directoryExists(src)) {
			sources = directoryList(src, false, "path");
		} else {
			sources = [src];
		}
		var results = [];
		for (var s in sources) {
			variables._ops[1].args[1] = s;
			var leaf = listLast(s, "/\");
			var ext = listLast(leaf, ".");
			var base = listDeleteAt(leaf, listLen(leaf, "."), ".");
			var dest = arguments.destDir & arguments.prefix & base & "." & ext;
			arrayAppend(results, toFile(dest));
		}
		return results;
	}

	public any function asBufferedImage() hint="Terminal: build and return the BufferedImage" {
		var builder = _buildJavaBuilder();
		return builder.asBufferedImage();
	}

	public struct function createThumbnail(required string srcPath, required string destPath, required numeric width, required numeric height, struct opts = {}) hint="Convenience: fit-within w x h, JPEG quality 0.85, scalingMode quality, useExifOrientation true" {
		var effectiveOpts = duplicate(arguments.opts);
		if (!structKeyExists(effectiveOpts, "quality"))            effectiveOpts.quality = 0.85;
		if (!structKeyExists(effectiveOpts, "scalingMode"))        effectiveOpts.scalingMode = "quality";
		if (!structKeyExists(effectiveOpts, "useExifOrientation")) effectiveOpts.useExifOrientation = true;
		if (!structKeyExists(effectiveOpts, "outputFormat"))       effectiveOpts.outputFormat = "jpg";
		of(arguments.srcPath).size(arguments.width, arguments.height);
		_applyOpts(effectiveOpts);
		var r = toFile(arguments.destPath);
		_maybePassthroughExif(arguments.srcPath, arguments.destPath, effectiveOpts);
		return r;
	}

	public struct function toFile(required string destPath) hint="Builds and writes a single thumbnail; returns result struct" {
		var start = getTickCount();
		var builder = _buildJavaBuilder();
		try {
			builder.toFile(variables.JFile.init(javacast("string", arguments.destPath)));
		} catch (any e) {
			_throwFromJava(e, arguments.destPath);
		}
		var elapsed = getTickCount() - start;
		if (!fileExists(arguments.destPath)) _throw("IOError", "Output file was not written: " & arguments.destPath, "");
		var sz = _readSize(arguments.destPath);
		var fLen = createObject("java", "java.io.File").init(javacast("string", arguments.destPath)).length();
		return [
			"ok":         javacast("boolean", true),
			"destPath":   arguments.destPath,
			"width":      javacast("int", sz.width),
			"height":     javacast("int", sz.height),
			"sizeBytes":  javacast("long", fLen),
			"format":     _detectFormat(arguments.destPath),
			"durationMs": javacast("long", elapsed)
		];
	}

	/* ---------- Internal: replay accumulated ops onto a fresh Java Builder ---------- */

	private any function _buildJavaBuilder() hint="Replays variables._ops onto Thumbnails.of(...) and returns the live Java builder" {
		if (!arrayLen(variables._ops) || variables._ops[1].op neq "of") {
			_throw("InvalidArgument", "Builder requires of() to be called before any terminal", "");
		}
		var src = variables._ops[1].args[1];
		var builder = "";

		if (isArray(src)) {
			var fileList = createObject("java", "java.util.ArrayList").init();
			for (var p in src) {
				if (!fileExists(p)) _throw("SourceNotFound", "Source file not found: " & p, "");
				fileList.add(variables.JFile.init(javacast("string", p)));
			}
			builder = variables.JThumbnails.fromFiles(fileList);
		} else if (directoryExists(src)) {
			var paths = directoryList(src, false, "path");
			var fileList = createObject("java", "java.util.ArrayList").init();
			for (var p in paths) fileList.add(variables.JFile.init(javacast("string", p)));
			builder = variables.JThumbnails.fromFiles(fileList);
		} else {
			if (!fileExists(src)) _throw("SourceNotFound", "Source file not found: " & src, "");
			var singleFileList = createObject("java", "java.util.ArrayList").init();
			singleFileList.add(variables.JFile.init(javacast("string", src)));
			builder = variables.JThumbnails.fromFiles(singleFileList);
		}

		for (var i = 2; i lte arrayLen(variables._ops); i++) {
			var step = variables._ops[i];
			switch (step.op) {
				case "size":     builder = builder.size(javacast("int", step.args[1]), javacast("int", step.args[2])); break;
				case "forceSize":builder = builder.forceSize(javacast("int", step.args[1]), javacast("int", step.args[2])); break;
				case "rotate":   builder = builder.rotate(createObject("java","java.lang.Double").init(step.args[1])); break;
				case "width":    builder = builder.width(javacast("int", step.args[1])); break;
				case "height":   builder = builder.height(javacast("int", step.args[1])); break;
				case "scale1":   builder = builder.scale(createObject("java","java.lang.Double").init(step.args[1])); break;
				case "scale2":   builder = builder.scale(createObject("java","java.lang.Double").init(step.args[1]), createObject("java","java.lang.Double").init(step.args[2])); break;
				case "outputFormat":     builder = builder.outputFormat(javacast("string", step.args[1])); break;
				case "outputFormatType": builder = builder.outputFormatType(javacast("string", step.args[1])); break;
				case "outputQuality":    builder = builder.outputQuality(createObject("java","java.lang.Float").init(step.args[1])); break;
				case "useOriginalFormat":builder = builder.useOriginalFormat(); break;
				case "keepAspectRatio":  builder = builder.keepAspectRatio(javacast("boolean", step.args[1])); break;
				case "useExifOrientation":builder = builder.useExifOrientation(javacast("boolean", step.args[1])); break;
				case "allowOverwrite":   builder = builder.allowOverwrite(javacast("boolean", step.args[1])); break;
				case "scalingMode":      builder = builder.scalingMode(_resolveScalingMode(step.args[1])); break;
				case "crop":             builder = builder.crop(_resolvePosition(step.args[1])); break;
				case "sourceRegion4":
					builder = builder.sourceRegion(
						javacast("int", step.args[1]),
						javacast("int", step.args[2]),
						javacast("int", step.args[3]),
						javacast("int", step.args[4])
					);
					break;
				case "sourceRegionPos":
					builder = builder.sourceRegion(_resolvePosition(step.args[1]), javacast("int", step.args[2]), javacast("int", step.args[3]));
					break;
				case "watermark":
					var wmImage = variables.JImageIO.read(variables.JFile.init(javacast("string", step.args[1])));
					if (isNull(wmImage)) _throw("UnsupportedImage", "Could not read watermark image: " & step.args[1], "");
					if (arrayLen(step.args) gte 4) {
						builder = builder.watermark(_resolvePosition(step.args[2]), wmImage, createObject("java","java.lang.Float").init(step.args[3]), javacast("int", step.args[4]));
					} else {
						builder = builder.watermark(_resolvePosition(step.args[2]), wmImage, createObject("java","java.lang.Float").init(step.args[3]));
					}
					break;
				default:
					_throw("InvalidArgument", "Unknown internal op: " & step.op, "");
			}
		}
		return builder;
	}

	/* ---------- Private helpers ---------- */

	private void function _applyOpts(required struct opts) {
		if (structKeyExists(arguments.opts, "scalingMode"))        scalingMode(arguments.opts.scalingMode);
		if (structKeyExists(arguments.opts, "keepAspectRatio"))    keepAspectRatio(arguments.opts.keepAspectRatio);
		if (structKeyExists(arguments.opts, "useExifOrientation")) useExifOrientation(arguments.opts.useExifOrientation);
		if (structKeyExists(arguments.opts, "allowOverwrite"))     allowOverwrite(arguments.opts.allowOverwrite);
		if (structKeyExists(arguments.opts, "outputFormat"))       outputFormat(arguments.opts.outputFormat);
		if (structKeyExists(arguments.opts, "outputFormatType") && len(arguments.opts.outputFormatType)) outputFormatType(arguments.opts.outputFormatType);
		if (structKeyExists(arguments.opts, "quality"))            outputQuality(arguments.opts.quality);
	}

	private any function _resolvePosition(required string name) {
		var key = lcase(arguments.name);
		if (!structKeyExists(variables._positions, key)) {
			_throw("UnknownPosition", "Unknown position '" & arguments.name & "'. Valid: " & arrayToList(structKeyArray(variables._positions)), "");
		}
		return variables._positions[key];
	}

	private any function _resolveScalingMode(required string name) {
		var key = lcase(arguments.name);
		if (!structKeyExists(variables._scalingModes, key)) {
			_throw("UnknownScalingMode", "Unknown scalingMode '" & arguments.name & "'. Valid: " & arrayToList(structKeyArray(variables._scalingModes)), "");
		}
		return variables._scalingModes[key];
	}

	private string function _resolveFormat(required string name) {
		var key = lcase(arguments.name);
		if (!structKeyExists(variables._formats, key)) {
			_throw("UnknownFormat", "Unknown outputFormat '" & arguments.name & "'. Valid: " & arrayToList(structKeyArray(variables._formats)), "");
		}
		return variables._formats[key];
	}

	private string function _detectFormat(required string path) {
		var stream = variables.JImageIO.createImageInputStream(variables.JFile.init(javacast("string", arguments.path)));
		try {
			var readers = variables.JImageIO.getImageReaders(stream);
			if (readers.hasNext()) return lcase(readers.next().getFormatName());
		} finally {
			stream.close();
		}
		return "unknown";
	}

	private struct function _readSize(required string path) {
		var img = variables.JImageIO.read(variables.JFile.init(javacast("string", arguments.path)));
		return ["width": img.getWidth(), "height": img.getHeight()];
	}

	private void function _throw(required string type, required string message, required string detail) {
		throw(type = "Thumbnailator." & arguments.type, message = arguments.message, detail = arguments.detail);
	}

	private void function _throwFromJava(required any javaException, string destPath = "") {
		var msg = arguments.javaException.message;
		if (msg contains "OverwriteBlocked" || msg contains "already exists" || msg contains "destination file exists") {
			_throw("OverwriteBlocked", "Destination exists and allowOverwrite=false: " & arguments.destPath, msg);
		}
		if (msg contains "Unsupported") {
			_throw("UnsupportedImage", "Unsupported image format", msg);
		}
		_throw("IOError", "Thumbnailator failed: " & msg, msg);
	}

	/* ---------- EXIF passthrough helpers ---------- */

	private boolean function _isJpegPath(required string path) hint="True if the path ends in .jpg or .jpeg (case-insensitive)" {
		var ext = lcase(listLast(arguments.path, "."));
		return ext eq "jpg" || ext eq "jpeg";
	}

	private void function _maybePassthroughExif(required string srcPath, required string destPath, required struct opts) hint="If opts.exifPassthrough is true and both files are JPEG, copies src EXIF to dest with Orientation reset to 1" {
		if (!structKeyExists(arguments.opts, "exifPassthrough") || !arguments.opts.exifPassthrough) return;
		if (!_isJpegPath(arguments.srcPath) || !_isJpegPath(arguments.destPath)) return;
		var exifSeg = _readExifAppSegment(arguments.srcPath);
		if (isNull(exifSeg)) return;
		var safeSeg = _resetExifOrientation(exifSeg);
		_spliceExifIntoJpeg(arguments.destPath, safeSeg);
	}

	private any function _readExifAppSegment(required string jpegPath) hint="Returns the raw APP1/Exif segment bytes (java byte[]) or null if absent" {
		if (!fileExists(arguments.jpegPath)) return javacast("null", "");
		var fis = createObject("java","java.io.FileInputStream").init(arguments.jpegPath);
		var fLen = createObject("java","java.io.File").init(javacast("string", arguments.jpegPath)).length();
		var bytes = createObject("java","java.lang.reflect.Array").newInstance(createObject("java","java.lang.Byte").TYPE, javacast("int", fLen));
		try {
			fis.read(bytes);
		} finally {
			fis.close();
		}
		if (fLen lt 4) return javacast("null", "");
		var arrCls = createObject("java","java.lang.reflect.Array");
		if (bitAnd(arrCls.getByte(bytes, javacast("int", 0)), 255) neq 255 || bitAnd(arrCls.getByte(bytes, javacast("int", 1)), 255) neq 216) return javacast("null", "");
		var pos = 2;
		while (pos lt fLen - 4) {
			var b0 = bitAnd(arrCls.getByte(bytes, javacast("int", pos)), 255);
			var b1 = bitAnd(arrCls.getByte(bytes, javacast("int", pos + 1)), 255);
			if (b0 neq 255) break;
			if (b1 eq 218 || b1 eq 217) break;
			var segLen = bitOr(bitShln(bitAnd(arrCls.getByte(bytes, javacast("int", pos + 2)), 255), 8), bitAnd(arrCls.getByte(bytes, javacast("int", pos + 3)), 255));
			if (b1 eq 225 && pos + 9 lt fLen
					&& bitAnd(arrCls.getByte(bytes, javacast("int", pos + 4)), 255) eq 69
					&& bitAnd(arrCls.getByte(bytes, javacast("int", pos + 5)), 255) eq 120
					&& bitAnd(arrCls.getByte(bytes, javacast("int", pos + 6)), 255) eq 105
					&& bitAnd(arrCls.getByte(bytes, javacast("int", pos + 7)), 255) eq 102) {
				var totalBytes = 2 + segLen;
				var segArr = arrCls.newInstance(createObject("java","java.lang.Byte").TYPE, javacast("int", totalBytes));
				for (var i = 0; i lt totalBytes; i++) {
					arrCls.setByte(segArr, javacast("int", i), arrCls.getByte(bytes, javacast("int", pos + i)));
				}
				return segArr;
			}
			pos += 2 + segLen;
		}
		return javacast("null", "");
	}

	private void function _spliceExifIntoJpeg(required string jpegPath, required any exifSegment) hint="Inserts the exifSegment bytes after the SOI marker of jpegPath, stripping any existing APP1/Exif segment first" {
		if (isNull(arguments.exifSegment)) return;
		if (!fileExists(arguments.jpegPath)) return;
		var fis = createObject("java","java.io.FileInputStream").init(arguments.jpegPath);
		var fLen = createObject("java","java.io.File").init(javacast("string", arguments.jpegPath)).length();
		var orig = createObject("java","java.lang.reflect.Array").newInstance(createObject("java","java.lang.Byte").TYPE, javacast("int", fLen));
		try {
			fis.read(orig);
		} finally {
			fis.close();
		}
		var arrCls = createObject("java","java.lang.reflect.Array");
		if (fLen lt 2) return;
		if (bitAnd(arrCls.getByte(orig, javacast("int", 0)), 255) neq 255 || bitAnd(arrCls.getByte(orig, javacast("int", 1)), 255) neq 216) return;
		/* Scan existing segments and find where to insert.  Strip any existing APP1/Exif first to avoid duplicates. */
		var stripStart = -1;
		var stripEnd = -1;
		var pos = 2;
		while (pos lt fLen - 4) {
			var b0 = bitAnd(arrCls.getByte(orig, javacast("int", pos)), 255);
			var b1 = bitAnd(arrCls.getByte(orig, javacast("int", pos + 1)), 255);
			if (b0 neq 255) break;
			if (b1 eq 218 || b1 eq 217) break;
			var segLen = bitOr(bitShln(bitAnd(arrCls.getByte(orig, javacast("int", pos + 2)), 255), 8), bitAnd(arrCls.getByte(orig, javacast("int", pos + 3)), 255));
			if (b1 eq 225 && pos + 9 lt fLen
					&& bitAnd(arrCls.getByte(orig, javacast("int", pos + 4)), 255) eq 69
					&& bitAnd(arrCls.getByte(orig, javacast("int", pos + 5)), 255) eq 120
					&& bitAnd(arrCls.getByte(orig, javacast("int", pos + 6)), 255) eq 105
					&& bitAnd(arrCls.getByte(orig, javacast("int", pos + 7)), 255) eq 102) {
				stripStart = pos;
				stripEnd = pos + 2 + segLen;
				break;
			}
			pos += 2 + segLen;
		}
		var segLen2 = arrCls.getLength(arguments.exifSegment);
		var stripLen = (stripStart gte 0) ? (stripEnd - stripStart) : 0;
		var newLen = fLen + segLen2 - stripLen;
		var out = arrCls.newInstance(createObject("java","java.lang.Byte").TYPE, javacast("int", newLen));
		/* SOI */
		arrCls.setByte(out, javacast("int", 0), arrCls.getByte(orig, javacast("int", 0)));
		arrCls.setByte(out, javacast("int", 1), arrCls.getByte(orig, javacast("int", 1)));
		var oi = 2;
		var i = 0;
		/* Insert EXIF segment */
		for (i = 0; i lt segLen2; i++) {
			arrCls.setByte(out, javacast("int", oi), arrCls.getByte(arguments.exifSegment, javacast("int", i)));
			oi++;
		}
		/* Copy bytes 2..stripStart (or to end if nothing to strip) */
		var copyEnd = (stripStart gte 0) ? stripStart : fLen;
		for (i = 2; i lt copyEnd; i++) {
			arrCls.setByte(out, javacast("int", oi), arrCls.getByte(orig, javacast("int", i)));
			oi++;
		}
		/* Copy bytes after stripped APP1, if any */
		if (stripStart gte 0) {
			for (i = stripEnd; i lt fLen; i++) {
				arrCls.setByte(out, javacast("int", oi), arrCls.getByte(orig, javacast("int", i)));
				oi++;
			}
		}
		var fos = createObject("java","java.io.FileOutputStream").init(arguments.jpegPath);
		try {
			fos.write(out);
		} finally {
			fos.close();
		}
	}

	private any function _resetExifOrientation(required any exifBytes) hint="Returns a copy of exifBytes with the EXIF Orientation tag (IFD0 0x0112) forced to 1" {
		var arrCls = createObject("java","java.lang.reflect.Array");
		var slen = arrCls.getLength(arguments.exifBytes);
		var out = arrCls.newInstance(createObject("java","java.lang.Byte").TYPE, javacast("int", slen));
		var i = 0;
		for (i = 0; i lt slen; i++) {
			arrCls.setByte(out, javacast("int", i), arrCls.getByte(arguments.exifBytes, javacast("int", i)));
		}
		if (slen lt 18) return out;
		var tiffStart = 10;
		var be = bitAnd(arrCls.getByte(out, javacast("int", tiffStart)), 255) eq 77;
		var ifd0Offset = _readUint32(out, tiffStart + 4, be);
		var ifd0Start = tiffStart + ifd0Offset;
		if (ifd0Start + 2 gt slen) return out;
		var entryCount = _readUint16(out, ifd0Start, be);
		var e = 0;
		for (e = 0; e lt entryCount; e++) {
			var entryStart = ifd0Start + 2 + (e * 12);
			if (entryStart + 12 gt slen) break;
			var tag = _readUint16(out, entryStart, be);
			if (tag eq 274) {
				if (be) {
					arrCls.setByte(out, javacast("int", entryStart + 8), javacast("byte", javacast("int", 0)));
					arrCls.setByte(out, javacast("int", entryStart + 9), javacast("byte", javacast("int", 1)));
				} else {
					arrCls.setByte(out, javacast("int", entryStart + 8), javacast("byte", javacast("int", 1)));
					arrCls.setByte(out, javacast("int", entryStart + 9), javacast("byte", javacast("int", 0)));
				}
				break;
			}
		}
		return out;
	}

	private numeric function _readUint16(required any bytes, required numeric pos, required boolean bigEndian) {
		var arrCls = createObject("java","java.lang.reflect.Array");
		var b0 = bitAnd(arrCls.getByte(arguments.bytes, javacast("int", arguments.pos)), 255);
		var b1 = bitAnd(arrCls.getByte(arguments.bytes, javacast("int", arguments.pos + 1)), 255);
		return arguments.bigEndian ? (b0 * 256 + b1) : (b1 * 256 + b0);
	}

	private numeric function _readUint32(required any bytes, required numeric pos, required boolean bigEndian) {
		var arrCls = createObject("java","java.lang.reflect.Array");
		var b0 = bitAnd(arrCls.getByte(arguments.bytes, javacast("int", arguments.pos)), 255);
		var b1 = bitAnd(arrCls.getByte(arguments.bytes, javacast("int", arguments.pos + 1)), 255);
		var b2 = bitAnd(arrCls.getByte(arguments.bytes, javacast("int", arguments.pos + 2)), 255);
		var b3 = bitAnd(arrCls.getByte(arguments.bytes, javacast("int", arguments.pos + 3)), 255);
		return arguments.bigEndian ? (b0 * 16777216 + b1 * 65536 + b2 * 256 + b3) : (b3 * 16777216 + b2 * 65536 + b1 * 256 + b0);
	}
}
