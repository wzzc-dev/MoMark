///|
test "markdown editor right-press records the context menu target per surface" {
  // Host backends dispatch the right-button press into the view tree before
  // showing the menu, so each surface records its own target and the menu the
  // host builds differs per surface.
  let app = MarkdownEditorApp::new()
  app.update_in_place(ToggleFileSidebar)
  assert_true(app.file_sidebar_visible)
  let runtime = app.runtime(width=980.0, height=640.0)
  // Lay out the tree before pressing: the hit path of the very first event on
  // a fresh runtime is not yet meaningful.
  ignore(runtime.draw_frame())

  // The document surface owns the editor menu.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
        phase=@core.PointerPhase::Down,
        button=1,
      ),
    ),
  )
  assert_true(
    app.context_menu_target == MarkdownEditorContextTarget::EditorSurface,
  )
  let editor_labels = markdown_editor_menu_labels_for_app(app)
  assert_true(editor_labels.contains("Code Block"))
  assert_true(!editor_labels.contains("Refresh File Tree"))

  // The sidebar background is the explorer's "no row" target.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=10.0, y=120.0),
        phase=@core.PointerPhase::Down,
        button=1,
      ),
    ),
  )
  assert_true(
    app.context_menu_target == MarkdownEditorContextTarget::ExplorerBackground,
  )
  let background_labels = markdown_editor_menu_labels_for_app(app)
  assert_true(background_labels.contains("Refresh File Tree"))
  assert_true(background_labels.contains("New Document"))
  assert_true(!background_labels.contains("Bold"))

  // Chrome surfaces fall back to the global menu.
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(x=980.0 - 8.0, y=6.0),
        phase=@core.PointerPhase::Down,
        button=1,
      ),
    ),
  )
  assert_true(app.context_menu_target == MarkdownEditorContextTarget::Global)
  let global_labels = markdown_editor_menu_labels_for_app(app)
  assert_true(global_labels.contains("Save"))
  assert_true(!global_labels.contains("Refresh File Tree"))
}

///|
test "markdown editor classifies explorer rows into file and folder targets" {
  // A row id carries no type of its own: directories are the ids whose subtree
  // is loaded, placeholder rows are not targetable at all.
  let app = MarkdownEditorApp::new()
  app.directory_tree_items = [
    @views.tree_item(id="/tmp/project", label="project", children=[
      @views.tree_item(id="/tmp/project/notes.md", label="notes.md"),
    ]),
    @views.tree_item(id="/tmp/empty", label="empty", children=[
      @views.tree_item(
        id=markdown_editor_tree_loading_placeholder_id("/tmp/empty"),
        label="Loading",
      ),
    ]),
  ]
  assert_true(
    app.explorer_target("/tmp/project") ==
    MarkdownEditorContextTarget::ExplorerFolder("/tmp/project"),
  )
  assert_true(
    app.explorer_target("/tmp/project/notes.md") ==
    MarkdownEditorContextTarget::ExplorerFile("/tmp/project/notes.md"),
  )
  assert_true(
    app.explorer_target(markdown_editor_tree_loading_placeholder_id("/tmp/x")) ==
    MarkdownEditorContextTarget::ExplorerBackground,
  )
}

