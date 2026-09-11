///|
/// The Typora paragraph rhythm for blank source lines.
///
/// Typora separates sibling blocks with a collapsed `p { margin: 0.8em 0 }`
/// (its stock Github theme measures 12.8px at the 16px root) and has no node
/// at all for a blank line, so several blank lines between blocks render
/// exactly like one. MoMark keeps the blank source line as a block — the
/// canonical source stays the editable truth — but the block is a separator:
/// the paragraph supplies 0.4em through its inset and the run of blank lines
/// supplies the other 0.4em with no line box. The one exception is the blank
/// line the caret occupies, which is the writing line Enter just created;
/// Typora's empty paragraph is a full line box too.
fn blank_line_gap_blocks(
  app : MarkdownEditorApp,
  caret : Int,
) -> Array[@moui_richtext.RichTextBlock] {
  let window = app.document_session.rich_text_window(
    { caret, selection: None },
    base=@text.FontSpec::new(size=17.0),
    source_mode=false,
    focus_mode=false,
    base_dir=None,
    scroll_y=0.0,
    viewport_height=640.0,
    overscan=0.0,
    content_width=720.0,
  )
  let gaps : Array[@moui_richtext.RichTextBlock] = []
  for block in window.document.blocks {
    let is_gap = block.runs.is_empty() &&
      block.prefix == "" &&
      block.table is None &&
      !block.rule
    if is_gap {
      gaps.push(block)
    }
  }
  gaps
}

///|
/// Gap metrics are `scale * 17.0`, which is not exactly representable in
/// binary floating point, so compare with a tolerance instead of a literal.
fn blank_line_height_matches(height : Double?, em : Double) -> Bool {
  match height {
    Some(value) => {
      let diff = value - 17.0 * em
      (if diff < 0.0 { -diff } else { diff }) < 0.0001
    }
    None => false
  }
}

///|
/// Total rendered height of the blank gap blocks in a window.
fn blank_line_gap_run_height(gaps : Array[@moui_richtext.RichTextBlock]) -> Double {
  let mut height = 0.0
  for gap in gaps {
    height = height + gap.inset.top + gap.inset.bottom
    match gap.line_height {
      Some(line_height) => height = height + line_height
      None => ()
    }
  }
  height
}

///|
test "markdown editor blank line keeps the typora paragraph rhythm" {
  // One blank line between two paragraphs: the separator carries the
  // paragraph margin (0.4em of the 17px editor font) with no line box of its
  // own, so the whole paragraph gap is Typora's 0.8em.
  let app = MarkdownEditorApp::new()
  app.set_document("Alpha paragraph here.\n\nBeta paragraph here.")
  let gaps = blank_line_gap_blocks(app, 0)
  inspect(gaps.length(), content="1")
  assert_true(blank_line_height_matches(gaps[0].line_height, 0.0))
  assert_true(blank_line_height_matches(Some(gaps[0].inset.top), 0.4))
  inspect(gaps[0].inset.bottom, content="0")
  inspect(app.document(), content="Alpha paragraph here.\n\nBeta paragraph here.")
}

///|
test "markdown editor blank lines alternate separator and empty line" {
  // Typora spends one blank line on the paragraph break and one more on each
  // empty line it shows, so a run alternates separator / writing line /
  // separator: three blank lines render as one visible empty line, and only
  // that middle gap carries a line box the caret can sit on.
  let app = MarkdownEditorApp::new()
  app.set_document("Alpha paragraph here.\n\n\n\nBeta paragraph here.")
  let gaps = blank_line_gap_blocks(app, 0)
  inspect(gaps.length(), content="3")
  assert_true(blank_line_height_matches(gaps[0].line_height, 0.0))
  assert_true(blank_line_height_matches(Some(gaps[0].inset.top), 0.4))
  assert_true(blank_line_height_matches(gaps[1].line_height, 1.55))
  assert_true(blank_line_height_matches(gaps[2].line_height, 0.0))
  assert_true(blank_line_height_matches(Some(gaps[2].inset.top), 0.4))
  // The run is separator + writing line + separator, 2.75em in total.
  assert_true(blank_line_height_matches(Some(blank_line_gap_run_height(gaps)), 2.75))
}

///|
/// Painted y of every rendered run of `text`, in paint order.
fn blank_line_painted_rows(
  commands : Array[@core.DrawCommand],
  text : String,
) -> Array[Double] {
  let rows : Array[Double] = []
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          rows.push(frame.origin.y)
        }
      _ => ()
    }
  }
  rows
}

