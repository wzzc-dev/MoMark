///|
/// Optional command-line argument: `macos_skia <document.md>` opens that
/// document on startup instead of the sample.
fn initial_document_from_args() -> String? {
  let args = @env.args()
  if args.length() > 1 && args[1] != "" {
    Some(args[1])
  } else {
    None
  }
}

///|
/// Runs on the async runtime so remote image fetches can interleave with the
/// window pump.
///
/// The renderer-neutral image pipeline resolves bytes synchronously, so an
/// `https:` source can only be fetched without blocking the UI if something
/// else owns the network wait. `remote_image_starter` enqueues those sources,
/// and `remote_image_worker_loop` fetches them as a sibling task of the pump.
/// Local raster and SVG assets keep their unchanged synchronous path.
async fn main {
  /// Image intrinsic-size probe for the markdown layout (native only).
  @native_metrics.register_image_metrics()
  // Vector outlines for SVG `<text>` (badge legibility): pure-MoonBit glyph
  // outlines replace the renderer's bitmap fallback. No-op when no default
  // platform font loads.
  let _ = @svg_text.install_svg_text_path_resolver()
  let remote_images = @image_remote.RemoteImageOwner::new()
  @window_image.window_image_task_starter_install(
    @image_remote.remote_image_starter(remote_images),
  )
  let runtime = @momark.runtime(
    environment=@macos_backend.app_environment(),
    initial_document_path=initial_document_from_args(),
  )
  let menus = @momark.application_menus()
  let window_task : async () -> Unit = async fn() {
    @runtime
    .run_app("MoUI Markdown Editor", runtime)
    .render_all(
      @render_skia.from_env(platform=@render_skia.NativeGpuPlatform::MacOS),
    )
    .backend(
      @macos_backend.entry(
        options=@macos_backend.MacosHostAppOptions::new(
          transparent_titlebar=true,
          on_ready=Some(
            @macos_backend.application_menu_on_ready(menus, runtime),
          ),
          min_window_size=Some(@dpi.LogicalSize::LogicalSize(816.0, 480.0)),
        ),
        // Honors the same first-frame smoke switch as every other MoUI app, so
        // the async-pump entry can be asserted in CI (exit 0 after the first
        // presented frame).
        smoke_options=@macos_backend.MacosHostSmokeOptions::new(
          first_frame_smoke_auto_exit=@momark.env_flag("MOUI_FIRST_FRAME_EXIT"),
        ),
      ),
    )
    .run_async_pump()
  }
  try {
    // The worker is a cancellable child of the window task, so quitting the
    // window tears it down instead of leaving it parked on an empty queue.
    @image_remote.with_remote_images(remote_images, window=window_task)
  } catch {
    err => println("MoMark exited with error: \{err}")
  }
}
