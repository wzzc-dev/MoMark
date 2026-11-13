///|

///|
test "markdown editor working directory starts empty" {
  let app = MarkdownEditorApp::new()
  inspect(app.working_directory(), content="")
  inspect(@debug.to_string(app.expanded_tree_paths()), content="[]")
}

///|
test "markdown editor pick working directory stores chosen folder" {
  let app = MarkdownEditorApp::new()
  let services = markdown_editor_file_dialog_services(
    selected_path="/tmp/project",
    seen_kind=Ref(@host.HostFileDialogKind::OpenFile),
    seen_title=Ref(""),
    seen_default_name=Ref(""),
  )
  app.pick_working_directory_for_test(services)
  inspect(app.working_directory(), content="/tmp/project")
  inspect(
    @debug.to_string(app.expanded_tree_paths()),
    content="[\"/tmp/project\"]",
  )
  inspect(app.transfer_status_label_for_test(), content="")
}

///|
test "markdown editor pick working directory preserves recent files" {
  let app = MarkdownEditorApp::new()
  app.load_document_for_test("# Note", path="/tmp/project/Note.md")
  let services = markdown_editor_file_dialog_services(
    selected_path="/tmp/project",
    seen_kind=Ref(@host.HostFileDialogKind::OpenFile),
    seen_title=Ref(""),
    seen_default_name=Ref(""),
  )
  app.pick_working_directory_for_test(services)
  inspect(app.working_directory(), content="/tmp/project")
  inspect(app.document_path(), content="/tmp/project/Note.md")
  inspect(app.recent_document_paths().length(), content="1")
  inspect(app.recent_document_paths()[0], content="/tmp/project/Note.md")
}

///|
test "markdown editor tree path opens recent markdown file" {
  let app = MarkdownEditorApp::new()
  let services = markdown_editor_file_dialog_services(
    selected_path="",
    seen_kind=Ref(@host.HostFileDialogKind::OpenFile),
    seen_title=Ref(""),
    seen_default_name=Ref(""),
  )
  app.pick_working_directory_for_test(services)
  app.dispatch_message_for_test(
    services,
    SelectTreePath("/tmp/project/README.md"),
  )
  inspect(app.transfer_status_label_for_test(), content="Opened README.md")
}

///|
test "markdown editor file sidebar renders optional directory tree" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "No folder open", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Journal.md", .. })
    }),
  )
  app.load_document_for_test("# Note", path="/tmp/project/Note.md")
  // Inline mock that returns realistic directory entries for the tree test
  let entries = [
    @host.HostDirectoryEntry::new(
      name="README.md",
      path="/tmp/project/README.md",
    ),
    @host.HostDirectoryEntry::new(
      name="Journal.md",
      path="/tmp/project/Journal.md",
    ),
  ]
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_access=true,
      file_dialogs=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(["/tmp/project"])
        @host.HostServiceRequest::ListDirectory(_) =>
          @host.HostServiceResponse::DirectoryListing("/tmp/project", entries)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  app.pick_working_directory_for_test(
    @backend_common_services.app_services(bridge~),
  )
  let expanded = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    expanded.any(command => {
      command is @core.DrawCommand::DrawText({ text: "project", .. })
    }),
  )
  assert_true(
    expanded.any(command => {
      command is @core.DrawCommand::DrawText({ text: "README.md", .. })
    }),
  )
}

///|
test "markdown editor file sidebar pins empty folder prompt to top" {
  // The empty-state header and its primary action head the panel; Recent
  // follows below (Winc-style header, no separate "Files" caption row).
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  guard markdown_editor_text_frame(commands, "Open folder")
    is Some(actions_frame) else {
    fail("expected the empty folder prompt")
  }
  guard markdown_editor_text_frame(commands, "Recent") is Some(recent_frame) else {
    fail("expected the Recent section")
  }
  assert_true(actions_frame.origin.y < 120.0)
  assert_true(recent_frame.origin.y > actions_frame.origin.y)
}

///|
test "empty file sidebar pins the outline footer to the bottom" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  guard markdown_editor_text_frame(commands, "Outline") is Some(outline_frame) else {
    fail("expected the sidebar outline footer")
  }
  assert_true(outline_frame.origin.y > 500.0)
}

///|
test "markdown editor files and outline sidebars fit narrow window" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n\n## Section")
  app.set_file_sidebar_visible(true)
  app.set_outline_visible(true)
  let window_width = 980.0
  let commands = app.runtime(width=window_width, height=640.0).draw_commands()
  guard markdown_editor_text_frame(commands, "Outline") is Some(outline_frame) else {
    fail("expected outline sidebar title")
  }
  guard markdown_editor_text_frame(commands, "H1 Title") is Some(heading_frame) else {
    fail("expected outline heading")
  }
  assert_true(outline_frame.origin.x + outline_frame.size.width <= window_width)
  assert_true(heading_frame.origin.x + heading_frame.size.width <= window_width)
}

