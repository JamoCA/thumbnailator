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

	/* ---------- One-shot helpers ---------- */

	public struct function resize(required string srcPath, required string destPath, required numeric width, required numeric height, struct opts = {}) hint="Resize srcPath to width x height preserving aspect by default" {
		of(arguments.srcPath).size(arguments.width, arguments.height);
		_applyOpts(arguments.opts);
		return toFile(arguments.destPath);
	}

	public struct function scaleImage(required string srcPath, required string destPath, required numeric factor, struct opts = {}) hint="One-shot scale by factor" {
		of(arguments.srcPath).scale(arguments.factor);
		_applyOpts(arguments.opts);
		return toFile(arguments.destPath);
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
				case "width":    builder = builder.width(javacast("int", step.args[1])); break;
				case "height":   builder = builder.height(javacast("int", step.args[1])); break;
				case "scale1":   builder = builder.scale(javacast("double", step.args[1])); break;
				case "scale2":   builder = builder.scale(javacast("double", step.args[1]), javacast("double", step.args[2])); break;
				case "outputFormat":     builder = builder.outputFormat(javacast("string", step.args[1])); break;
				case "outputFormatType": builder = builder.outputFormatType(javacast("string", step.args[1])); break;
				case "outputQuality":    builder = builder.outputQuality(javacast("float", step.args[1])); break;
				case "useOriginalFormat":builder = builder.useOriginalFormat(); break;
				case "keepAspectRatio":  builder = builder.keepAspectRatio(javacast("boolean", step.args[1])); break;
				case "useExifOrientation":builder = builder.useExifOrientation(javacast("boolean", step.args[1])); break;
				case "allowOverwrite":   builder = builder.allowOverwrite(javacast("boolean", step.args[1])); break;
				case "scalingMode":      builder = builder.scalingMode(_resolveScalingMode(step.args[1])); break;
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
		if (msg contains "OverwriteBlocked" || msg contains "already exists") {
			_throw("OverwriteBlocked", "Destination exists and allowOverwrite=false: " & arguments.destPath, msg);
		}
		if (msg contains "Unsupported") {
			_throw("UnsupportedImage", "Unsupported image format", msg);
		}
		_throw("IOError", "Thumbnailator failed: " & msg, msg);
	}
}
