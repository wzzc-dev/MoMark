///|
fn markdown_editor_reading_label(snapshot : MarkdownEditorSnapshot) -> String {
  let minutes = if snapshot.reading_minutes == 0 {
    "less than 1 min"
  } else if snapshot.reading_minutes == 1 {
    "1 min"
  } else {
    snapshot.reading_minutes.to_string() + " min"
  }
  "\{snapshot.word_count} words / \{snapshot.line_count} lines / " + minutes
}

///|
fn markdown_editor_session_reading_label(
  session : MarkdownDocumentSession,
) -> String {
  let minutes = if session.reading_minutes == 0 {
    "less than 1 min"
  } else if session.reading_minutes == 1 {
    "1 min"
  } else {
    session.reading_minutes.to_string() + " min"
  }
  "\{session.word_count} words / \{session.line_count} lines / " + minutes
}

///|
/// 计算当前展开状态下树中可见条目的数量。镜像 `moui/views/data_tree.mbt`
/// 中 `append_tree_rows` 的可见性逻辑：顶层条目总是计数；仅当节点 id
/// 出现在 `expanded` 中时才递归计数其子项。
fn markdown_editor_count_visible_tree_items(
  items : Array[@views.TreeItem],
  expanded : Array[String],
) -> Int32 {
  let mut count = 0
  for item in items {
    count = count + 1
    if expanded.any(id => id == item.id) {
      count = count +
        markdown_editor_count_visible_tree_items(item.children, expanded)
    }
  }
  count
}

///|
fn markdown_editor_filter_file_paths(
  paths : Array[String],
  query : String,
) -> Array[String] {
  let needle = query.trim().to_owned().to_lower()
  if needle == "" {
    return paths
  }
  paths.filter(path => markdown_editor_file_sidebar_filter_matches(path, needle))
}

///|
fn markdown_editor_filter_tree_items(
  items : Array[@views.TreeItem],
  query : String,
) -> Array[@views.TreeItem] {
  let needle = query.trim().to_owned().to_lower()
  if needle == "" {
    return items
  }
  markdown_editor_filter_tree_items_with_needle(items, needle)
}

///|
fn markdown_editor_filter_tree_items_with_needle(
  items : Array[@views.TreeItem],
  needle : String,
) -> Array[@views.TreeItem] {
  let filtered : Array[@views.TreeItem] = []
  for item in items {
    let self_matches = markdown_editor_file_sidebar_filter_matches(
      item.label + " " + item.id,
      needle,
    )
    let filtered_children = markdown_editor_filter_tree_items_with_needle(
      item.children,
      needle,
    )
    if self_matches {
      filtered.push(item)
    } else if filtered_children.length() > 0 {
      filtered.push(
        @views.tree_item(
          id=item.id,
          label=item.label,
          children=filtered_children,
          icon=item.icon,
          icon_color=item.icon_color,
        ),
      )
    }
  }
  filtered
}

///|
fn markdown_editor_file_sidebar_filter_matches(
  value : String,
  needle : String,
) -> Bool {
  value.to_lower().contains(needle)
}

///|
fn markdown_editor_tree_item_ids(
  items : Array[@views.TreeItem],
) -> Array[String] {
  let ids : Array[String] = []
  markdown_editor_append_tree_item_ids(ids, items)
  ids
}

///|
fn markdown_editor_append_tree_item_ids(
  ids : Array[String],
  items : Array[@views.TreeItem],
) -> Unit {
  for item in items {
    ids.push(item.id)
    markdown_editor_append_tree_item_ids(ids, item.children)
  }
}

///|
/// Hairline divider separating the recent list from the pinned footer.
fn markdown_editor_file_sidebar_divider(
  theme : @moui.Theme,
  width~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  frame(empty(), width~, height=1.0).background(
    theme.palette.muted.multiply_alpha(0.24),
  )
}

///|
fn markdown_sidebar_theme(theme : @moui.Theme) -> @moui.Theme {
  let control = @core.FontSpec::new(size=13.0, weight=500)
  @views.theme(
    base=theme,
    spacing_scale={ ..theme.spacing_scale, sm: 2.0, lg: 4.0, },
    typography={ ..theme.typography, control, label: control, },
  )
}