///|
test "markdown editor file tree lazily expands subdirectories" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  let read_path = Ref("")
  let listed_paths : Array[String] = []
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_access=true,
      file_dialogs=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(["/tmp/project"])
        @host.HostServiceRequest::ListDirectory(path) => {
          listed_paths.push(path)
          if path == "/tmp/project" {
            @host.HostServiceResponse::DirectoryListing(path, [
              @host.HostDirectoryEntry::new(
                name="notes",
                path="/tmp/project/notes",
                is_directory=true,
              ),
            ])
          } else if path == "/tmp/project/notes" {
            @host.HostServiceResponse::DirectoryListing(path, [
              @host.HostDirectoryEntry::new(
                name="daily.md",
                path="/tmp/project/notes/daily.md",
              ),
            ])
          } else {
            @host.HostServiceResponse::DirectoryListing(path, [])
          }
        }
        @host.HostServiceRequest::TextFile(
          @host.HostTextFileRequest::ReadText(path)
        ) => {
          read_path.val = path
          @host.HostServiceResponse::TextFileContent(path, "# Daily")
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @backend_common_services.app_services(bridge~)
  app.pick_working_directory_for_test(services)
  inspect(listed_paths.length(), content="1")
  inspect(listed_paths[0], content="/tmp/project")

  app.dispatch_message_for_test(services, SelectTreePath("/tmp/project/notes"))
  inspect(listed_paths.length(), content="2")
  inspect(listed_paths[1], content="/tmp/project/notes")
  inspect(read_path.val, content="")
  inspect(app.transfer_status_label_for_test(), content="")
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "daily.md", .. })
    }),
  )

  app.dispatch_message_for_test(
    services,
    SelectTreePath("/tmp/project/notes/daily.md"),
  )
  inspect(read_path.val, content="/tmp/project/notes/daily.md")
  inspect(app.transfer_status_label_for_test(), content="Opened daily.md")
}

///|
test "markdown editor file tree sorts folders before files by name" {
  let sorted = markdown_editor_sorted_directory_entries([
    @services.DirectoryEntry::{
      name: "zeta.md",
      path: "/tmp/project/zeta.md",
      is_directory: false,
    },
    @services.DirectoryEntry::{
      name: "drafts",
      path: "/tmp/project/drafts",
      is_directory: true,
    },
    @services.DirectoryEntry::{
      name: "Alpha.md",
      path: "/tmp/project/Alpha.md",
      is_directory: false,
    },
    @services.DirectoryEntry::{
      name: "Archive",
      path: "/tmp/project/Archive",
      is_directory: true,
    },
  ])
  inspect(sorted.length(), content="4")
  inspect(sorted[0].name, content="Archive")
  inspect(sorted[1].name, content="drafts")
  inspect(sorted[2].name, content="Alpha.md")
  inspect(sorted[3].name, content="zeta.md")
}

///|
test "markdown editor file tree refresh reloads picked folder" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  let version = Ref(0)
  let listed_paths : Array[String] = []
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_access=true,
      file_dialogs=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(["/tmp/project"])
        @host.HostServiceRequest::ListDirectory(path) => {
          listed_paths.push(path)
          if version.val == 0 {
            @host.HostServiceResponse::DirectoryListing(path, [
              @host.HostDirectoryEntry::new(
                name="old.md",
                path="/tmp/project/old.md",
              ),
            ])
          } else {
            @host.HostServiceResponse::DirectoryListing(path, [
              @host.HostDirectoryEntry::new(
                name="new.md",
                path="/tmp/project/new.md",
              ),
            ])
          }
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @backend_common_services.app_services(bridge~)
  app.pick_working_directory_for_test(services)
  let initial = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    initial.any(command => {
      command is @core.DrawCommand::DrawText({ text: "old.md", .. })
    }),
  )
  version.val = 1
  app.dispatch_message_for_test(services, RefreshFileTree)
  inspect(listed_paths.length(), content="2")
  inspect(listed_paths[1], content="/tmp/project")
  let refreshed = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    refreshed.any(command => {
      command is @core.DrawCommand::DrawText({ text: "new.md", .. })
    }),
  )
  assert_false(
    refreshed.any(command => {
      command is @core.DrawCommand::DrawText({ text: "old.md", .. })
    }),
  )
}