///|
test "markdown editor orders each context menu for its surface" {
  // The catalog is declaration-ordered for shortcut dispatch, so the menu gets
  // its reading order from the target's own label list. Row actions lead the
  // explorer menus; the editor menu leads with formatting and ends with the
  // document and view actions, the way mature editors present them.
  inspect(
    markdown_editor_menu_labels_for_target(
      MarkdownEditorContextTarget::ExplorerFile("/tmp/project/notes.md"),
    ).join(","),
    content="Open,Refresh File Tree",
  )
  inspect(
    markdown_editor_menu_labels_for_target(
      MarkdownEditorContextTarget::ExplorerFolder("/tmp/project"),
    ).join(","),
    content="Open Folder,Refresh File Tree",
  )
  // The folder picker is state-dependent: it repoints the tree the sidebar
  // background belongs to.
  inspect(
    markdown_editor_menu_labels_for_target(
      MarkdownEditorContextTarget::ExplorerBackground,
    ).join(","),
    content="Pick Folder,New Document,Open Document,Refresh File Tree,Toggle Files",
  )
  inspect(
    markdown_editor_menu_labels_for_target(MarkdownEditorContextTarget::Global).join(
      ",",
    ),
    content="New Document,Open Document,Save,Save As,Import Markdown from Clipboard,Export Markdown,Export HTML,Find,Find/Replace,Toggle Files,Toggle Outline,Toggle Document Info,Toggle Source Preview,Toggle Source Mode,Toggle Quick Format,Cycle Writing Look,Toggle Focus Mode,Toggle Typewriter Mode,Toggle Zen Mode",
  )
  inspect(
    markdown_editor_menu_labels_for_target(
      MarkdownEditorContextTarget::EditorSurface,
    ).join(","),
    content="Paragraph,Heading 1,Heading 2,Heading 3,Heading 4,Heading 5,Heading 6,Bullet List,Ordered List,Task List,Quote,Code Block,Duplicate Block,Move Block Up,Move Block Down,Indent Lines,Outdent Lines,Hard Line Break,Insert Table of Contents,Insert YAML Front Matter,Find,Find/Replace,Save,Save As,Import Markdown from Clipboard,Export Markdown,Export HTML,Toggle Source Preview,Toggle Source Mode,Toggle Quick Format",
  )
}

///|
test "markdown editor scopes editor menu entries to the caret context" {
  // Actions that cannot act on the current caret are left out rather than
  // shown disabled, matching the context keys mature editors gate on.
  let mut app = MarkdownEditorApp::new().update(
    ContextMenuTargeted(MarkdownEditorContextTarget::EditorSurface),
  )
  // A paragraph caret offers no table, task, or inline entries.
  assert_true(
    !markdown_editor_menu_labels_for_app(app).contains("Insert Table Row"),
  )
  assert_true(
    !markdown_editor_menu_labels_for_app(app).contains("Table Align Center"),
  )
  assert_true(!markdown_editor_menu_labels_for_app(app).contains("Toggle Task"))
  assert_true(!markdown_editor_menu_labels_for_app(app).contains("Open Target"))
  assert_true(!markdown_editor_menu_labels_for_app(app).contains("Bold"))

  // Inline formatting appears once there is selected text to format.
  app = app.update(SetSelection(0, Some(@core.TextRange::new(start=0, end=4))))
  assert_true(markdown_editor_menu_labels_for_app(app).contains("Bold"))
  assert_true(markdown_editor_menu_labels_for_app(app).contains("Highlight"))
  assert_true(markdown_editor_menu_labels_for_app(app).contains("Link"))

  // Table commands appear only inside a table, and lead the menu there.
  app.block_label = "Table"
  assert_true(
    markdown_editor_menu_labels_for_app(app).contains("Insert Table Row"),
  )
  assert_true(
    markdown_editor_menu_labels_for_app(app).contains("Delete Table Column"),
  )
  assert_true(
    markdown_editor_menu_labels_for_app(app).contains("Table Align Auto"),
  )
  inspect(
    markdown_editor_menu_labels_for_app(app)[0],
    content="Insert Table Row",
  )

  // The task toggle addresses the checkbox of the task item under the caret.
  app.block_label = "Task list"
  assert_true(markdown_editor_menu_labels_for_app(app).contains("Toggle Task"))
  assert_true(
    !markdown_editor_menu_labels_for_app(app).contains("Insert Table Row"),
  )

  // "Open Target" resolves a link or an image under the caret.
  app.block_label = "Paragraph"
  app.target_kind = LinkTarget
  assert_true(markdown_editor_menu_labels_for_app(app).contains("Open Target"))
  app.target_kind = ImageTarget
  assert_true(markdown_editor_menu_labels_for_app(app).contains("Open Target"))
  app.target_kind = HtmlBlockTarget
  assert_true(!markdown_editor_menu_labels_for_app(app).contains("Open Target"))
}

