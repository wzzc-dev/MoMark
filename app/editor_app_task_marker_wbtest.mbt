///|
/// The editor projects task list items as a vector checkbox marker, not a
/// `☑`/`☐` glyph: the box is a filled rounded square with a checkmark path
/// when checked, and a rounded outline when unchecked.
///
/// These assertions read the app's own paint commands, so they cover the whole
/// path from markdown source through the document projection to what the
/// window draws.

///|
/// Accent fill of a checked marker, mirrored from the marker geometry so a
/// drifting painted color fails the test.
fn task_marker_accent_color() -> @graphics.Color {
  @graphics.Color::rgba(r=0.122, g=0.435, b=0.922)
}

///|
/// Outline color of an unchecked marker.
fn task_marker_outline_color() -> @graphics.Color {
  @graphics.Color::rgba(r=0.573, g=0.600, b=0.631)
}

///|
test "markdown editor paints checked task as a filled checkbox" {
  let app = MarkdownEditorApp::new()
  app.set_document("- [x] finished item")
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  let mut box : @core.RoundedRect? = None
  let mut has_checkmark = false
  let mut has_glyph = false
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRect(rounded, color) =>
        if color == task_marker_accent_color() {
          box = Some(rounded)
        }
      @core.DrawCommand::DrawPath(path) =>
        if path.fill == Some(@core.Brush::solid(@graphics.Color::white())) {
          has_checkmark = true
        }
      @core.DrawCommand::DrawText({ text, .. }) =>
        if text.contains("☑") {
          has_glyph = true
        }
      _ => ()
    }
  }
  guard box is Some(rounded) else {
    fail("expected an accent-filled checkbox box")
  }
  // One em of the 17pt editor font, with a rounded silhouette.
  inspect(rounded.rect.size.width, content="17")
  inspect(rounded.rect.size.height, content="17")
  assert_true(rounded.radius > 0.0)
  assert_true(has_checkmark)
  assert_false(has_glyph)
}

///|
test "markdown editor paints unchecked task as an outlined box" {
  let app = MarkdownEditorApp::new()
  app.set_document("- [ ] pending item")
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  let mut box : @core.RoundedRect? = None
  let mut stroke_width = 0.0
  let mut has_checkmark = false
  let mut has_glyph = false
  for command in commands {
    match command {
      @core.DrawCommand::StrokeRoundedRect(rounded, color, width) =>
        if color == task_marker_outline_color() {
          box = Some(rounded)
          stroke_width = width
        }
      @core.DrawCommand::DrawPath(path) =>
        // The app draws other paths (caret, overlays); only the unchecked
        // marker's own checkmark would be white-filled here.
        if path.fill == Some(@core.Brush::solid(@graphics.Color::white())) {
          has_checkmark = true
        }
      @core.DrawCommand::DrawText({ text, .. }) =>
        if text.contains("☐") {
          has_glyph = true
        }
      _ => ()
    }
  }
  guard box is Some(rounded) else { fail("expected an outlined checkbox box") }
  // The outline is inset by half its stroke so the box stays inside the lane.
  let restored = rounded.rect.size.width + stroke_width
  assert_true((restored - 17.0).abs() < 0.0001)
  assert_true(stroke_width > 0.0)
  assert_false(has_checkmark)
  assert_false(has_glyph)
}

///|
/// A caret inside a task marker reveals its editable source `- [x] ` text, so
/// the vector box must yield to the raw text the user can edit.
test "markdown editor reveals raw task marker under the caret" {
  let app = MarkdownEditorApp::new()
  app.set_document("- [x] finished item")
  app.set_selection(6, None)
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  let mut has_raw_marker = false
  let mut has_box = false
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRect(_, color) =>
        if color == task_marker_accent_color() {
          has_box = true
        }
      @core.DrawCommand::DrawText({ text, .. }) =>
        if text.contains("[x]") {
          has_raw_marker = true
        }
      _ => ()
    }
  }
  assert_true(has_raw_marker)
  assert_false(has_box)
}