///|
test "markdown editor blank line rhythm matches the typora reference" {
  // The reference document compared against Typora is
  // "123\n123\n\n123\n\n\n\n123": a soft-wrapped pair, then a paragraph
  // after one blank line, then a paragraph after three. Typora's stock Github
  // theme renders 1.56em, 2.34em and 4.72em between the text tops; MoMark
  // measures the same proportions in its own 17px body font, because a run
  // alternates the paragraph separator with the empty lines Typora shows.
  let app = MarkdownEditorApp::new()
  app.set_document("123\n123\n\n123\n\n\n\n123")
  let rows = blank_line_painted_rows(
    app.runtime(width=980.0, height=640.0).draw_commands(),
    "123",
  )
  inspect(rows.length(), content="4")
  let deltas : Array[Double] = []
  for index = 1; index < rows.length(); index = index + 1 {
    deltas.push(rows[index] - rows[index - 1])
  }
  // soft wrap, one blank line, three blank lines
  assert_true(blank_line_height_matches(Some(deltas[0]), 1.55))
  assert_true(blank_line_height_matches(Some(deltas[1]), 2.35))
  assert_true(blank_line_height_matches(Some(deltas[2]), 4.7))
}

///|
test "markdown editor enter keeps a full writing line on the new blank line" {
  // Pressing Enter at the end of a paragraph leaves the caret on a
  // source-visible blank line that is still a full writing line, so the
  // caret has somewhere visible to sit and type; collapsing it to the
  // separator margin would hide the caret.
  let app = MarkdownEditorApp::new()
  app.clear()
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=6.0),
          y=84.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(
      @core.TextInputEvent::InsertText("Alpha paragraph here."),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  // Enter splits the paragraph with a blank writing line in the source.
  inspect(app.document(), content="Alpha paragraph here.\n\n")
  let caret = app.selection_caret()
  let gaps = blank_line_gap_blocks(app, caret)
  let mut writing_lines = 0
  for gap in gaps {
    if blank_line_height_matches(gap.line_height, 1.55) {
      writing_lines = writing_lines + 1
    }
  }
  // Only the line the caret sits on stays a full 1.55em writing line; the
  // blank line above it carries the run's 0.4em paragraph margin, and the
  // caret's line itself takes the writing line rather than that blank line's
  // increment. The run is therefore the margin, the writing line and the
  // spacing that follows it (0.4em + 1.55em + 0.4em).
  inspect(writing_lines, content="1")
  assert_true(
    blank_line_height_matches(Some(blank_line_gap_run_height(gaps)), 2.35),
  )
  let font = @text.FontSpec::new(size=17.0)
  match
    @moui_richtext.rich_text_document_caret_rect_at_source(
      app.document_session.rich_text_window(
        { caret, selection: None },
        base=font,
        source_mode=false,
        focus_mode=false,
        base_dir=None,
        scroll_y=0.0,
        viewport_height=640.0,
        overscan=0.0,
        content_width=720.0,
      ).document,
      caret,
      @core.Rect::new(x=0.0, y=0.0, width=720.0, height=640.0),
      font,
    ) {
    Some(rect) => inspect(rect.size.height > 0.0, content="true")
    None => fail("expected a caret rect on the blank writing line")
  }
}

///|
test "markdown editor one blank line is no caret target, three show one line" {
  // A single blank line is a bare paragraph separator: nothing renders there
  // and no pointer can park the caret on it. Three blank lines render as
  // separator + one empty line + separator, and that empty line is an ordinary
  // caret target.
  let app = MarkdownEditorApp::new()
  app.set_document("Alpha paragraph here.\n\nBeta paragraph here.")
  let runtime = app.runtime(width=980.0, height=640.0)
  guard markdown_editor_text_frame(runtime.draw_commands(), "Alpha paragraph here.")
    is Some(frame) else {
    fail("expected the first paragraph to render")
  }
  guard markdown_editor_text_frame(runtime.draw_commands(), "Beta paragraph here.")
    is Some(next_frame) else {
    fail("expected the second paragraph to render")
  }
  // "Alpha paragraph here." occupies 0..21, so the blank line is offset 22.
  let band_top = frame.origin.y + frame.size.height + 17.0 * 0.4
  let click = fn(y : Double) -> Unit {
    let point = @geometry.Point::new(x=frame.origin.x + 4.0, y~)
    runtime.dispatch_event(
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
      ),
    )
    runtime.dispatch_event(
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
      ),
    )
  }
  click(band_top + 1.0)
  inspect(app.selection_caret(), content="21")
  click(next_frame.origin.y - 1.0)
  inspect(app.selection_caret(), content="23")

  // Three blank lines between the paragraphs: the middle gap is the empty line
  // Typora shows, at offset 23.
  let three = MarkdownEditorApp::new()
  three.set_document("Alpha paragraph here.\n\n\n\nBeta paragraph here.")
  let runtime3 = three.runtime(width=980.0, height=640.0)
  guard
    markdown_editor_text_frame(runtime3.draw_commands(), "Beta paragraph here.")
    is Some(beta_frame) else {
    fail("expected the second paragraph to render")
  }
  // Above the second paragraph sit its separator (0.4em) and the empty line
  // (1.55em), so the middle of that line is 0.4em + half a line above Beta.
  let empty_line_center = beta_frame.origin.y - 17.0 * 0.4 - 17.0 * 1.55 / 2.0
  let point = @geometry.Point::new(
    x=beta_frame.origin.x + 4.0,
    y=empty_line_center,
  )
  runtime3.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
    ),
  )
  runtime3.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
    ),
  )
  inspect(three.selection_caret(), content="23")
}

