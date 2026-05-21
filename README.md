# Thumbnailator

[![ForgeBox Version](https://www.forgebox.io/api/v1/entry/thumbnailator/badges/version)](https://www.forgebox.io/view/thumbnailator)
[![ForgeBox Downloads](https://www.forgebox.io/api/v1/entry/thumbnailator/badges/downloads)](https://www.forgebox.io/view/thumbnailator)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A CFML wrapper around the [Thumbnailator](https://github.com/coobird/thumbnailator) Java library (net.coobird.thumbnailator:thumbnailator:0.4.21). One CFC, two ways to call it: a fluent builder for the picky stuff, and a set of one-shot helpers for the 80% of jobs that just need "resize this file to that size".

It does resize, scale, crop, rotate, watermark, format conversion, and batch processing without making you write any Java interop code.

## Supported engines

- Adobe ColdFusion 2016 (and newer): 105/105 tests pass
- Lucee 5+ (tested on 5.4.8): 105/105 tests pass
- BoxLang 1+ (tested on 1.13.0): 105/105 tests pass

BoxLang needs the `bx-compat-cfml` module enabled and JDK 17+. The bundled `server-boxlang.json` sets both. If you wire BoxLang up yourself, copy the `boxlang` block from `server-boxlang.json` into your own config. The `Application.cfc` adds each JAR file explicitly to `this.javaSettings.loadPaths` (BoxLang's classloader doesn't scan directories the way Adobe and Lucee do), so pointing it at the bundled `lib/thumbnailator/` works out of the box.

### BoxLang cold-start nuance

On a freshly started BoxLang server, the very first HTTP request after boot can fail with `[net.coobird.thumbnailator.Thumbnails] has not been located in the [java] resolver`. This is a BoxLang lifecycle quirk: the JAR loader in `Application.cfc` has not applied `javaSettings.loadPaths` by the time the first request hits the dispatcher. Any subsequent request will warm the classloader. Hit `/demo.cfm` or any single test file once, and the full `tests/index.cfm` aggregator then passes 105/105. Adobe CF 2016 and Lucee do not have this race.

### BoxLang server profiles

Three BoxLang server profiles are provided:

- `server-boxlang.json` (port 8782): pure BoxLang, no compat module
- `server-boxlang-adobe.json` (port 8783): bx-compat-cfml engine=adobe
- `server-boxlang-lucee.json` (port 8784): bx-compat-cfml engine=lucee

All three pass 105/105 after the classloader warm-up described above. The compat module is not strictly required for the wrapper to function. It changes how BoxLang handles Adobe-flavored and Lucee-flavored idioms in surrounding code, which matters if you mix the wrapper into a larger codebase written against one of those dialects.

## Install

### ForgeBox (CFML library)

```
box install thumbnailator
```

CommandBox fetches the wrapper from ForgeBox and the Thumbnailator JAR from Maven Central in one step. The JAR lands at `modules/thumbnailator/lib/thumbnailator/thumbnailator-0.4.21.jar` and `Application.cfc` picks it up automatically.

### Developing on the wrapper

Clone the repo, then:

```
box install
```

The JAR is not in the GitHub repo (`lib/` is gitignored). `box install` reads the project's `box.json` and pulls the JAR from Maven Central into `lib/thumbnailator/`. After that you can `box server start` against any of the server profiles.

### Manual JAR placement

If you can't reach Maven Central (air-gapped, corporate firewall), drop the JAR somewhere your engine can load it and point the wrapper at it via env var. The wrapper resolves the JAR from one of three places, in this order:

1. `THUMBNAILATOR_JAR_PATH` env var or system property (full path to a `.jar`)
2. `THUMBNAILATOR_JAR_DIR` env var or system property (directory containing the JAR)
3. `./lib/thumbnailator/` next to `Application.cfc` (where `box install` places it)

Set the env var in CommandBox via `.env` or your OS, point it at wherever you keep the JAR, and you're done.

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

The `opts` struct accepts any of: `quality`, `scalingMode`, `useExifOrientation`, `allowOverwrite`, `outputFormat`, `outputFormatType`, `keepAspectRatio`, `exifPassthrough`. Only keys you actually set get applied, so partial opts work.

### exifPassthrough

`exifPassthrough` (default `false`) - when `true`, the wrapper copies the source JPEG's APP1/Exif segment into the destination JPEG after Thumbnailator has finished writing, then forces the EXIF `Orientation` tag to `1` (normal) so downstream viewers don't double-rotate the image. The Thumbnailator Java library writes through `javax.imageio`, which strips APP1; this opt is the recovery hook.

```cfml
thumb.resize("photo.jpg", "small.jpg", 320, 240, ["exifPassthrough": true]);
// Make, Model, DateTimeOriginal, GPS tags, etc. all survive. Orientation is reset to 1.
```

Only meaningful when both source and destination are JPEG. Silently skipped if either side is PNG, GIF, or BMP (those formats don't carry EXIF natively in the same APP1 form). Silently skipped if the source has no APP1/Exif segment at all.

Caveat: the wrapper strips any APP1/Exif segment already present in the dest (Thumbnailator rarely writes one but some `outputFormatType` paths might) before splicing the source segment, to avoid duplicate APP1 markers. ICC, XMP, and other ancillary segments are not transferred - this is a deliberately narrow EXIF-only passthrough.

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
