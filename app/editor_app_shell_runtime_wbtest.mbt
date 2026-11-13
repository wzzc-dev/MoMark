///|
test "island shell metrics keep the window inset and bar sizes" {
  let workspace = markdown_shell_metrics(WorkspaceMode)
  assert_eq(workspace.island_margin, 4.0)
  assert_eq(workspace.island_gap, 6.0)
  assert_eq(workspace.island_radius, 10.0)
  assert_eq(workspace.bar_inset, 10.0)
  assert_eq(workspace.top_bar_height, 32.0)
  assert_eq(workspace.status_bar_height, 26.0)
  let minimal = markdown_shell_metrics(MinimalMode)
  assert_eq(minimal.island_margin, 4.0)
  assert_eq(minimal.island_gap, 0.0)
  assert_eq(minimal.top_bar_height, 32.0)
  assert_eq(minimal.status_bar_height, 24.0)
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
test "island cards start at the margin and meet the flush status bar" {
  // Single chrome band: no full-width top bar; the editor card (with its tab
  // header) starts at the island margin and runs down to the status bar.
  let app = MarkdownEditorApp::new()
  app.set_document("# Plan")
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  let rects = markdown_shell_fill_rects(commands)
  let workspace = markdown_shell_metrics(WorkspaceMode)
  let card_height = 640.0 -
    workspace.status_bar_height -
    workspace.island_margin
  // With no sidebar the editor card fills the row; the document measure is
  // centered inside it.
  let card_width = 972.0
  let card_x = workspace.island_margin
  assert_true(
    rects.any(rect => {
      rect.origin.x == card_x &&
      rect.origin.y == workspace.island_margin &&
      rect.size.width == card_width &&
      rect.size.height == card_height
    }),
  )
  let status_y = 640.0 - workspace.status_bar_height
  assert_true(
    rects.any(rect => {
      rect.origin.x == 0.0 &&
      rect.origin.y == status_y &&
      rect.size.width == 980.0 &&
      rect.size.height == workspace.status_bar_height
    }),
  )
  // Minimal: 4px outer margin, same card band, 24px status bar.
  app.set_layout_mode(MinimalMode)
  let minimal_commands = app.runtime(width=980.0, height=640.0).draw_commands()
  let minimal_rects = markdown_shell_fill_rects(minimal_commands)
  let minimal = markdown_shell_metrics(MinimalMode)
  let minimal_card_height = 640.0 -
    minimal.status_bar_height -
    minimal.island_margin
  assert_true(
    minimal_rects.any(rect => {
      rect.origin.x == card_x &&
      rect.origin.y == minimal.island_margin &&
      rect.size.width == card_width &&
      rect.size.height == minimal_card_height
    }),
  )
  let minimal_status_y = 640.0 - minimal.status_bar_height
  assert_true(
    minimal_rects.any(rect => {
      rect.origin.x == 0.0 &&
      rect.origin.y == minimal_status_y &&
      rect.size.width == 980.0 &&
      rect.size.height == minimal.status_bar_height
    }),
  )
}

///|
test "switching shells keeps the document and selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Plan\n\nBody")
  app.selection = { caret: 3, selection: None, }
  app.set_layout_mode(MinimalMode)
  assert_true(app.layout_mode is MinimalMode)
  assert_eq(app.document(), "# Plan\n\nBody")
  assert_eq(app.selection.caret, 3)
  app.set_layout_mode(WorkspaceMode)
  assert_true(app.layout_mode is WorkspaceMode)
  assert_eq(app.document(), "# Plan\n\nBody")
  assert_eq(app.selection.caret, 3)
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
test "legacy settings migrate to the minimal shell" {
  let legacy = "{\"dark_mode\":true,\"font_family\":\"Serif\",\"writing_appearance\":\"Warm\",\"focus_mode\":false,\"typewriter_mode\":false,\"zen_mode\":false,\"source_preview\":false,\"outline\":true,\"files\":false,\"document_info\":false}"
  let settings = markdown_editor_decode_settings(legacy)
  assert_true(settings.dark_mode)
  assert_eq(settings.font_family, "Serif")
  assert_eq(settings.layout_mode, "Minimal")
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
    layout_mode: "Workspace",
    follow_system_scheme: true,
    sidebar_panel: "Files",
    sidebar_width: 340.0,
    editor_zoom: 1.0,
  }
  let text = ToJson::to_json(settings).stringify(indent=2)
  let decoded = markdown_editor_decode_settings(text)
  assert_eq(decoded.layout_mode, "Workspace")
  assert_true(decoded.follow_system_scheme)
  assert_eq(decoded.sidebar_width, 340.0)
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
test "find regex compilation is cached per query" {
  markdown_editor_regex_cache.val = []
  assert_true(markdown_editor_compile_regex("a+", false) is Some(_))
  inspect(markdown_editor_regex_cache.val.length(), content="1")
  assert_true(markdown_editor_compile_regex("a+", false) is Some(_))
  inspect(markdown_editor_regex_cache.val.length(), content="1")
  assert_true(markdown_editor_compile_regex("a+", true) is Some(_))
  inspect(markdown_editor_regex_cache.val.length(), content="2")
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
