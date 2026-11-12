///|
test "island shell metrics keep the window inset and bar sizes" {
  let workspace = markdown_shell_metrics(WorkspaceMode)
  assert_eq(workspace.island_margin, 6.0)
  assert_eq(workspace.island_gap, 6.0)
  assert_eq(workspace.island_radius, 10.0)
  assert_eq(workspace.bar_inset, 12.0)
  assert_eq(workspace.top_bar_height, 40.0)
  assert_eq(workspace.status_bar_height, 26.0)
  let minimal = markdown_shell_metrics(MinimalMode)
  assert_eq(minimal.island_margin, 8.0)
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
test "island shell draws the top and status bars inside the window inset" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Plan")
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  let rects = markdown_shell_fill_rects(commands)
  // Workspace: 6px outer margin, 40px top bar, 26px status bar.
  assert_true(
    rects.any(rect => {
      rect.origin.x == 6.0 &&
      rect.origin.y == 6.0 &&
      rect.size.width == 968.0 &&
      rect.size.height == 40.0
    }),
  )
  assert_true(
    rects.any(rect => {
      rect.origin.x == 6.0 &&
      rect.origin.y == 608.0 &&
      rect.size.width == 968.0 &&
      rect.size.height == 26.0
    }),
  )
  // Minimal: 8px outer margin, 32px top bar, 24px status bar.
  app.set_layout_mode(MinimalMode)
  let minimal_commands = app.runtime(width=980.0, height=640.0).draw_commands()
  let minimal_rects = markdown_shell_fill_rects(minimal_commands)
  assert_true(
    minimal_rects.any(rect => {
      rect.origin.x == 8.0 &&
      rect.origin.y == 8.0 &&
      rect.size.width == 964.0 &&
      rect.size.height == 32.0
    }),
  )
  assert_true(
    minimal_rects.any(rect => {
      rect.origin.x == 8.0 &&
      rect.origin.y == 608.0 &&
      rect.size.width == 964.0 &&
      rect.size.height == 24.0
    }),
  )
}

///|
test "switching shells keeps the document and selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Plan\n\nBody")
  app.selection = { caret: 3, selection: None }
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
test "sidebar panel selection keeps one left panel visible" {
  let app = MarkdownEditorApp::new()
  app.set_sidebar_panel(FilesPanel)
  assert_true(app.file_sidebar_visible)
  assert_false(app.outline_visible)
  assert_true(app.sidebar_panel is FilesPanel)
  app.set_sidebar_panel(OutlinePanel)
  assert_false(app.file_sidebar_visible)
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
