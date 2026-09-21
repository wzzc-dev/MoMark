///|
/// Large-file regression tests: a novel-shaped document (one huge
/// soft-wrapped paragraph, almost no blank lines — the shape that engages
/// the line-level viewport window) must place, paint and type with the
/// caret exactly like an ordinary document.

///|
fn large_file_novel_document() -> String {
  let parts : Array[String] = []
  for index in 0..<20000 {
    parts.push(
      "　　第" +
      index.to_string() +
      "段正文内容，模拟长篇小说的一行文字。",
    )
  }
  parts.join("\n")
}

///|
test "click after scrolling a large single-paragraph document places the caret at the click" {
  // The caret is parked at the front while the user scrolls deep into the
  // document, the exact sequence the large-file click defect describes:
  // the caret must land at the clicked line, not stay at the front.
  let app = MarkdownEditorApp::new()
  app.set_document(large_file_novel_document())
  app.editor_scroll_glide = MarkdownScrollGlide::settled(20000.0)
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=100.0),
          y=300.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  let caret = app.selection_caret()
  let total = app.document_session.source_length
  assert_true(caret > 10000)
  assert_true(caret < total)
}

///|
test "click without scrolling a large document moves the caret off the front" {
  let app = MarkdownEditorApp::new()
  app.set_document(large_file_novel_document())
  app.editor_scroll_glide = MarkdownScrollGlide::settled(0.0)
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=100.0),
          y=500.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  // With ~26px lines, a mid-viewport click is tens of lines into the
  // document, so the caret must move off offset 0.
  assert_true(app.selection_caret() > 100)
}

///|
test "drawn caret after a deep click sits near the click y" {
  let app = MarkdownEditorApp::new()
  app.set_document(large_file_novel_document())
  app.editor_scroll_glide = MarkdownScrollGlide::settled(20000.0)
  let runtime = app.runtime(width=980.0, height=640.0)
  let click_y = 300.0
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=100.0),
          y=click_y,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  // The caret rect (the host IME's window, derived from the same
  // window/document the paint uses) must be on the clicked line — within a
  // couple of line steps of the click y, not pinned at the top.
  let input = runtime.focused_text_input()
  assert_true(input.caret_rect.origin.y > click_y - 60.0)
  assert_true(input.caret_rect.origin.y < click_y + 60.0)
  // And the drawn caret must exist as a thin FillRect at that y.
  let commands = runtime.draw_commands()
  let mut caret_y = -1.0
  for command in commands {
    match command {
      @core.DrawCommand::FillRect(rect, _) =>
        if rect.size.width <= 2.0 && rect.size.height >= 10.0 {
          caret_y = rect.origin.y
        }
      _ => ()
    }
  }
  assert_true(caret_y > click_y - 60.0)
  assert_true(caret_y < click_y + 60.0)
}

///|
test "drawn caret follows the scroll while parked outside the window band" {
  // The caret stays at offset 0 while the user scrolls deep into the
  // document. The clipped window no longer contains the caret; the
  // painted caret must sit at the document's off-screen position (above
  // the viewport), never pinned to the first rendered line of the band.
  let app = MarkdownEditorApp::new()
  app.set_document(large_file_novel_document())
  app.editor_scroll_glide = MarkdownScrollGlide::settled(20000.0)
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  // Focus the editor without moving the caret (no pointer press), so the
  // input state reflects the parked caret at offset 0.
  assert_true(runtime.focus_key("markdown-editor"))
  let input = runtime.focused_text_input()
  assert_true(input.caret < 10)
  assert_true(input.caret_rect.origin.y < 0.0)
}