///|
test "markdown editor file sidebar filters tree and recent files" {
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  app.load_document_for_test("# Daily", path="/tmp/project/notes/daily.md")
  app.load_document_for_test("# Ideas", path="/tmp/project/ideas.md")
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_access=true,
      file_dialogs=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(["/tmp/project"])
        @host.HostServiceRequest::ListDirectory(path) =>
          if path == "/tmp/project" {
            @host.HostServiceResponse::DirectoryListing(path, [
              @host.HostDirectoryEntry::new(
                name="README.md",
                path="/tmp/project/README.md",
              ),
              @host.HostDirectoryEntry::new(
                name="notes",
                path="/tmp/project/notes",
                is_directory=true,
              ),
            ])
          } else {
            @host.HostServiceResponse::DirectoryListing(path, [
              @host.HostDirectoryEntry::new(
                name="daily.md",
                path="/tmp/project/notes/daily.md",
              ),
            ])
          }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @backend_common_services.app_services(bridge~)
  app.pick_working_directory_for_test(services)
  app.dispatch_message_for_test(services, SelectTreePath("/tmp/project/notes"))

  app.update_in_place(UpdateFileFilterQuery("daily"))
  let filtered = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    filtered.any(command => {
      command is @core.DrawCommand::DrawText({ text: "daily.md", .. })
    }),
  )
  assert_false(
    filtered.any(command => {
      command is @core.DrawCommand::DrawText({ text: "README.md", .. })
    }),
  )
  let filtered_recent = markdown_editor_filter_file_paths(
    app.recent_document_paths(),
    "daily",
  )
  inspect(filtered_recent.length(), content="1")
  inspect(filtered_recent[0], content="/tmp/project/notes/daily.md")

  app.update_in_place(UpdateFileFilterQuery("missing"))
  let missing = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    missing.any(command => {
      command is @core.DrawCommand::DrawText({ text: "No matching files", .. })
    }),
  )
  app.update_in_place(UpdateFileFilterQuery(""))
  let cleared = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    cleared.any(command => {
      command is @core.DrawCommand::DrawText({ text: "README.md", .. })
    }),
  )
  assert_true(
    cleared.any(command => {
      command is @core.DrawCommand::DrawText({ text: "ideas.md", .. })
    }),
  )
}

///|
test "markdown editor tree toggle preserves expansion order" {
  let app = MarkdownEditorApp::new()
  app.update_in_place(ToggleTreePath("b"))
  app.update_in_place(ToggleTreePath("a"))
  inspect(app.expanded_tree_paths().length(), content="2")
  inspect(app.expanded_tree_paths()[0], content="b")
  inspect(app.expanded_tree_paths()[1], content="a")
  app.update_in_place(ToggleTreePath("a"))
  inspect(app.expanded_tree_paths().length(), content="1")
  inspect(app.expanded_tree_paths()[0], content="b")
}

//|

///|
test "markdown editor file tree starts expanded" {
  let app = MarkdownEditorApp::new()
  inspect(@debug.to_string(app.file_tree_expanded), content="true")
}

//|

///|
test "markdown editor toggle file tree fold hides tree" {
  let app = MarkdownEditorApp::new()
  app.update_in_place(ToggleFileTree)
  inspect(@debug.to_string(app.file_tree_expanded), content="false")
  app.update_in_place(ToggleFileTree)
  inspect(@debug.to_string(app.file_tree_expanded), content="true")
}

///|
test "markdown editor tree dims dot-directories" {
  // Winc renders ignored/hidden entries one step quieter: the label drops to
  // the muted color while normal rows keep the foreground color.
  let app = MarkdownEditorApp::new()
  app.set_file_sidebar_visible(true)
  let entries = [
    @host.HostDirectoryEntry::new(
      name=".cache",
      path="/tmp/project/.cache",
      is_directory=true,
    ),
    @host.HostDirectoryEntry::new(
      name="readme.md",
      path="/tmp/project/readme.md",
    ),
  ]
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_access=true,
      file_dialogs=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(["/tmp/project"])
        @host.HostServiceRequest::ListDirectory(_) =>
          @host.HostServiceResponse::DirectoryListing("/tmp/project", entries)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  app.pick_working_directory_for_test(
    @backend_common_services.app_services(bridge~),
  )
  app.file_tree_expanded = true
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  let tokens = markdown_ui_tokens(@core.ColorScheme::Light)
  let mut saw_hidden = false
  let mut saw_regular = false
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text, color, .. }) =>
        if text == ".cache" {
          assert_true(color == tokens.text_muted)
          saw_hidden = true
        } else if text == "readme.md" {
          // Regular rows keep the control-theme label color; what matters is
          // that they are NOT the muted dim color.
          assert_true(color != tokens.text_muted)
          saw_regular = true
        }
      _ => ()
    }
  }
  assert_true(saw_hidden)
  assert_true(saw_regular)
}
