/// Native-only host wiring shared by every platform entrypoint.
///
/// These are process-wide registrations that the shared `momark.runtime()`
/// factory installs before the first layout pass:
///
/// * `image_metrics.mbt` — synchronous image intrinsic-size reader for the
///   markdown layout.
/// * `svg_text.mbt` — pure-MoonBit vector glyph outlines for SVG `<text>`.
///
/// They live in their own package because the underlying providers
/// (`moui_richtext`'s filesystem reader, `moui_sun_renderer`'s font stack) are
/// native-only, while the `momark` and `momark/app` packages stay
/// renderer-neutral. Keep new native-only entrypoint wiring here rather than
/// in the individual `*/main.mbt` files.
