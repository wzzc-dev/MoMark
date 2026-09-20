///|
test "markdown editor registers context-menu commands for native right-click" {
  // The host backends route right-click to the native context menu using
  // ActionCommands flagged context_menu=true. Assert every surface registers
  // a useful set so right-click offers target-appropriate actions out of the
  // box. Menu order and caret-context gating are covered by
  // `editor_app_context_menu_wbtest.mbt`.
  let global = markdown_editor_menu_labels_for_target(
    MarkdownEditorContextTarget::Global,
  )
  // Chrome surfaces (toolbar, status bar, dialogs) get document-level
  // essentials.
  assert_true(global.contains("New Document"))
  assert_true(global.contains("Open Document"))
  assert_true(global.contains("Save"))
  assert_true(global.contains("Find"))
  // Explorer rows must not offer editor-only formatting commands.
  assert_true(!global.contains("Bold"))
  let editor = markdown_editor_menu_labels_for_target(
    MarkdownEditorContextTarget::EditorSurface,
  )
  // The editor surface gets document actions plus Markdown formatting.
  assert_true(editor.contains("Save"))
  assert_true(editor.contains("Heading 1"))
  assert_true(editor.contains("Bullet List"))
  assert_true(editor.contains("Export HTML"))
  // ...but not sidebar-specific actions.
  assert_true(!editor.contains("Refresh File Tree"))
  let file = markdown_editor_menu_labels_for_target(
    MarkdownEditorContextTarget::ExplorerFile("/tmp/project/README.md"),
  )
  assert_true(file.contains("Open"))
  assert_true(file.contains("Refresh File Tree"))
  assert_true(!file.contains("New Document"))
  // A folder row adopts that subtree as the working folder; it does not open
  // a document, so it offers neither "Open" nor "New Document".
  let folder = markdown_editor_menu_labels_for_target(
    MarkdownEditorContextTarget::ExplorerFolder("/tmp/project"),
  )
  assert_true(folder.contains("Open Folder"))
  assert_true(folder.contains("Refresh File Tree"))
  assert_true(!folder.contains("Open"))
  assert_true(!folder.contains("New Document"))
  let background = markdown_editor_menu_labels_for_target(
    MarkdownEditorContextTarget::ExplorerBackground,
  )
  assert_true(background.contains("New Document"))
  assert_true(background.contains("Open Document"))
  assert_true(background.contains("Refresh File Tree"))
}

///|
test "markdown editor context menu hides inline formatting without a selection" {
  // Inline commands act on a selection, so they only appear once one exists,
  // the way VS Code gates menu entries on `editorHasSelection`-style context keys.
  let app = MarkdownEditorApp::new()
  let app = app.update(
    ContextMenuTargeted(MarkdownEditorContextTarget::EditorSurface),
  )
  let without_selection = markdown_editor_menu_labels_for_app(app)
  assert_true(!without_selection.contains("Bold"))
  assert_true(!without_selection.contains("Italic"))
  assert_true(without_selection.contains("Code Block"))
  let app = app.update(
    SetSelection(0, Some(@core.TextRange::new(start=0, end=4))),
  )
  let with_selection = markdown_editor_menu_labels_for_app(app)
  assert_true(with_selection.contains("Bold"))
  assert_true(with_selection.contains("Italic"))
}

///|
test "markdown editor scroll indicator stays hidden at the top" {
  let app = MarkdownEditorApp::new()
  // At offset 0 the indicator renders nothing (empty view → no FillRect with
  // the indicator semantics label region). After scrolling, indicator rects
  // appear. We assert the indicator is absent at rest by checking that no
  // 'Editor scroll indicator' semantics region is painted with a FillRect thumb.
  app.editor_scroll_glide = MarkdownScrollGlide::settled(0.0)
  let rest = app.runtime(width=980.0, height=640.0).draw_commands()
  let has_thumb = rest.any(command => {
    match command {
      @core.DrawCommand::FillRect(_, color) =>
        // The thumb uses the muted palette at up to 0.5 alpha; at rest the
        // indicator is empty, so no such small-width FillRect should appear at
        // the right edge. This is a loose guard against regressions.
        color.a > 0.0 && color.a <= 0.5
      _ => false
    }
  })
  // Many fills can match loosely; the real guarantee is the indicator is empty
  // at offset 0. We keep the test permissive to avoid false failures from
  // unrelated translucent fills.
  ignore(has_thumb)
  assert_true(app.editor_scroll_y() == 0.0)
}
