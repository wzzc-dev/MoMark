///|
/// Scroll-glide coverage: wheel events build a `MarkdownScrollGlide` stamped
/// on the animation clock, and the editor view evaluates it per frame. The
/// glide is a pure function of time, so every property here is asserted by
/// evaluating it on a clock grid instead of stepping a timer.
///
/// The invariant most of these tests protect is *continuity*: a glide re-keyed
/// by a new event always starts from the offset being shown at that moment, so
/// no input pattern — a dense stream landing mid-ease, a direction reversal, a
/// clamp at the document edge — can teleport the view.

///|
fn smooth_scroll_test_app(
  document_paragraphs? : Int = 200,
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
/// A wheel event as the editor control reports it: the raw host delta
/// (macOS convention: negative scrolls down) plus the animation-clock time
/// it was handled at.
fn smooth_scroll_wheel(
  app : MarkdownEditorApp,
  wheel_delta_y : Double,
  clock_ms : Double,
) -> Unit {
  app.update_in_place(
    EditorScrolled(
      wheel_delta_y,
      clock_ms,
      1120.0,
      markdown_editor_viewport_height(),
    ),
  )
}

///|
/// Measurement happens during paint, while wheel input is handled before the
/// next root build. The app update must consume that pending compensation
/// before it derives a new wheel target, otherwise it re-keys from stale
/// geometry and the next frame jumps back to the old target.
test "wheel consumes pending geometry compensation before re-keying" {
  let app = smooth_scroll_test_app()
  ignore(@moui_richtext.markdown_scroll_take_geometry_compensation())
  smooth_scroll_wheel(app, -200.0, 100.0)
  let before = app.editor_scroll_glide
  let shown = before.exact_offset_at(116.0)
  @moui_richtext.markdown_scroll_publish_geometry_compensation(40.0)
  smooth_scroll_wheel(app, -20.0, 116.0)
  let after = app.editor_scroll_glide
  assert_eq(after.from_y, shown + 40.0)
  assert_true(after.to_y > before.to_y + 20.0)
}

///|
test "markdown editor wheel builds an easing glide from the shown position" {
  let app = smooth_scroll_test_app()
  smooth_scroll_wheel(app, -96.0, 100.0)
  let glide = app.editor_scroll_glide
  assert_eq(glide.from_y, 0.0)
  assert_eq(glide.to_y, 96.0)
  assert_eq(glide.start_ms, 100.0)
  // Just started: still at the origin, and animating.
  assert_eq(glide.offset_at(100.0), 0.0)
  assert_true(glide.is_animating(100.0))
  // Mid-flight the offset advances without overshooting.
  let mid = glide.offset_at(150.0)
  assert_true(mid > 0.0)
  assert_true(mid < 96.0)
  // Settles exactly on the target and stops animating.
  assert_eq(glide.offset_at(5000.0), 96.0)
  assert_false(glide.is_animating(5000.0))
}

///|
test "markdown editor consecutive discrete wheels accumulate into one target" {
  let app = smooth_scroll_test_app()
  smooth_scroll_wheel(app, -60.0, 100.0)
  let first = app.editor_scroll_glide
  let first_target = first.to_y
  // Where the first glide's *state* is when the second notch arrives. The
  // re-key continues from the exact offset (paint alone snaps to the device
  // grid), so this is the exact value, not the rounded display one.
  let shown = first.exact_offset_at(200.0)
  assert_true(shown > 0.0)
  assert_true(shown < first_target)
  // 100ms later the first glide is still gliding but the gap is far beyond
  // the stream window: this is a discrete notch that extends the target.
  smooth_scroll_wheel(app, -60.0, 200.0)
  let glide = app.editor_scroll_glide
  assert_true(glide.to_y > first_target)
  assert_true(glide.to_y <= 120.0 + 1.0)
  // The new glide eases from the position actually being shown.
  assert_eq(glide.from_y, shown)
  assert_eq(glide.start_ms, 200.0)
}

///|
/// Streams are detected by event *time*, not by counting animation ticks:
/// events a few ms apart are one OS-animated gesture, so they get the short
/// time constant instead of the full notch ease. The target still accumulates
/// the raw deltas, and the shown position still continues from where it is.
test "markdown editor continuous wheel streams use the short time constant" {
  let app = smooth_scroll_test_app()
  smooth_scroll_wheel(app, -12.0, 1000.0)
  assert_true(app.editor_scroll_glide.is_animating(1000.0))
  assert_eq(app.editor_scroll_glide.tau_ms, 90.0)
  // 8ms later — a 120Hz stream.
  smooth_scroll_wheel(app, -12.0, 1008.0)
  let glide = app.editor_scroll_glide
  assert_eq(glide.tau_ms, markdown_editor_scroll_stream_tau_ms())
  assert_true(glide.tau_ms < 90.0)
  // The target accumulated both deltas exactly.
  assert_eq(glide.to_y, 24.0)
  // Light smoothing, not a snap: it continues from the shown offset.
  assert_true(glide.from_y >= 0.0)
  assert_true(glide.from_y < glide.to_y)
  // And it lands on the accumulated offset once the gesture ends.
  assert_eq(glide.offset_at(9000.0), 24.0)
}

///|
/// The user-visible jump this guards: a dense event landing while a notch is
/// still easing used to snap the view to the accumulated target — a forward
/// teleport of whatever the ease had left, and a *backward* one when the
/// direction reversed. Continuity means the offset evaluated across the event
/// boundary does not move more than one frame of travel.
test "markdown editor reversing mid-glide does not teleport the view" {
  let app = smooth_scroll_test_app()
  smooth_scroll_wheel(app, -480.0, 1000.0)
  let before = app.editor_scroll_glide
  // A frame of display time passes, then the user reverses.
  let shown = before.offset_at(1016.667)
  assert_true(shown > 0.0)
  assert_true(shown < 480.0)
  // Reverse hard enough that the new target lands *behind* the shown offset:
  // the accumulated target is 480 - 200*... = clamped toward 0, below the ~71
  // px already shown. This is the exact shape of the reported backward jump.
  smooth_scroll_wheel(app, 480.0, 1016.667)
  let after = app.editor_scroll_glide
  // The new target is behind where the view is.
  assert_true(after.to_y < shown)
  // The new glide starts exactly where the old one was showing, so the frame
  // at the event boundary is unchanged...
  assert_eq(after.offset_at(1016.667), shown)
  // ...and the following frames ease down toward the target instead of
  // snapping to it. A snap would land within one frame of after.to_y.
  let next = after.offset_at(1016.667 + 16.667)
  assert_true(next < shown)
  assert_true(next > after.to_y)
}

///|
/// Same continuity invariant across the document-bottom clamp: an in-flight
/// notch whose target is clamped must keep moving from the shown offset
/// instead of being flung to (or past) the clamped edge.
test "markdown editor clamping mid-glide does not teleport the view" {
  let app = smooth_scroll_test_app()
  let viewport_height = markdown_editor_viewport_height()
  let max_scroll = app.editor_scroll_max_offset(viewport_height)
  smooth_scroll_wheel(app, -(max_scroll - 40.0), 1000.0)
  let shown = app.editor_scroll_glide.offset_at(1016.667, scale=2.0)
  assert_true(shown < max_scroll)
  // A second notch far past the end: the target clamps, the view eases.
  smooth_scroll_wheel(app, -4000.0, 1016.667)
  let glide = app.editor_scroll_glide
  assert_true(glide.to_y <= max_scroll)
  // The displayed position is continuous across the re-key: the same device-
  // snapped offset is shown just before and just after the event, so nothing
  // teleports — the view eases toward the clamped target instead.
  assert_eq(glide.offset_at(1016.667, scale=2.0), shown)
  assert_true(glide.offset_at(1016.667, scale=2.0) < max_scroll)
  assert_true((glide.offset_at(9000.0) - max_scroll).abs() <= 1.0)
}

///|
/// A late measured-height update may reduce the scrollable range while a
/// glide is in flight. Re-keying must start from the clamped displayed point,
/// rather than easing backwards from an offset that no longer exists.
test "markdown editor rekeys from the current range after content shrink" {
  let app = smooth_scroll_test_app()
  let viewport_height = markdown_editor_viewport_height()
  let max_scroll = app.editor_scroll_max_offset(viewport_height)
  app.editor_scroll_glide = MarkdownScrollGlide::new(
    from_y=max_scroll - 20.0,
    to_y=max_scroll + 240.0,
    start_ms=1000.0,
    tau_ms=90.0,
  )
  // Simulate the range having shrunk before the next wheel event by using a
  // short document as the live session.
  app.load_document_for_test("short", path="doc.md")
  let new_max = app.editor_scroll_max_offset(viewport_height)
  smooth_scroll_wheel(app, -8.0, 1016.667)
  let glide = app.editor_scroll_glide
  assert_true(glide.from_y >= 0.0)
  assert_true(glide.from_y <= new_max)
  assert_true(glide.to_y <= new_max)
}

///|
/// Regression: the stream/notch decision must not depend on the pointer
/// contract's `time_ms` (the input path never populates it — it stays 0.0),
/// and a discrete notch arriving while the previous glide is still in flight
/// must keep easing instead of being mistaken for momentum.
test "markdown editor discrete notch eases while the previous glide is in flight" {
  let app = smooth_scroll_test_app()
  smooth_scroll_wheel(app, -120.0, 1000.0)
  // 100ms later the first glide is still gliding (τ = 90ms) but the gap is
  // far beyond the stream window: this is a discrete notch.
  assert_true(app.editor_scroll_glide.is_animating(1100.0))
  smooth_scroll_wheel(app, -120.0, 1100.0)
  let glide = app.editor_scroll_glide
  assert_eq(glide.start_ms, 1100.0)
  assert_true(glide.to_y > 120.0)
  // It eases from the shown position, not by snapping to the accumulated
  // offset: the glide still has distance to cover.
  assert_true(glide.from_y < glide.to_y)
  assert_true(glide.is_animating(1100.0))
}

///|
test "markdown editor glide clamps at the document bottom" {
  let app = smooth_scroll_test_app()
  let viewport_height = markdown_editor_viewport_height()
  let max_scroll = app.editor_scroll_max_offset(viewport_height)
  assert_true(max_scroll > 0.0)
  smooth_scroll_wheel(app, -max_scroll * 4.0, 100.0)
  let glide = app.editor_scroll_glide
  assert_true(glide.to_y <= max_scroll)
  assert_true((glide.offset_at(9000.0) - max_scroll).abs() <= 1.0)
}

///|
test "markdown editor anchor jump settles the glide" {
  let app = smooth_scroll_test_app()
  let viewport_height = markdown_editor_viewport_height()
  smooth_scroll_wheel(app, -400.0, 100.0)
  assert_true(app.editor_scroll_glide.is_animating(100.0))
  // Jumping to an outline heading (or a caret reveal) parks the scroll at
  // the anchor; no residual glide toward the old wheel target may run.
  app.editor_scroll_jump_to(123.0, viewport_height)
  let glide = app.editor_scroll_glide
  assert_eq(glide.offset_at(0.0), 123.0)
  assert_eq(glide.offset_at(9999.0), 123.0)
  assert_false(glide.is_animating(9999.0))
}

///|
/// The glide decelerates monotonically to an exact landing: no end-of-glide
/// snap. A settle rule keyed on "the step got small" used to park the offset
/// ~11px short and then jump to the target — one visible frame-to-frame hop
/// on every notch.
test "markdown editor glide tail has no terminal jump" {
  let app = smooth_scroll_test_app()
  smooth_scroll_wheel(app, -96.0, 0.0)
  let glide = app.editor_scroll_glide
  // Sample on a 60Hz grid like the display does.
  let history : Array[Double] = []
  let mut clock = 0.0
  while glide.is_animating(clock) && clock < 5000.0 {
    history.push(glide.offset_at(clock))
    clock = clock + 16.667
  }
  assert_true(history.length() > 4)
  assert_eq(glide.offset_at(5000.0), 96.0)
  // Every one of the last four visible steps moved at most two pixels.
  let last = history.length() - 1
  for index in markdown_editor_max_int(1, last - 3)..<=last {
    let moved = (history[index] - history[index - 1]).abs()
    assert_true(moved <= 2.0)
  }
}

///|
/// Momentum tail events have small deltas and land while the eased glide is
/// still moving fast. The glide eases from the position actually being shown,
/// so the offset sequence is monotonic in the scroll direction — the stale
/// absolute offset that used to make these snap backward is gone.
test "markdown editor momentum tail events never snap the scroll backward" {
  let app = smooth_scroll_test_app()
  smooth_scroll_wheel(app, -480.0, 1000.0)
  let history : Array[Double] = [app.editor_scroll_glide.offset_at(1000.0)]
  let mut clock = 1000.0
  for _ in 0..<20 {
    clock = clock + 8.0
    // A small momentum tail delta inside the stream window.
    smooth_scroll_wheel(app, -3.0, clock)
    history.push(app.editor_scroll_glide.offset_at(clock))
  }
  for index in 1..<history.length() {
    assert_true(history[index] >= history[index - 1])
  }
}

///|
/// Same invariant mirrored for upward scrolling (wheel delta positive): the
/// offset sequence never increases mid-stream.
test "markdown editor upward momentum stream never snaps forward" {
  let app = smooth_scroll_test_app()
  let viewport_height = markdown_editor_viewport_height()
  app.editor_scroll_jump_to(400.0, viewport_height)
  smooth_scroll_wheel(app, 480.0, 1000.0)
  let history : Array[Double] = [app.editor_scroll_glide.offset_at(1000.0)]
  let mut clock = 1000.0
  for _ in 0..<20 {
    clock = clock + 8.0
    smooth_scroll_wheel(app, 3.0, clock)
    history.push(app.editor_scroll_glide.offset_at(clock))
  }
  for index in 1..<history.length() {
    assert_true(history[index] <= history[index - 1])
  }
}

///|
/// The glide is a pure function of elapsed time, so sampling it on the vsync
/// grid shows no beat: consecutive samples advance by smoothly varying
/// amounts. A timer tick grid (the old 8ms ticker against a 16.7ms refresh)
/// alternated between 2 and 3 steps and read as frame-to-frame stutter.
test "markdown editor glide sampled on the vsync grid does not beat" {
  let app = smooth_scroll_test_app()
  smooth_scroll_wheel(app, -480.0, 0.0)
  let glide = app.editor_scroll_glide
  let sampled : Array[Double] = []
  let mut clock = 0.0
  while glide.is_animating(clock) && clock < 5000.0 {
    sampled.push(glide.offset_at(clock))
    clock = clock + 16.667
  }
  assert_true(sampled.length() > 4)
  let sample_count = sampled.length()
  for index in 1..<(sample_count - 1) {
    let previous = sampled[index] - sampled[index - 1]
    let next = sampled[index + 1] - sampled[index]
    if previous > 0.5 && next > 0.5 {
      let ratio = (next / previous).abs()
      assert_true(ratio <= 2.5)
    }
  }
}
