///|
/// What the pointer was over when the host asked for a context menu. Host
/// backends dispatch the right-button press into the view tree before showing
/// the menu, so the deepest handler under the pointer records its target here
/// and the command list is derived from it. This mirrors how mature editors
/// scope right-click menus per surface (VS Code contributes a menu per tree or
/// editor region, Typora per document region): a file row, a folder row, the
/// sidebar background, the editor surface, and the surrounding chrome each
/// present a different menu.
pub enum MarkdownEditorContextTarget {
  Global
  ExplorerFile(String)
  ExplorerFolder(String)
  ExplorerBackground
  EditorSurface
} derive(Eq, Debug)

///|
/// Labels the current target offers, in the order the menu presents them.
///
/// The catalog is declaration-ordered for shortcut dispatch, so this list —
/// not the catalog — is what gives each surface a readable menu. Membership is
/// by label rather than by binding because a few actions carry one label and
/// several platform-specific shortcut variants; the menu offers the first
/// binding of each label only.
fn markdown_editor_context_menu_labels(
  app : MarkdownEditorApp,
) -> Array[String] {
  match app.context_menu_target {
    MarkdownEditorContextTarget::Global => markdown_editor_chrome_menu_labels()
    MarkdownEditorContextTarget::ExplorerFile(_) =>
      ["Open", "Refresh File Tree"]
    MarkdownEditorContextTarget::ExplorerFolder(_) =>
      ["Open Folder", "Refresh File Tree"]
    MarkdownEditorContextTarget::ExplorerBackground =>
      ["New Document", "Open Document", "Refresh File Tree", "Toggle Files"]
    MarkdownEditorContextTarget::EditorSurface =>
      markdown_editor_editor_surface_labels(app)
  }
}

///|
/// The document and view actions for a right-press no inner surface claimed
/// (toolbar, status strip, dialogs). Writing modes and panel toggles belong to
/// the chrome, so they stay reachable here even in Zen mode, where the chrome
/// that normally carries them is hidden.
fn markdown_editor_chrome_menu_labels() -> Array[String] {
  [
    "New Document", "Open Document", "Save", "Save As", "Import Markdown from Clipboard",
    "Export Markdown", "Export HTML", "Find", "Find/Replace", "Toggle Files", "Toggle Outline",
    "Toggle Document Info", "Toggle Source Preview", "Toggle Source Mode", "Toggle Quick Format",
    "Cycle Writing Look", "Toggle Focus Mode", "Toggle Typewriter Mode", "Toggle Zen Mode",
  ]
}

///|
/// The document surface's menu: the flat projection of what mature editors
/// nest one level down (Typora's Insert/Paragraph/Format submenus and its
/// table and image submenus), because the host context menu is a flat command
/// list.
///
/// Entries are scoped to what the press can act on. Table commands appear only
/// inside a table and the task toggle only inside a task item, the way Typora
/// and Obsidian swap in their table submenu and checkbox action; inline
/// formatting appears only with a selection. Actions that cannot do anything
/// at the current caret are left out rather than shown disabled, matching the
/// `editorHasSelection`-style context keys VS Code gates menu entries on.
fn markdown_editor_editor_surface_labels(
  app : MarkdownEditorApp,
) -> Array[String] {
  let mut labels : Array[String] = []
  if app.is_inside_table() {
    labels = labels +
      [
        "Insert Table Row", "Insert Table Column", "Delete Table Row", "Delete Table Column",
        "Table Align Left", "Table Align Center", "Table Align Right", "Table Align Auto",
      ]
  }
  if app.has_openable_target() {
    labels.push("Open Target")
  }
  if app.has_active_selection() {
    labels = labels +
      [
        "Bold", "Italic", "Strikethrough", "Inline Code", "Highlight", "Link", "Image",
      ]
  }
  // Block commands act at the caret, so they stay visible without a selection.
  labels = labels +
    [
      "Paragraph", "Heading 1", "Heading 2", "Heading 3", "Heading 4", "Heading 5",
      "Heading 6", "Bullet List", "Ordered List", "Task List", "Quote", "Code Block",
      "Duplicate Block", "Move Block Up", "Move Block Down",
    ]
  if app.is_inside_task_item() {
    labels.push("Toggle Task")
  }
  labels +
  [
    "Indent Lines", "Outdent Lines", "Hard Line Break", "Insert Table of Contents",
    "Insert YAML Front Matter", "Find", "Find/Replace", "Save", "Save As", "Import Markdown from Clipboard",
    "Export Markdown", "Export HTML", "Toggle Source Preview", "Toggle Source Mode",
    "Toggle Quick Format",
  ]
}

///|
/// The first binding declared for a command label. The context menu is built
/// from these, so an action that binds several platform-specific shortcut
/// variants still contributes one row, and a sidebar-only action with no
/// shortcut at all can still be offered.
priv struct MarkdownEditorMenuBinding {
  label : String
  shortcut : @views.KeyboardShortcut?
  message : MarkdownEditorMsg
}