///|
/// Layout top of the block that owns `caret`, in the current WYSIWYG window.
fn blank_line_caret_block_top(app : MarkdownEditorApp, caret : Int) -> Double {
  let font = @text.FontSpec::new(size=17.0)
  let window = app.document_session.rich_text_window(
    { caret, selection: None },
    base=font,
    source_mode=false,
    focus_mode=false,
    base_dir=None,
    scroll_y=0.0,
    viewport_height=640.0,
    overscan=0.0,
    content_width=720.0,
  )
  let mut top = 0.0
  for block in window.document.blocks {
    let owns_caret = match block.source_range {
      Some(range) => caret >= range.start && caret <= range.end
      None => false
    }
    if owns_caret {
      return top
    }
    top = top +
      @moui_richtext.rich_text_document_height(
        @moui_richtext.RichTextDocument::new(blocks=[block]),
        font,
      )
  }
  top
}

///|
test "markdown editor enter leaves the caret where the typed line lands" {
  // The blank writing line Enter creates has to sit exactly where the text
  // lands on the first keystroke. The blank line above it carries the run's
  // 0.4em paragraph margin, but the caret's own line takes the writing line
  // instead of that blank line's 1.2em increment: carrying both would leave
  // the caret one increment (1.2em) too low and the line would jump up as
  // soon as the first character appears.
  let app = MarkdownEditorApp::new()
  app.clear()
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=6.0),
          y=84.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("123")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  let caret_line_top = blank_line_caret_block_top(app, app.selection_caret())
  // The whole gap is the paragraph's 0.8em, i.e. the paragraph line box plus
  // Typora's collapsed paragraph margin (1.55em + 0.8em = 2.35em).
  assert_true(blank_line_height_matches(Some(caret_line_top), 2.35))
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("456")),
  )
  let typed_line_top = blank_line_caret_block_top(app, app.selection_caret())
  assert_true(blank_line_height_matches(Some(typed_line_top), 2.35))
  assert_true(blank_line_height_matches(Some(caret_line_top - typed_line_top), 0.0))
}

///|
test "markdown editor arrow keys stop on the empty line a run shows" {
  // One blank line is a bare paragraph separator, so ArrowDown steps straight
  // from one paragraph to the next. Three blank lines show one empty line and
  // the caret stops on it, the way Typora's own empty paragraph behaves.
  let app = MarkdownEditorApp::new()
  app.set_document("123\n\n456")
  let runtime = app.runtime(width=980.0, height=640.0)
  let frame = markdown_editor_text_frame(runtime.draw_commands(), "123").unwrap()
  let point = @geometry.Point::new(
    x=frame.origin.x + frame.size.width,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
    ),
  )
  inspect(app.selection_caret(), content="3")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowDown")),
  )
  // One blank line: straight to the second paragraph, no stop in between.
  inspect(app.selection_caret(), content="5")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowUp")),
  )
  inspect(app.selection_caret(), content="3")

  let three = MarkdownEditorApp::new()
  three.set_document("123\n\n\n\n456")
  let runtime3 = three.runtime(width=980.0, height=640.0)
  let frame3 = markdown_editor_text_frame(runtime3.draw_commands(), "123").unwrap()
  let point3 = @geometry.Point::new(
    x=frame3.origin.x + frame3.size.width,
    y=frame3.origin.y + frame3.size.height / 2.0,
  )
  runtime3.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point3, phase=@core.PointerPhase::Down),
    ),
  )
  runtime3.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point3, phase=@core.PointerPhase::Up),
    ),
  )
  runtime3.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowDown")),
  )
  // Three blank lines: the separator at 4 is stepped over and the empty line at
  // 5 is a caret stop; the separator at 6 is stepped over again.
  inspect(three.selection_caret(), content="5")
  runtime3.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowDown")),
  )
  inspect(three.selection_caret(), content="7")
}
