///|
/// Scroll behaviour after the live glide moved into the editor element.
///
/// The app no longer owns a per-tick glide: a wheel event must be paint-only
/// (no root rebuild, no layout pass), and the app learns the position once per
/// gesture through `EditorScrollSettled`. The continuity/easing maths itself is
/// covered by `moui_richtext`'s transient-scroll tests.

///|
fn smooth_scroll_test_app(
  document_paragraphs~ : Int32 = 200,
) -> MarkdownEditorApp {
  let app = MarkdownEditorApp::new()
  let source : Array[String] = []
  for index in 0..<document_paragraphs {
    source.push("Paragraph \{index} with some flowing text to grow the page.")
  }
  app.load_document_for_test(source.join("\n\n"), path="doc.md")
  app
}

///|
fn smooth_scroll_test_runtime(app : MarkdownEditorApp) -> @runtime.AppRuntime {
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  runtime
}

///|
fn smooth_scroll_dispatch_wheel(
  app : MarkdownEditorApp,
  runtime : @runtime.AppRuntime,
  wheel_delta_y : Double,
) -> Unit {
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=8.0),
          y=254.0,
        ),
        phase=@core.PointerPhase::Move,
        wheel_delta=@geometry.Point::new(x=0.0, y=wheel_delta_y),
      ),
    ),
  )
}

///|
test "wheel scrolls without rebuilding or laying out the program root" {
  let app = smooth_scroll_test_app()
  let runtime = smooth_scroll_test_runtime(app)
  smooth_scroll_dispatch_wheel(app, runtime, -220.0)
  assert_false(runtime.needs_rebuild())
  assert_false(runtime.needs_layout())
  assert_true(runtime.needs_paint())
  runtime.advance_time(32.0)
  ignore(runtime.draw_frame())
  assert_true(app.editor_painted_scroll_y_for_test() > 0.0)
}

///|
test "one settle notification reaches the app after the glide stops" {
  let app = smooth_scroll_test_app()
  let runtime = smooth_scroll_test_runtime(app)
  ignore(smooth_scroll_dispatch_wheel(app, runtime, -220.0))
  // The paint reports `animating`, so the frame pump owns the settle check.
  ignore(runtime.draw_frame())
  runtime.dispatch_event(
    @core.AppEvent::FrameTick(@core.Frame::new(time_ms=2000.0, delta_ms=16.0)),
  )
  ignore(runtime.draw_frame())
  assert_true(app.editor_scroll_settled_y > 0.0)
  let settled = app.editor_scroll_settled_y
  // A later tick must not emit another settle update for the same gesture.
  runtime.dispatch_event(
    @core.AppEvent::FrameTick(@core.Frame::new(time_ms=2100.0, delta_ms=16.0)),
  )
  ignore(runtime.draw_frame())
  assert_eq(app.editor_scroll_settled_y, settled)
}

///|
test "programmatic scroll request applies once and a newer id wins" {
  let app = smooth_scroll_test_app()
  app.park_scroll_for_test(180.0)
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  let first = app.editor_scroll_y()
  assert_true((first - 180.0).abs() < 1.0)
  // Rebuilding with the same request id must not restart or move the scroll.
  ignore(runtime.draw_frame())
  assert_eq(app.editor_scroll_y(), first)
  app.park_scroll_for_test(40.0)
  let next_runtime = app.runtime(width=980.0, height=640.0)
  ignore(next_runtime.draw_frame())
  ignore(next_runtime.draw_frame())
  assert_true((app.editor_painted_scroll_y_for_test() - 40.0).abs() < 1.0)
}

///|
test "scroll request clamps to the document range" {
  let app = smooth_scroll_test_app()
  app.park_scroll_for_test(1_000_000.0)
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  let painted = app.editor_painted_scroll_y_for_test()
  let max_scroll = app.editor_scroll_max_offset(640.0)
  assert_true(painted <= max_scroll + 1.0)
  assert_true(painted > 0.0)
}

///|
test "document switch resets the transient scroll to the top" {
  let app = smooth_scroll_test_app()
  app.park_scroll_for_test(180.0)
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  assert_true(app.editor_scroll_y() > 0.0)
  app.load_document_for_test("A fresh document", path="other.md")
  let next_runtime = app.runtime(width=980.0, height=640.0)
  ignore(next_runtime.draw_frame())
  ignore(next_runtime.draw_frame())
  assert_eq(app.editor_painted_scroll_y_for_test(), 0.0)
}
