///|
test "island shell metrics keep the window inset and bar sizes" {
  let shell = markdown_shell_metrics()
  assert_eq(shell.island_margin, 4.0)
  assert_eq(shell.island_gap, 6.0)
  assert_eq(shell.island_radius, 10.0)
  assert_eq(shell.bar_inset, 10.0)
  assert_eq(shell.top_bar_height, 32.0)
  assert_eq(shell.status_bar_height, 26.0)
  assert_eq(markdown_shell_chrome_control_height(), 24.0)
}

///|
fn markdown_shell_fill_rects(
  commands : Array[@core.DrawCommand],
) -> Array[@geometry.Rect] {
  let rects : Array[@geometry.Rect] = []
  for command in commands {
    match command {
      @core.DrawCommand::FillRoundedRectBrush(rounded, _) =>
        rects.push(rounded.rect)
      _ => ()
    }
  }
  rects
}

///|
fn markdown_shell_rect_at(
  rects : Array[@geometry.Rect],
  x~ : Double,
  width~ : Double,
) -> @geometry.Rect? {
  for rect in rects {
    if rect.origin.x == x &&
      rect.size.width == width &&
      rect.origin.y < 40.0 &&
      rect.size.height > 20.0 &&
      rect.size.height < 30.0 {
      return Some(rect)
    }
  }
  None
}

///|
fn markdown_shell_double_close(a : Double, b : Double) -> Bool {
  let diff = a - b
  diff < 0.5 && diff > -0.5
}

///|
test "collapsed chrome keeps the toggle, tab and actions on one row" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Plan")
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  let rects = markdown_shell_fill_rects(commands)
  // Leading toggle after the traffic-light inset, then the tab pill.
  let toggle = markdown_shell_rect_at(rects, x=82.0, width=24.0)
  let tab = markdown_shell_rect_at(rects, x=122.0, width=168.0)
  match (toggle, tab) {
    (Some(toggle), Some(tab)) => {
      assert_eq(toggle.origin.y, tab.origin.y)
      assert_eq(toggle.size.height, 24.25)
      assert_eq(tab.size.height, 24.25)
      // The 32px band is centered at 20pt, then shifted 4pt up so the row's
      // center (16pt) sits on the native traffic-light center line.
      assert_eq(toggle.origin.y + toggle.size.height / 2.0, 16.0)
    }
    _ => fail("collapsed chrome is missing the toggle or the tab pill")
  }
  // The three view actions are 24px wide with a 2px gap and end 8px inside
  // the editor card instead of running off its right edge.
  assert_true(markdown_shell_rect_at(rects, x=892.0, width=24.0) is Some(_))
  assert_true(markdown_shell_rect_at(rects, x=918.0, width=24.0) is Some(_))
  assert_true(markdown_shell_rect_at(rects, x=944.0, width=24.0) is Some(_))
  assert_eq(944.0 + 24.0, 976.0 - 8.0)
}

///|
test "expanded header and tab strip share the same chrome row" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Plan")
  app.apply_settings(MarkdownEditorSettings::default())
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  let rects = markdown_shell_fill_rects(commands)
  let toggle = markdown_shell_rect_at(rects, x=82.0, width=24.0)
  let track = markdown_shell_rect_at(rects, x=112.0, width=54.0)
  let tab = markdown_shell_rect_at(rects, x=318.0, width=168.0)
  match (toggle, track, tab) {
    (Some(toggle), Some(track), Some(tab)) => {
      // The header row and the tab row agree within half a point, and neither
      // pokes above the card's top edge (the old header offset did).
      assert_true(markdown_shell_double_close(toggle.origin.y, tab.origin.y))
      assert_true(
        markdown_shell_double_close(toggle.size.height, tab.size.height),
      )
      assert_true(markdown_shell_double_close(toggle.origin.y, track.origin.y))
      // Both halves sit on the traffic-light center line (the band center is
      // 20pt; the row is shifted up 4pt).
      assert_eq(toggle.origin.y + toggle.size.height / 2.0, 16.0)
    }
    _ => fail("expanded chrome is missing the toggle, switch or tab")
  }
}

///|
test "tab actions stay inside the window at the minimum width" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Plan")
  let commands = app.runtime(width=816.0, height=600.0).draw_commands()
  let rects = markdown_shell_fill_rects(commands)
  // 816 - island margin (4) - right inset (8) = 804; the three 24px actions
  // and two 2px gaps put the first one at 728. The old 70px assumption let the
  // last action run past the card edge.
  assert_true(markdown_shell_rect_at(rects, x=728.0, width=24.0) is Some(_))
  assert_true(markdown_shell_rect_at(rects, x=754.0, width=24.0) is Some(_))
  assert_true(markdown_shell_rect_at(rects, x=780.0, width=24.0) is Some(_))
  assert_eq(780.0 + 24.0, 816.0 - 4.0 - 8.0)
}

