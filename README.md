# Thumbnailator

A CFML wrapper around the [Thumbnailator](https://github.com/coobird/thumbnailator) Java library (net.coobird.thumbnailator:thumbnailator:0.4.21). One CFC, two ways to call it: a fluent builder for the picky stuff, and a set of one-shot helpers for the 80% of jobs that just need "resize this file to that size".

It does resize, scale, crop, rotate, watermark, format conversion, and batch processing without making you write any Java interop code.

## Supported engines

- Adobe ColdFusion 2016 (and newer): 95/95 tests pass
- Lucee 5+ (tested on 5.4.8): 95/95 tests pass
- BoxLang 1+ (tested on 1.13.0): 51/95 tests pass

BoxLang 1.13 has a Java method dispatch bug that breaks calls to Thumbnailator methods taking `double` or `float` arguments. That hits `scale`, `rotate`, `outputQuality`, and the watermark `opacity` arg. 51 of the 95 tests pass; the rest are blocked on the upstream issue. The wrapper has BoxLang-aware code paths where they helped, but the dispatch problem is below the CFML layer. Adobe CF 2016+ and Lucee 5+ run the whole suite clean.

## Install

### ForgeBox

```
box install thumbnailator
```

### Manual via CommandBox

Drop `Thumbnailator.cfc` into your project and copy `lib/thumbnailator/thumbnailator-0.4.21.jar` somewhere your engine can load it. The bundled `Application.cfc` shows the pattern: it adds the JAR directory to `this.javaSettings.loadPaths`.

### Manual JAR placement

The wrapper loads the JAR from one of three places, in this order:

1. `THUMBNAILATOR_JAR_PATH` env var or system property (full path to a `.jar`)
2. `THUMBNAILATOR_JAR_DIR` env var or system property (directory containing the JAR)
3. Bundled `./lib/thumbnailator/` next to `Application.cfc` (the default fallback)

Set the env var in CommandBox via `server.json` or your OS, point it at wherever you keep the JAR, and you're done. No env var needed if you're happy with the bundled copy.

## Quickstart

```cfml
thumb = new Thumbnailator();
result = thumb.resize("photo.jpg", "small.jpg", 320, 240);
// result.width, result.height, result.sizeBytes, result.durationMs, result.format

thumb.of("photo.jpg").size(320, 240).outputQuality(0.85).toFile("small.jpg");
```

That's both styles. Pick whichever fits the call site.

A few more examples for orientation:

```cfml
// Square 200x200 crop from the center
thumb.cropImage("photo.jpg", "thumb.jpg", 200, 200);

// Rotate 90 degrees and save as PNG
thumb.of("photo.jpg").rotate(90).outputFormat("png").toFile("photo-rotated.png");

// Watermark a PNG bottom-right at 50% opacity, 10px inset
thumb.watermarkImage("photo.jpg", "stamped.jpg", "logo.png", "bottom_right", 0.5, 10);

// Bulk-resize every image in a folder
summary = thumb.batchResize("originals/", "thumbs/", 400, 400);
// summary.count, summary.totalMs, summary.totalBytes, summary.results
```

## One-shot API

Each one-shot returns a result struct: `["ok": true, "destPath": ..., "width": ..., "height": ..., "sizeBytes": ..., "format": ..., "durationMs": ...]`.

| Method | Signature | Notes |
|---|---|---|
| `resize` | `(srcPath, destPath, width, height, opts)` | Aspect-preserving by default |
| `scaleImage` | `(srcPath, destPath, factor, opts)` | Factor is a single multiplier |
| `rotateImage` | `(srcPath, destPath, degrees, opts)` | Clockwise; negative rotates the other way |
| `cropImage` | `(srcPath, destPath, width, height, positionName, opts)` | `positionName` defaults to `"center"` |
| `watermarkImage` | `(srcPath, destPath, wmPath, positionName, opacity, insets, opts)` | `insets` in pixels |
| `convertFormat` | `(srcPath, destPath, formatName, opts)` | Keeps dimensions, changes encoding |
| `createThumbnail` | `(srcPath, destPath, width, height, opts)` | Fits within w x h, quality 0.85, EXIF orientation honored |
| `batchResize` | `(srcDir, destDir, width, height, opts)` | Returns `["results": [], "totalMs": ..., "count": ..., "totalBytes": ...]` |
| `inspect` | `(srcPath)` | Returns width, height, format, sizeBytes, hasAlpha, exifOrientation |

The `opts` struct accepts any of: `quality`, `scalingMode`, `useExifOrientation`, `allowOverwrite`, `outputFormat`, `outputFormatType`, `keepAspectRatio`. Only keys you actually set get applied, so partial opts work.

## Fluent builder

Setters return `this`. Terminals run the call and return.

Source and sizing:

```
of(srcPath | array | directory)
size(width, height)
forceSize(width, height)
width(value)
height(value)
scale(factor)             single multiplier
scale(factorX, factorY)   independent axes
```

Geometry:

```
rotate(degrees)
crop(positionName)
sourceRegion(x, y, w, h)
sourceRegion(positionName, w, h)
```

Watermark:

```
watermark(wmPath, positionName, opacity)
watermark(wmPath, positionName, opacity, insets)
```

Output controls:

```
outputFormat(name)        jpg | png | gif | bmp
outputFormatType(subtype) format-specific subtype string
outputQuality(0..1)
useOriginalFormat()
```

Behavior flags:

```
scalingMode(name)
keepAspectRatio(true|false)
useExifOrientation(true|false)
allowOverwrite(true|false)
```

Terminals:

```
toFile(destPath)            -> result struct
toFiles(destDir, prefix)    -> array of result structs (one per source)
asBufferedImage()           -> java.awt.image.BufferedImage
```

The builder is reusable. You can call a terminal twice on the same chain and it'll write twice; setters accumulate into an internal op list and the terminal replays them onto a fresh Thumbnails builder.

## Reference values

Position names (used by `crop`, `sourceRegion`, and `watermark`):

```
center
top_left      top_center      top_right
left_center                   right_center
bottom_left   bottom_center   bottom_right
```

Format names: `jpg` (alias: `jpeg`), `png`, `gif`, `bmp`.

scalingMode names:

```
default                progressive bilinear (Thumbnailator's own default)
quality                progressive bilinear
speed                  bilinear
bilinear
bicubic
progressive_bilinear
```

## resize vs createThumbnail

Both fit an image inside a width-by-height box, but they pick different defaults.

`resize` is the plain one. It uses your `opts` as-is and applies the wrapper's general defaults (quality 0.85, scalingMode `quality`, EXIF orientation honored, overwrite allowed).

`createThumbnail` is tuned for thumbnail galleries: it forces JPEG output, sets quality to 0.85, picks `scalingMode("quality")`, and respects EXIF rotation. Use it when you don't care what the source format was and you just want a JPEG thumbnail.

## inspect

```cfml
info = thumb.inspect("photo.jpg");
// info.width, info.height, info.format, info.sizeBytes, info.hasAlpha, info.exifOrientation
```

`inspect` uses `javax.imageio.ImageIO` directly, not the Thumbnailator JAR. `exifOrientation` is the raw EXIF tag value (1..8) or 0 if the image has no EXIF orientation marker. Handy for "should I auto-rotate this before display" checks.

## Errors

The wrapper throws structured exceptions. All types live under the `Thumbnailator.*` namespace.

| Type | When |
|---|---|
| `Thumbnailator.SourceNotFound` | Source path missing or unreadable |
| `Thumbnailator.UnknownFormat` | `outputFormat` got a name not in the table |
| `Thumbnailator.UnknownPosition` | Position name not in the table |
| `Thumbnailator.UnknownScalingMode` | scalingMode name not in the table |
| `Thumbnailator.OverwriteBlocked` | Dest exists and `allowOverwrite(false)` is set |
| `Thumbnailator.InvalidArgument` | Numeric out of range (quality outside 0..1, etc.) |
| `Thumbnailator.IOError` | Wraps `java.io.IOException` from the JAR |
| `Thumbnailator.UnsupportedImage` | Wraps `UnsupportedFormatException` |

Each throw carries `message` and `detail` (root Java exception text if any). The exception `type` is one of the values in the table above, so you can `cfcatch` on the specific case you care about.

## Running the demo

```
box server start serverConfigFile=server.json
```

Then open http://localhost:8780/demo.cfm. The page has three regions: a gallery of canned recipes (resize, forceSize, crop, rotate, watermark, format convert), a sandbox form where you pick an operation and tweak the inputs, and a result panel that shows the source and result side by side along with the CFC code that produced it.

The other two profiles live at `server-lucee.json` and `server-boxlang.json`. Same command, different `serverConfigFile`.

## Running the tests

Start whichever server profile you want to test against, then hit `/tests/index.cfm`. The page prints PASS/FAIL lines for each assertion and a summary at the bottom. If anything failed, the response returns HTTP 500 so you can wire it into CI without parsing the HTML.

Tests are plain `.cfm` files with a tiny `assert()` helper. No MXUnit, no TestBox, nothing to install.

## License

MIT. See `LICENSE`.

Thumbnailator itself is also MIT-licensed; the bundled `lib/thumbnailator/thumbnailator-0.4.21.jar` ships with the upstream license intact.
