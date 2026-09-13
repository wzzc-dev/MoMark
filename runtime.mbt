///|
/// Build the editor runtime for a native host.
///
/// Every platform entrypoint (`macos_skia`, `macos_wgpu`, `windows_*`,
/// `linux_*`) calls this before launching, so the host-side process-wide
/// wiring lives here rather than being repeated per entrypoint:
///
/// * `register_image_metrics` installs the synchronous filesystem reader that
///   lets the markdown layout reserve an image's real box at projection time.
/// * `install_svg_text` swaps SVG `<text>` bitmap fallback for pure-MoonBit
///   vector glyph outlines (badge legibility).
///
/// Both are process-wide registrations that must run before the first layout
/// pass, which `new_program_with_dimensions` below does not trigger on its
/// own. `install_svg_text` returns false when no default platform font could
/// be loaded; SVG text then keeps the renderer's bitmap fallback.
pub fn runtime(
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  width? : Double = 1000.0,
  height? : Double = 640.0,
  initial_document_path? : String? = None,
) -> @runtime.AppRuntime {
  @native_metrics.register_image_metrics()
  let _ = @native_metrics.install_svg_text()
  @runtime.new_program_with_dimensions(
    program=@app.MarkdownEditorApp::new().program(
      environment~,
      initial_document_path~,
    ),
    width~,
    height~,
  )
}

///|
/// Shared environment-flag convention for the platform entrypoints, matching
/// the other desktop examples (e.g. `MOUI_FIRST_FRAME_EXIT=1` smoke runs).
pub fn env_flag(name : String) -> Bool {
  @env.get_env_var(name) == Some("1")
}

///|
pub fn application_menus() -> Array[@services.ApplicationMenu] {
  @app.markdown_editor_application_menus()
}