///|
/// Winc-style file sidebar: a project header with its actions, a flat tree,
/// and the outline docked as a collapsible section at the bottom. The chrome
/// header band (toggle + segmented) is supplied by the shell.
fn files_inspector(
  app : MarkdownEditorApp,
  session : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  theme : @moui.Theme,
  height~ : Double,
  width~ : Double = markdown_editor_file_sidebar_width(),
  header~ : @moui.View[MarkdownEditorMsg] = @views.empty(),
  header_height~ : Double = 0.0,
  outline_expanded~ : Bool = false,
) -> @moui.View[MarkdownEditorMsg] {
  let panel_theme = markdown_sidebar_theme(theme)
  let panel_height = markdown_editor_max_double(0.0, height - header_height)
  let content_width = markdown_editor_max_double(0.0, width - 24.0)
  let row_gap = 4.0
  let working_directory = app.working_directory
  let has_folder = working_directory != ""
  let tree_expanded = has_folder && app.file_tree_expanded
  let tree_items = markdown_editor_filter_tree_items(
    app.directory_tree_items,
    app.file_filter_query,
  )
  let tree_display_items = if has_folder &&
    tree_items.length() == 1 &&
    tree_items[0].id == working_directory {
    tree_items[0].children
  } else {
    tree_items
  }
  let tree_expanded_paths = if app.file_filter_query.trim().to_owned() == "" {
    app.expanded_tree_paths
  } else {
    markdown_editor_tree_item_ids(tree_items)
  }
  let recent_paths = markdown_editor_filter_file_paths(
    app.recent_document_paths,
    app.file_filter_query,
  )
  // Inner height after the card padding. The list and the outline section
  // share the slack explicitly; every other row is fixed height.
  let inner = markdown_editor_max_double(0.0, panel_height - 20.0)
  // Project header/empty header + open button + Recent label, plus the
  // divider and the classic outline header row that always sit at the bottom.
  let fixed_base = if has_folder {
    26.0 + 1.0 + 24.0
  } else {
    24.0 + 28.0 + 22.0 + 1.0 + 24.0
  }
  let base_gaps = if has_folder { 3.0 } else { 5.0 }
  let gaps = base_gaps + (if outline_expanded { 1.0 } else { 0.0 })
  let outline_height = if outline_expanded {
    let allowance = inner - fixed_base - gaps * row_gap - 80.0
    markdown_editor_clamp_double(
      inner * 0.42,
      80.0,
      markdown_editor_max_double(80.0, allowance),
    )
  } else {
    0.0
  }
  let list_height = markdown_editor_max_double(
    0.0,
    inner - fixed_base - outline_height - gaps * row_gap,
  )
  let compact = markdown_shell_compact_theme(theme, focus_ring=false)
  let action_size = markdown_shell_chrome_control_height()
  let action_button = fn(
    icon : @views.IconName,
    label : String,
    message : MarkdownEditorMsg,
  ) -> @moui.View[MarkdownEditorMsg] {
    tooltip(
      button(
        "",
        on_click=message,
        variant=@views.ButtonVariant::Ghost,
        icon=Some(icon),
        theme=compact,
        width=action_size,
        height=action_size,
      ),
      label,
    )
  }
  let folder_actions = [
    action_button(
      @views.IconName::FolderOpen,
      "Change folder",
      PickWorkingDirectory,
    ),
    action_button(@views.IconName::Refresh, "Refresh", RefreshFileTree),
    action_button(@views.IconName::Ellipsis, "More", OpenSettings),
  ]
  let file_rows : Array[@moui.View[MarkdownEditorMsg]] = []
  if has_folder {
    let name_width = markdown_editor_max_double(
      72.0,
      content_width - 20.0 - 18.0 - 3.0 * action_size - 6.0 * row_gap,
    )
    file_rows.push(
      row(
        [
          container(
            @views.icon(
              @views.IconName::Folder,
              size=12.0,
              color=@graphics.Color::white(),
            ),
            width=20.0,
            height=20.0,
            variant=@views.ContainerVariant::Base,
            background=theme.palette.primary,
            corner_radius=5.0,
            padding=0.0,
          ),
          button(
            markdown_editor_file_name(working_directory),
            on_click=ToggleFileTree,
            variant=@views.ButtonVariant::Ghost,
            theme=compact,
            width=name_width,
            height=24.0,
            label_align=@text.TextAlign::TextStart,
          )
          .font(panel_theme.typography.control)
          .foreground(theme.palette.foreground),
          button(
            if tree_expanded {
              "▾"
            } else {
              "▸"
            },
            on_click=ToggleFileTree,
            variant=@views.ButtonVariant::Ghost,
            theme=compact,
            width=18.0,
            height=22.0,
          ),
          spacer(min_length=0.0, weight=1.0),
          folder_actions[0],
          folder_actions[1],
          folder_actions[2],
        ],
        spacing=row_gap,
        align=@views.CrossAlign::Center,
      ),
    )
    if tree_expanded && tree_display_items.length() > 0 {
      file_rows.push(
        scroll_view(
          @views.tree_view(
            tree_display_items,
            expanded=tree_expanded_paths,
            selected=app.document_path,
            on_select=Some(id => SelectTreePath(id)),
            on_toggle=Some(id => ToggleTreePath(id)),
            on_secondary_tap=Some(id => {
              ContextMenuTargeted(app.explorer_target(id))
            }),
            theme=panel_theme,
            width=content_width,
          ),
          width=content_width,
          height=list_height,
        ),
      )
    } else {
      file_rows.push(
        frame(
          column(
            [
              text(
                if tree_expanded {
                  "No matching files"
                } else {
                  "Folder empty"
                },
                width=content_width,
                height=24.0,
                align=@text.TextAlign::TextStart,
              )
              .font(theme.typography.caption)
              .foreground(theme.palette.muted),
            ],
            spacing=0.0,
            align=@views.CrossAlign::Start,
          ),
          width=content_width,
          height=list_height,
        ),
      )
    }
  } else {
    file_rows.push(
      row(
        [
          container(
            @views.icon(
              @views.IconName::FolderOpen,
              size=12.0,
              color=@graphics.Color::white(),
            ),
            width=20.0,
            height=20.0,
            variant=@views.ContainerVariant::Base,
            background=theme.palette.primary,
            corner_radius=5.0,
            padding=0.0,
          ),
          text(
            "No folder open",
            width=markdown_editor_max_double(
              72.0,
              content_width - 20.0 - action_size - 3.0 * row_gap,
            ),
            height=24.0,
            align=@text.TextAlign::TextStart,
          )
          .font(theme.typography.label)
          .foreground(theme.palette.foreground),
          spacer(min_length=0.0, weight=1.0),
          action_button(@views.IconName::Ellipsis, "More", OpenSettings),
        ],
        spacing=row_gap,
        align=@views.CrossAlign::Center,
      ),
    )
    file_rows.push(
      button(
        "Open folder",
        on_click=PickWorkingDirectory,
        variant=@views.ButtonVariant::Tonal,
        theme=compact,
        width=content_width,
        height=28.0,
      ),
    )
    file_rows.push(
      text(
        "Recent",
        width=content_width,
        height=22.0,
        align=@text.TextAlign::TextStart,
      )
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    )
    if recent_paths.length() > 0 {
      file_rows.push(
        scroll_view(
          file_sidebar_recent_rows(
            recent_paths,
            width=content_width,
            current_path=app.document_path,
            panel_theme,
          ),
          width=content_width,
          height=list_height,
        ),
      )
    } else {
      file_rows.push(
        frame(
          column(
            [
              text(
                "No recent files",
                width=content_width,
                height=24.0,
                align=@text.TextAlign::TextStart,
              )
              .font(theme.typography.caption)
              .foreground(theme.palette.muted),
            ],
            spacing=0.0,
            align=@views.CrossAlign::Start,
          ),
          width=content_width,
          height=list_height,
        ),
      )
    }
  }
  file_rows.push(
    markdown_editor_file_sidebar_divider(theme, width=content_width),
  )
  file_rows.push(
    row(
      [
        button(
          if outline_expanded {
            "▾"
          } else {
            "›"
          },
          on_click=ToggleOutline,
          variant=@views.ButtonVariant::Ghost,
          theme=compact,
          width=20.0,
          height=24.0,
        ),
        button(
          "Outline",
          on_click=ToggleOutline,
          variant=@views.ButtonVariant::Ghost,
          theme=compact,
          width=content_width - 20.0 - row_gap,
          height=24.0,
          label_align=@text.TextAlign::TextStart,
        )
        .font(panel_theme.typography.control)
        .foreground(theme.palette.muted),
      ],
      spacing=row_gap,
      align=@views.CrossAlign::Center,
    ),
  )
  if outline_expanded {
    let visible_outline = markdown_editor_folded_outline(
      session.outline,
      app.folded_headings,
    )
    let active_index = markdown_editor_active_outline_index(
      session.outline,
      selection.caret,
    )
    if visible_outline.length() == 0 {
      file_rows.push(
        frame(
          column(
            [
              text(
                "No headings",
                width=content_width,
                height=24.0,
                align=@text.TextAlign::TextStart,
              )
              .font(theme.typography.caption)
              .foreground(theme.palette.muted),
            ],
            spacing=0.0,
            align=@views.CrossAlign::Start,
          ),
          width=content_width,
          height=outline_height,
        ),
      )
    } else {
      file_rows.push(
        scroll_view(
          outline_rows(
            app,
            session.outline,
            visible_outline,
            active_index,
            panel_theme,
            width=content_width,
          ),
          width=content_width,
          height=outline_height,
        ),
      )
    }
  }
  let pinned_content = frame(
    padding_edges(
      column(file_rows, spacing=row_gap, align=@views.CrossAlign::Start).on_secondary_tap(
        ContextMenuTargeted(MarkdownEditorContextTarget::ExplorerBackground),
      ),
      top=10.0,
      right=12.0,
      bottom=10.0,
      left=12.0,
    ),
    width~,
    height=panel_height,
  )
  let card_children : Array[@moui.View[MarkdownEditorMsg]] = []
  if header_height > 0.0 {
    card_children.push(header)
  }
  card_children.push(pinned_content)
  container(
    column(card_children, spacing=0.0, align=@views.CrossAlign::Stretch),
    width~,
    height~,
    variant=@views.ContainerVariant::Base,
    background=theme.palette.surface,
    corner_radius=theme.radius_scale.lg,
    padding=0.0,
  )
}

