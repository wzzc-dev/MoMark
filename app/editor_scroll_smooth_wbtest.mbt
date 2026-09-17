///|
/// Smooth-scroll state machine coverage: the wheel moves a target offset and
/// an animation closes the gap; anchor jumps interrupt the glide; hosts
/// without a timer fall back to instant jumps.

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
test "markdown editor wheel moves the scroll target and starts animating" {
  let app = smooth_scroll_test_app()
  let viewport_height = markdown_editor_viewport_height()
  // A wheel notch reports the offset after the control applied its clamp;
  // simulate a 96px down-notch by feeding the post-clamp offset directly.
  app.editor_scroll_wheel(96.0, viewport_height)
  assert_true(app.editor_scroll_animating)
  // The immediate first step moved the visible offset partway toward the
  // target but not all the way.
  assert_true(app.editor_scroll.y > 0.0)
  assert_true(app.editor_scroll.y < app.editor_scroll_target)
  assert_true(app.editor_scroll_target <= 96.0)
}

///|
test "markdown editor scroll animation converges on the target" {
  let app = smooth_scroll_test_app()
  let viewport_height = markdown_editor_viewport_height()
  app.editor_scroll_wheel(240.0, viewport_height)
  let target = app.editor_scroll_target
  let mut ticks = 0
  while app.editor_scroll_animating && ticks < 200 {
    ignore(app.editor_scroll_animation_step(viewport_height))
    ticks = ticks + 1
  }
  // The glide settles (finite ticks) and lands exactly on the target with
  // the animation flag cleared so the ticking subscription stops.
  assert_true(ticks > 1)
  assert_true(!app.editor_scroll_animating)
  // Whole-pixel snapping may land the last tick a fraction below the target;
  // the offset must sit on a whole pixel within half a pixel of the target.
  assert_true((app.editor_scroll.y - target).abs() <= 0.5)
  assert_eq(app.editor_scroll.y, app.editor_scroll.y.floor())
}

///|
test "markdown editor consecutive wheels accumulate into one target" {
  let app = smooth_scroll_test_app()
  let viewport_height = markdown_editor_viewport_height()
  app.editor_scroll_wheel(60.0, viewport_height)
  let first_target = app.editor_scroll_target
  app.editor_scroll_wheel(60.0, viewport_height)
  // The second notch extends the glide instead of restarting it from the
  // visible offset, so fast scrolling travels the summed distance.
  assert_true(app.editor_scroll_target > first_target)
  assert_true(app.editor_scroll_target <= 120.0 + 1.0)
}

///|
test "markdown editor wheel clamps at the document bottom" {
  let app = smooth_scroll_test_app()
  let viewport_height = markdown_editor_viewport_height()
  let max_scroll = app.editor_scroll_max_offset(viewport_height)
  assert_true(max_scroll > 0.0)
  app.editor_scroll_wheel(max_scroll * 4.0, viewport_height)
  assert_true(app.editor_scroll_target <= max_scroll)
  let mut ticks = 0
  while app.editor_scroll_animating && ticks < 200 {
    ignore(app.editor_scroll_animation_step(viewport_height))
    ticks = ticks + 1
  }
  // Whole-pixel snapping may land a fraction below the clamp limit.
  assert_true((app.editor_scroll.y - max_scroll).abs() <= 0.5)
}

///|
test "markdown editor anchor jump interrupts the animation" {
  let app = smooth_scroll_test_app()
  let viewport_height = markdown_editor_viewport_height()
  app.editor_scroll_wheel(400.0, viewport_height)
  assert_true(app.editor_scroll_animating)
  // Jumping to an outline heading (or a caret reveal) parks the scroll at
  // the anchor; no residual glide toward the old wheel target may run.
  app.editor_scroll_jump_to(123.0, viewport_height)
  assert_true(!app.editor_scroll_animating)
  assert_eq(app.editor_scroll.y, 123.0)
  assert_eq(app.editor_scroll_target, 123.0)
}

///|
test "markdown editor wheel without a timer host jumps instantly" {
  let app = smooth_scroll_test_app()
  app.editor_scroll_smooth_supported = false
  let before = app.editor_scroll
  // The control reports post-clamp offsets; with smoothing unavailable the
  // app copies the offset and never raises the animating flag.
  app.update_in_place(
    EditorScrollChanged(@geometry.Point::new(x=0.0, y=before.y + 96.0)),
  )
  assert_true(!app.editor_scroll_animating)
  assert_eq(app.editor_scroll.y, before.y + 96.0)
  assert_eq(app.editor_scroll_target, before.y + 96.0)
}

///|
test "markdown editor wheel with a timer host enters the eased path" {
  let app = smooth_scroll_test_app()
  app.editor_scroll_smooth_supported = true
  let before = app.editor_scroll.y
  // A 96px notch arrives as the post-clamp offset; the eased path takes the
  // immediate step and defers the rest to ticks.
  app.update_in_place(
    EditorScrollChanged(@geometry.Point::new(x=0.0, y=before + 96.0)),
  )
  assert_true(app.editor_scroll_animating)
  assert_true(app.editor_scroll.y < before + 96.0)
  assert_eq(app.editor_scroll_target, before + 96.0)
}

///|
test "markdown editor animation tick message steps and settles" {
  let app = smooth_scroll_test_app()
  let viewport_height = markdown_editor_viewport_height()
  app.editor_scroll_wheel(150.0, viewport_height)
  let target = app.editor_scroll_target
  let mut ticks = 0
  while app.editor_scroll_animating && ticks < 200 {
    app.update_in_place(EditorScrollAnimationTick)
    ticks = ticks + 1
  }
  assert_true(ticks > 1)
  // Whole-pixel snapping may land the final offset a fraction below the
  // target (the settle check accepts anything within half a pixel).
  assert_true((app.editor_scroll.y - target).abs() <= 0.5)
}