///|
test "markdown editor lists one menu row per label" {
  // A few actions bind platform-specific shortcut variants under one label;
  // the menu must show one row each, not one row per binding.
  for
    target in [
      MarkdownEditorContextTarget::Global,
      MarkdownEditorContextTarget::EditorSurface,
      MarkdownEditorContextTarget::ExplorerFile("/tmp/project/notes.md"),
      MarkdownEditorContextTarget::ExplorerFolder("/tmp/project"),
      MarkdownEditorContextTarget::ExplorerBackground,
    ] {
    let seen : Array[String] = []
    for label in markdown_editor_menu_labels_for_target(target) {
      assert_true(!seen.contains(label))
      seen.push(label)
    }
  }
}

///|
test "markdown editor keeps the command catalog stable across context targets" {
  // Shortcut dispatch resolves by scanning this list in order and taking the
  // first command whose shortcut matches, and the native application menu
  // resolves by full equality against it. Neither may depend on which surface
  // was last right-pressed, so only the appended menu copies vary per target.
  let catalog = (target : MarkdownEditorContextTarget) => {
    markdown_editor_program_commands(
      MarkdownEditorApp::new().update(ContextMenuTargeted(target)),
    )
    .map(command => command.command())
    .filter(command => !command.context_menu)
  }
  let reference = catalog(MarkdownEditorContextTarget::Global)
  assert_true(reference.length() > 0)
  for
    target in [
      MarkdownEditorContextTarget::EditorSurface,
      MarkdownEditorContextTarget::ExplorerFile("/tmp/project/notes.md"),
      MarkdownEditorContextTarget::ExplorerFolder("/tmp/project"),
      MarkdownEditorContextTarget::ExplorerBackground,
    ] {
    let other = catalog(target)
    assert_true(other.length() == reference.length())
    for index, command in other {
      assert_true(command == reference[index])
    }
  }
}

///|
test "markdown editor application menu resolves against the command catalog" {
  // The native menu bar hands the host an ActionCommand built from the static
  // menu definition; dispatch matches it by full equality, so every item must
  // be present in the program's catalog whichever surface was last pressed.
  for
    target in [
      MarkdownEditorContextTarget::Global,
      MarkdownEditorContextTarget::EditorSurface,
      MarkdownEditorContextTarget::ExplorerBackground,
    ] {
    let catalog = markdown_editor_program_commands(
      MarkdownEditorApp::new().update(ContextMenuTargeted(target)),
    ).map(command => command.command())
    for menu in markdown_editor_application_menus() {
      for item in menu.items {
        match item {
          @services.ApplicationMenuItem::MenuCommand(command) =>
            assert_true(catalog.any(entry => entry == command))
          @services.ApplicationMenuItem::MenuSeparator => ()
        }
      }
    }
  }
}

///|
test "markdown editor offers one menu copy per label with its first shortcut" {
  // The menu copy carries the shortcut for display but is a distinct command,
  // so it can neither shadow the catalog binding nor break the menu bar, and a
  // label bound to several platform variants still yields one row.
  let app = MarkdownEditorApp::new()
    .update(ContextMenuTargeted(MarkdownEditorContextTarget::EditorSurface))
    // Inline formatting is offered only with a selection, so the copy only
    // exists once something is selected.
    .update(SetSelection(0, Some(@core.TextRange::new(start=0, end=4))))
  let commands = markdown_editor_program_commands(app).map(command => {
    command.command()
  })
  let bold = commands.filter(command => command.label == "Bold")
  // Two catalog bindings, one per platform family, plus the menu copy.
  assert_true(bold.length() == 3)
  assert_true(bold[0].shortcut != bold[1].shortcut)
  let menu = bold.filter(command => command.context_menu)
  assert_true(menu.length() == 1)
  assert_true(menu[0].shortcut == bold[0].shortcut)
}
