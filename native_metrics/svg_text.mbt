///|
/// Install the vector glyph-outline resolver for SVG `<text>` runs (native
/// only). Every backend's SVG image decoder then swaps the bitmap-font
/// fallback for renderer-neutral vector outlines, so badge and icon markup
/// stays legible on Skia, WGPU, and the software rasterizer alike.
///
/// The resolver itself lives in the framework layer (`render/common` holds
/// the global registry, `moui_sun_renderer` provides the font-backed
/// implementation); this is the one app-level install call every native
/// entrypoint makes, alongside `register_image_metrics`. Returns false when
/// no default platform font could be loaded, leaving SVG text on the
/// renderer's bitmap fallback.
///
/// Not available on wasm: `moui_sun_renderer` is native-only, so the web
/// build keeps the previous bitmap behavior by simply never installing it.
pub fn install_svg_text() -> Bool {
  @svg_text.install_svg_text_path_resolver()
}