///|
test "collapsing the sidebar keeps the toggle at the same height" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Plan")
  app.apply_settings(MarkdownEditorSettings::default())
  let expanded = markdown_shell_fill_rects(
    app.runtime(width=980.0, height=640.0).draw_commands(),
  )
  let expanded_toggle = markdown_shell_rect_at(expanded, x=82.0, width=24.0)
  app.update_in_place(ToggleFileSidebar)
  let collapsed = markdown_shell_fill_rects(
    app.runtime(width=980.0, height=640.0).draw_commands(),
  )
  let collapsed_toggle = markdown_shell_rect_at(collapsed, x=82.0, width=24.0)
  match (expanded_toggle, collapsed_toggle) {
    (Some(expanded), Some(collapsed)) => {
      assert_eq(expanded.origin.y, collapsed.origin.y)
      assert_eq(expanded.size.height, collapsed.size.height)
    }
    _ => fail("the sidebar toggle moved between states or disappeared")
  }
}

///|
test "island cards start at the margin and meet the flush status bar" {
  // Single chrome band: no full-width top bar; the editor card (with its tab
  // header) starts at the island margin and runs down to the status bar.
  let app = MarkdownEditorApp::new()
  app.set_document("# Plan")
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  let rects = markdown_shell_fill_rects(commands)
  let shell = markdown_shell_metrics()
  let card_height = 640.0 - shell.status_bar_height - shell.island_margin
  // With no sidebar the editor card fills the row; the document measure is
  // centered inside it.
  let card_width = 972.0
  let card_x = shell.island_margin
  assert_true(
    rects.any(rect => {
      rect.origin.x == card_x &&
      rect.origin.y == shell.island_margin &&
      rect.size.width == card_width &&
      rect.size.height == card_height
    }),
  )
  let status_y = 640.0 - shell.status_bar_height
  assert_true(
    rects.any(rect => {
      rect.origin.x == 0.0 &&
      rect.origin.y == status_y &&
      rect.size.width == 980.0 &&
      rect.size.height == shell.status_bar_height
    }),
  )
}

///|
test "restored panel settings start fully open" {
  let app = MarkdownEditorApp::new()
  app.panel_anim_enabled = true
  app.apply_settings(MarkdownEditorSettings::default())
  assert_true(app.file_sidebar_visible)
  inspect(app.panel_anim_fraction(), content="1")
}

///|
test "line column label tracks source newlines and clamps the caret" {
  inspect(
    markdown_editor_line_column_label("alpha\nbeta", 0),
    content="Ln 1, Col 1",
  )
  inspect(
    markdown_editor_line_column_label("alpha\nbeta", 3),
    content="Ln 1, Col 4",
  )
  inspect(
    markdown_editor_line_column_label("alpha\nbeta", 6),
    content="Ln 2, Col 1",
  )
  inspect(
    markdown_editor_line_column_label("alpha\nbeta", 99),
    content="Ln 2, Col 5",
  )
}

///|
test "sidebar panel selection keeps one left panel visible" {
  let app = MarkdownEditorApp::new()
  app.set_sidebar_panel(FilesPanel)
  assert_true(app.file_sidebar_visible)
  assert_false(app.outline_visible)
  assert_true(app.sidebar_panel is FilesPanel)
  // The outline is a section under the file tree: both stay visible.
  app.set_sidebar_panel(OutlinePanel)
  assert_true(app.file_sidebar_visible)
  assert_true(app.outline_visible)
  assert_true(app.sidebar_panel is OutlinePanel)
}

///|
test "legacy settings migrate to the single shell" {
  let legacy = "{\"dark_mode\":true,\"font_family\":\"Serif\",\"writing_appearance\":\"Warm\",\"focus_mode\":false,\"typewriter_mode\":false,\"zen_mode\":false,\"source_preview\":false,\"outline\":true,\"files\":false,\"document_info\":false}"
  let settings = markdown_editor_decode_settings(legacy)
  assert_true(settings.dark_mode)
  assert_eq(settings.font_family, "Serif")
  assert_eq(settings.sidebar_panel, "Outline")
  assert_true(settings.outline)
  assert_false(settings.files)
}

///|
test "settings round-trip carries the shell state" {
  let settings : MarkdownEditorSettings = {
    dark_mode: false,
    font_family: "Mono",
    writing_appearance: "Wide",
    focus_mode: false,
    typewriter_mode: false,
    zen_mode: false,
    source_preview: false,
    outline: false,
    files: true,
    document_info: false,
    follow_system_scheme: true,
    sidebar_panel: "Files",
    sidebar_width: 340.0,
    editor_zoom: 1.0,
  }
  let text = ToJson::to_json(settings).stringify(indent=2)
  let decoded = markdown_editor_decode_settings(text)
  assert_true(decoded.follow_system_scheme)
  assert_eq(decoded.sidebar_width, 340.0)
}

///|
test "settings saved with the retired layout field still decode" {
  // Preferences written while the two-shell switch existed carry a
  // `layout_mode` key. Dropping the field from the schema must not reset the
  // rest of the file.
  let legacy = "{\"dark_mode\":true,\"font_family\":\"Serif\",\"writing_appearance\":\"Warm\",\"focus_mode\":true,\"typewriter_mode\":false,\"zen_mode\":false,\"source_preview\":false,\"outline\":true,\"files\":true,\"document_info\":false,\"layout_mode\":\"Minimal\",\"follow_system_scheme\":false,\"sidebar_panel\":\"Outline\",\"sidebar_width\":310.0,\"editor_zoom\":1.0}"
  let settings = markdown_editor_decode_settings(legacy)
  assert_true(settings.dark_mode)
  assert_eq(settings.font_family, "Serif")
  assert_true(settings.outline)
  assert_eq(settings.sidebar_panel, "Outline")
  assert_eq(settings.sidebar_width, 310.0)
}