///|
fn document_info_inspector(
  session : MarkdownDocumentSession,
  theme : @moui.Theme,
  height~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let info = markdown_editor_document_info_from_session(session)
  let content_width = markdown_editor_info_content_width()
  let rows = column(
    [
      markdown_editor_info_row("Words", session.word_count.to_string(), theme),
      markdown_editor_info_row(
        "Characters",
        info.character_count.to_string(),
        theme,
      ),
      markdown_editor_info_row("Lines", session.line_count.to_string(), theme),
      markdown_editor_info_row(
        "Reading",
        markdown_editor_session_reading_time_short_label(session),
        theme,
      ),
      markdown_editor_info_divider(theme),
      markdown_editor_info_row(
        "Headings",
        info.heading_count.to_string(),
        theme,
      ),
      markdown_editor_info_row(
        "Paragraphs",
        info.paragraph_count.to_string(),
        theme,
      ),
      markdown_editor_info_row(
        "List items",
        info.list_item_count.to_string(),
        theme,
      ),
      markdown_editor_info_row(
        "Tasks",
        info.checked_task_count.to_string() + "/" + info.task_count.to_string(),
        theme,
      ),
      markdown_editor_info_row("Quotes", info.quote_count.to_string(), theme),
      markdown_editor_info_divider(theme),
      markdown_editor_info_row(
        "Code blocks",
        info.code_block_count.to_string(),
        theme,
      ),
      markdown_editor_info_row("Tables", info.table_count.to_string(), theme),
      markdown_editor_info_row("Links", info.link_count.to_string(), theme),
      markdown_editor_info_row("Images", info.image_count.to_string(), theme),
      markdown_editor_info_row(
        "Footnotes",
        info.footnote_reference_count.to_string() +
        "/" +
        info.footnote_definition_count.to_string(),
        theme,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Start,
  )
  container(
    padding_edges(
      column(
        [
          text("Info", width=content_width, height=24.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          scroll_view(
            rows,
            width=content_width,
            height=markdown_editor_max_double(0.0, height - 52.0),
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.sm,
      bottom=theme.spacing_scale.md,
      left=theme.spacing_scale.sm,
    ),
    width=markdown_editor_info_inspector_width(),
    height~,
    variant=@views.ContainerVariant::Base,
    background=theme.palette.surface,
    border=Some(
      @core.BorderStyle::new(
        brush=@graphics.Brush::solid(theme.palette.outline),
        width=1.0,
      ),
    ),
    corner_radius=theme.radius_scale.lg,
    padding=0.0,
  )
}

///|
fn markdown_editor_info_row(
  label : String,
  value : String,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  row(
    [
      text(label, width=126.0, height=24.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
      text(value, width=80.0, height=24.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.foreground),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
}

///|
fn markdown_editor_info_divider(
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  frame(empty(), width=markdown_editor_info_content_width(), height=1.0).background(
    theme.palette.muted.multiply_alpha(0.24),
  )
}

///|
#warnings("-unused_value")
fn markdown_editor_reading_time_short_label(
  snapshot : MarkdownEditorSnapshot,
) -> String {
  if snapshot.reading_minutes == 0 {
    "<1 min"
  } else if snapshot.reading_minutes == 1 {
    "1 min"
  } else {
    snapshot.reading_minutes.to_string() + " min"
  }
}

///|
fn markdown_editor_session_reading_time_short_label(
  session : MarkdownDocumentSession,
) -> String {
  if session.reading_minutes == 0 {
    "<1 min"
  } else if session.reading_minutes == 1 {
    "1 min"
  } else {
    session.reading_minutes.to_string() + " min"
  }
}

///|
fn file_sidebar_recent_rows(
  paths : Array[String],
  current_path~ : String,
  theme : @moui.Theme,
  width~ : Double = markdown_editor_file_sidebar_content_width(),
) -> @moui.View[MarkdownEditorMsg] {
  let rows : Array[@moui.View[MarkdownEditorMsg]] = []
  for path in paths {
    rows.push(
      file_sidebar_recent_row(path, current=path == current_path, width~),
    )
  }
  column(rows, spacing=theme.spacing_scale.xs, align=@views.CrossAlign::Start)
}

///|
fn file_sidebar_recent_row(
  path : String,
  current~ : Bool,
  width~ : Double = markdown_editor_file_sidebar_content_width(),
) -> @moui.View[MarkdownEditorMsg] {
  let (icon, _icon_color) = markdown_editor_tree_icon_for_name(
    markdown_editor_file_sidebar_recent_label(path),
  )
  button(
    markdown_editor_file_sidebar_recent_label(path),
    on_click=OpenRecentDocument(path),
    icon=Some(icon),
    variant=if current {
      @views.ButtonVariant::Tonal
    } else {
      @views.ButtonVariant::Ghost
    },
    width~,
    height=30.0,
    label_align=@text.TextAlign::TextStart,
  )
  // Recent rows are files the tree may not contain; the menu's Open action
  // resolves the recorded path either way.
  .on_secondary_tap(
    ContextMenuTargeted(MarkdownEditorContextTarget::ExplorerFile(path)),
  )
}

///|
fn markdown_editor_file_sidebar_current_label(
  path~ : String,
  fallback~ : String,
  dirty~ : Bool,
) -> String {
  let suffix = if dirty { " / Unsaved" } else { " / Saved" }
  markdown_editor_document_title(path~, fallback~) + suffix
}

///|
fn markdown_editor_file_sidebar_recent_label(path : String) -> String {
  let file = markdown_editor_file_name(path)
  if file == "" {
    "Untitled"
  } else {
    markdown_editor_outline_title(file)
  }
}

///|
fn source_preview(
  text : String,
  theme : @moui.Theme,
  height~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  scroll_view(source_preview_lines(text, theme), width=260.0, height~)
}

///|
fn source_inspector(
  source : String,
  theme : @moui.Theme,
  height~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  container(
    padding_edges(
      column(
        [
          text("Markdown source", width=260.0, height=24.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          source_preview(
            source,
            theme,
            height=markdown_editor_max_double(0.0, height - 52.0),
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.sm,
      bottom=theme.spacing_scale.md,
      left=theme.spacing_scale.sm,
    ),
    width=markdown_editor_source_inspector_width(),
    height~,
    variant=@views.ContainerVariant::Base,
    background=theme.palette.surface,
    border=Some(
      @core.BorderStyle::new(
        brush=@graphics.Brush::solid(theme.palette.outline),
        width=1.0,
      ),
    ),
    corner_radius=theme.radius_scale.lg,
    padding=0.0,
  )
}

///|
fn outline_rows(
  app : MarkdownEditorApp,
  full_outline : Array[MarkdownEditorOutlineItem],
  visible : Array[MarkdownEditorOutlineItem],
  active_index : Int32,
  theme : @moui.Theme,
  width~ : Double = markdown_editor_outline_content_width(),
) -> @moui.View[MarkdownEditorMsg] {
  let rows : Array[@moui.View[MarkdownEditorMsg]] = []
  for item in visible {
    let active = markdown_editor_outline_item_is_active(
      full_outline, item, active_index,
    )
    rows.push(outline_row(app, item, theme, width~, active~))
  }
  column(rows, spacing=2.0, align=@views.CrossAlign::Start)
}

///|
/// True when `item` matches the outline entry at `active_index` in the full
/// outline (so the active heading stays highlighted even while some are folded).
fn markdown_editor_outline_item_is_active(
  full_outline : Array[MarkdownEditorOutlineItem],
  item : MarkdownEditorOutlineItem,
  active_index : Int32,
) -> Bool {
  if active_index < 0 || active_index >= full_outline.length() {
    false
  } else {
    full_outline[active_index].source_start == item.source_start
  }
}

///|
fn outline_row(
  app : MarkdownEditorApp,
  item : MarkdownEditorOutlineItem,
  theme : @moui.Theme,
  width~ : Double,
  active~ : Bool,
) -> @moui.View[MarkdownEditorMsg] {
  let indent = markdown_editor_outline_indent_width(item.level)
  // A folded heading renders a '▸' prefix in its label to signal the folded
  // state; tapping the row still jumps to the heading. The dedicated toggle
  // affordance is intentionally not a separate button to preserve the row's
  // indent geometry that existing tests rely on.
  let folded = app.heading_is_folded(item.source_start)
  let label = if folded {
    "▸ " + markdown_editor_outline_label(item)
  } else {
    markdown_editor_outline_label(item)
  }
  padding_edges(
    button(
      label,
      on_click=JumpToOutline(item.source_start),
      variant=if active {
        @views.ButtonVariant::Tonal
      } else {
        @views.ButtonVariant::Ghost
      },
      theme=markdown_shell_compact_theme(theme, focus_ring=false),
      width=markdown_editor_max_double(96.0, width - indent),
      height=24.0,
      label_align=@text.TextAlign::TextStart,
    ).on_long_press(ToggleHeadingFold(item.source_start)),
    left=indent,
  )
}

///|

///|
fn markdown_editor_outline_indent_width(level : Int32) -> Double {
  markdown_editor_max_int(0, level - 1).to_double() * 12.0
}

///|
fn markdown_editor_outline_label(item : MarkdownEditorOutlineItem) -> String {
  let title = if item.title == "" { "Untitled" } else { item.title }
  "H" + item.level.to_string() + " " + markdown_editor_outline_title(title)
}

///|
fn markdown_editor_outline_title(title : String) -> String {
  if markdown_editor_text_length(title) <= 24 {
    title
  } else {
    markdown_editor_substring(title, 0, 21) + "..."
  }
}

///|
fn markdown_editor_active_outline_index(
  outline : Array[MarkdownEditorOutlineItem],
  caret : Int32,
) -> Int32 {
  let mut active = -1
  for index in 0..<outline.length() {
    if outline[index].source_start <= caret {
      active = index
    }
  }
  active
}

///|