///|
/// The context menu for the active target: the commands that only exist for
/// that target first, then the catalog entries the target names, in the order
/// it names them.
///
/// These are copies rather than the catalog entries themselves. Dispatch
/// matches an `ActionCommand` by full equality, so flagging a catalog entry
/// would both stop the native application menu from resolving it and let it
/// shadow the shortcut binding it was derived from — a menu copy appended
/// after the catalog can do neither.
fn markdown_editor_context_menu_commands(
  app : MarkdownEditorApp,
  bindings : Array[MarkdownEditorMenuBinding],
) -> Array[@moui.ProgramCommand[MarkdownEditorMsg]] {
  let menu = markdown_editor_target_commands(app)
  for label in markdown_editor_context_menu_labels(app) {
    for binding in bindings {
      if binding.label == label {
        menu.push(
          @moui.ProgramCommand::new(
            command=@views.ActionCommand::new(
              intent=@views.CommandIntent::Activate,
              label=binding.label,
              shortcut=binding.shortcut,
              context_menu=true,
            ),
            message=binding.message,
          ),
        )
      }
    }
  }
  menu
}

///|
/// Commands that only exist for the active target and therefore cannot be
/// derived from the catalog: they carry per-target payloads (the pressed path)
/// or state-dependent captions. They are prepended so they lead the menu, the
/// way an explorer's row actions do in mature editors.
fn markdown_editor_target_commands(
  app : MarkdownEditorApp,
) -> Array[@moui.ProgramCommand[MarkdownEditorMsg]] {
  match app.context_menu_target {
    MarkdownEditorContextTarget::ExplorerFile(path) if path != "" =>
      [markdown_editor_context_menu_command("Open", OpenContextMenuTargetPath)]
    MarkdownEditorContextTarget::ExplorerFolder(path) if path != "" =>
      [
        markdown_editor_context_menu_command(
          "Open Folder",
          OpenContextMenuTargetFolder,
        ),
      ]
    MarkdownEditorContextTarget::ExplorerBackground =>
      [
        markdown_editor_context_menu_command(
          if app.working_directory == "" {
            "Pick Folder"
          } else {
            "Change Folder"
          },
          PickWorkingDirectory,
        ),
      ]
    _ => []
  }
}

///|
/// A menu-only command: no keyboard shortcut, so it never joins shortcut
/// dispatch, and it is unconditionally part of the context menu because the
/// command only exists while its target is active.
fn markdown_editor_context_menu_command(
  label : String,
  message : MarkdownEditorMsg,
) -> @moui.ProgramCommand[MarkdownEditorMsg] {
  @moui.ProgramCommand::new(
    command=@views.ActionCommand::new(
      intent=@views.CommandIntent::Activate,
      label~,
      shortcut=None,
      context_menu=true,
    ),
    message~,
  )
}

///|
/// The path recorded for the explorer row that opened the menu, or "" when the
/// current target carries none.
fn markdown_editor_context_target_path(app : MarkdownEditorApp) -> String {
  match app.context_menu_target {
    MarkdownEditorContextTarget::ExplorerFile(path) => path
    MarkdownEditorContextTarget::ExplorerFolder(path) => path
    _ => ""
  }
}

///|
/// Classify a tree row id: placeholder rows (loading/empty markers) are not
/// targetable and fall back to the sidebar background, directories are the
/// entries whose subtree exists, everything else is a file.
fn MarkdownEditorApp::explorer_target(
  self : MarkdownEditorApp,
  path : String,
) -> MarkdownEditorContextTarget {
  if markdown_editor_tree_path_is_placeholder(path) {
    MarkdownEditorContextTarget::ExplorerBackground
  } else if self.tree_path_is_directory(path) {
    MarkdownEditorContextTarget::ExplorerFolder(path)
  } else {
    MarkdownEditorContextTarget::ExplorerFile(path)
  }
}

///|
/// Whether the document has a non-collapsed selection, i.e. commands that
/// operate on selected text are applicable.
fn MarkdownEditorApp::has_active_selection(self : MarkdownEditorApp) -> Bool {
  match self.selection.selection {
    Some(range) => !range.is_collapsed()
    None => false
  }
}

///|
/// Whether the caret sits in a table, i.e. the table commands have a cell to
/// act on.
fn MarkdownEditorApp::is_inside_table(self : MarkdownEditorApp) -> Bool {
  self.block_label == "Table"
}

///|
/// Whether the caret sits in a task item, i.e. there is a checkbox to toggle.
fn MarkdownEditorApp::is_inside_task_item(self : MarkdownEditorApp) -> Bool {
  self.block_label == "Task list"
}

///|
/// Whether "Open Target" has something to resolve: a link or an image under
/// the caret. Raw HTML blocks own their whole subtree and are edited through
/// the HTML target field instead, so they do not offer it.
fn MarkdownEditorApp::has_openable_target(self : MarkdownEditorApp) -> Bool {
  match self.target_kind {
    LinkTarget | ImageTarget => true
    _ => false
  }
}