///|
test "settings sheet opens from the shell and closes again" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Plan")
  app.update_in_place(OpenSettings)
  assert_true(app.settings_visible)
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      match command {
        @core.DrawCommand::DrawText({ text, .. }) => text == "Settings"
        _ => false
      }
    }),
  )
  app.update_in_place(CloseSettings)
  assert_false(app.settings_visible)
}

///|
test "caret blinks on the timer and resets on selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text")
  assert_true(app.caret_blink_visible)
  app.update_in_place(CaretBlinkTick)
  assert_false(app.caret_blink_visible)
  app.set_selection(1, None)
  assert_true(app.caret_blink_visible)
}

///|
test "zoom commands scale the editor font and reset" {
  let app = MarkdownEditorApp::new()
  let base = app.appearance_spec().editor_font_size
  app.update_in_place(ZoomIn)
  assert_true(app.appearance_spec().editor_font_size > base)
  app.update_in_place(ZoomOut)
  assert_true(app.appearance_spec().editor_font_size == base)
  app.update_in_place(ZoomIn)
  app.update_in_place(ResetZoom)
  assert_true(app.appearance_spec().editor_font_size == base)
}


///|
test "sidebar panel animates open and closed over twelve ticks" {
  let app = MarkdownEditorApp::new()
  app.panel_anim_enabled = true
  app.set_sidebar_panel(FilesPanel)
  inspect(app.panel_anim_progress, content="0")
  for _ in 0..<6 {
    app.update_in_place(PanelAnimTick)
  }
  let mid = app.panel_anim_progress
  assert_true(mid > 0.0 && mid < 1.0)
  let mid_x = app.editor_content_x(1120.0)
  for _ in 0..<6 {
    app.update_in_place(PanelAnimTick)
  }
  inspect(app.panel_anim_progress, content="1")
  let full_x = app.editor_content_x(1120.0)
  assert_true(mid_x < full_x)
  app.update_in_place(ToggleFileSidebar)
  assert_false(app.file_sidebar_visible)
  inspect(app.panel_anim_progress, content="1")
  for _ in 0..<12 {
    app.update_in_place(PanelAnimTick)
  }
  inspect(app.panel_anim_progress, content="0")
}

///|
test "collapsed sidebar keeps a toggle in the tab strip" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(false)
  assert_false(app.sidebar_visible())
  let runtime = app.runtime(width=980.0, height=640.0)
  let commands = runtime.draw_commands()
  guard markdown_editor_text_frame(commands, "Untitled") is Some(tab_frame) else {
    fail("expected the document tab to render")
  }
  // The leading toggle (traffic-light inset + 26px button) pushes the tab
  // right of where it sits when no chrome precedes it.
  assert_true(tab_frame.origin.x > 80.0)
  // Clicking that toggle brings the sidebar back.
  let point = @geometry.Point::new(x=93.0, y=20.0)
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
  assert_true(app.sidebar_visible())
}

///|
test "dragging the gap between sidebar and editor resizes the sidebar" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  let runtime = app.runtime(width=980.0, height=640.0)
  ignore(runtime.draw_frame())
  let start = @geometry.Point::new(x=307.0, y=300.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=start, phase=@core.PointerPhase::Down),
    ),
  )
  let moved = @geometry.Point::new(x=347.0, y=300.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=moved, phase=@core.PointerPhase::Move),
    ),
  )
  assert_true(app.sidebar_width > 320.0)
}

///|
test "editor surface fills the card below the tab strip and above its edge" {
  // The card spans y=4..614: the 32px tab strip ends at y=36 and the flush
  // status bar starts at y=614. Both points land in the bands that used to be
  // fixed, non-interactive page padding.
  for y in [44.0, 606.0] {
    let app = MarkdownEditorApp::new()
    app.set_document("")
    let runtime = app.runtime(width=980.0, height=640.0)
    ignore(runtime.draw_frame())
    let point = @geometry.Point::new(
      x=app.editor_content_x(980.0, inner_x=8.0),
      y~,
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
    runtime.dispatch_event(
      @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("edge")),
    )
    assert_true(
      app.document() == "edge",
      msg="editor card band at y=\{y} should accept focus and text",
    )
  }
}

///|
test "chrome buttons suppress the pointer focus ring" {
  let theme = markdown_ui_theme(markdown_ui_tokens(@core.ColorScheme::Light))
  let chrome = markdown_shell_compact_theme(theme, focus_ring=false)
  assert_eq(chrome.palette.focus.a, 0.0)
  // Dialog controls keep the normal accent ring.
  let dialog = markdown_shell_compact_theme(theme)
  assert_eq(dialog.palette.focus, theme.palette.focus)
}
