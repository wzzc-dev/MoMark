///|
fn MarkdownEditorApp::root(
  self : MarkdownEditorApp,
  viewport_width~ : Double = 1120.0,
  viewport_height~ : Double = 520.0,
  window_height? : Double,
  dark? : Bool,
) -> @moui.View[MarkdownEditorMsg] {
  let dark = match dark {
    Some(value) => value
    None => self.dark_mode_enabled
  }
  let scheme = if dark {
    @core.ColorScheme::Dark
  } else {
    @core.ColorScheme::Light
  }
  let tokens = markdown_ui_tokens(scheme)
  let theme = markdown_ui_theme(tokens)
  let metrics = markdown_shell_metrics(
    self.layout_mode,
    sidebar_width=self.sidebar_width,
  )
  let session = self.document_session.with_rich_text_palette(
    Some(tokens.rich_text),
  )
  let appearance = self.appearance_spec(dark=dark)
  let editor_font = markdown_editor_appearance_font(appearance)
  let zen = self.zen_mode_enabled
  // Both shells use the same inline panel layout in M1: the page keeps its
  // full width and panels push it instead of covering text. The minimal
  // floating drawer arrives with the M2 motion pass.
  let show_files = !zen && self.file_sidebar_visible
  let show_outline = !zen && self.outline_visible
  let show_source = !zen && self.source_preview_visible
  let show_info = !zen && self.document_info_visible
  let content_width = markdown_editor_max_double(
    0.0,
    viewport_width - metrics.island_margin * 2.0,
  )
  let workspace_width = markdown_editor_workspace_width(
    show_source,
    show_outline,
    show_files,
    show_info,
    appearance,
    viewport_width=content_width,
    sidebar_width=self.sidebar_width,
  )
  let target_bar = self.target_bar(theme)
  let selection = self.selection
  // The block target palette only surfaces after the user has actually
  // placed the caret (click/keys/edits); loading a document must not show
  // it just because the initial caret at offset 0 lands inside a rich block.
  let target_kind = if self.selection_engaged {
    self.target_kind
  } else {
    PlainSelection
  }
  let scroll_request = self.editor_scroll_request
  let children : Array[@moui.View[MarkdownEditorMsg]] = []
  children.push(
    editor_source_layout(
      self,
      session,
      editor_font,
      appearance,
      theme,
      show_source,
      show_outline,
      show_files,
      show_info,
      target_bar,
      selection,
      target_kind,
      scroll_request,
      (caret, selection) => SetSelection(caret, selection),
      offset => ToggleTaskAt(offset),
      viewport_width=content_width,
      viewport_height~,
      card_gap=metrics.island_gap,
      sidebar_width=self.sidebar_width,
      page_shadow=tokens.page_shadow,
      page_radius=metrics.island_radius,
    )
    .expanded(),
  )
  let workspace = @views.column(
    children,
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Stretch,
  )
  let top_bar = if zen {
    @views.empty()
  } else {
    self.markdown_shell_top_bar(tokens, metrics, theme)
  }
  let status_bar = if zen {
    @views.empty()
  } else {
    self.markdown_shell_status_bar(
      tokens, metrics, theme, session, selection,
      viewport_width~,
    )
  }
  let shell_children : Array[@moui.View[MarkdownEditorMsg]] = [
    top_bar,
    workspace.expanded(),
    status_bar,
  ]
  let mut auxiliary_height = 0.0
  let mut auxiliary_count = 0
  if !zen && self.find_visible {
    auxiliary_height = auxiliary_height + 42.0
    auxiliary_count = auxiliary_count + 1
  }
  if !zen && self.format_palette_visible {
    auxiliary_height = auxiliary_height + 240.0
    auxiliary_count = auxiliary_count + 1
  }
  let bars_height = if zen {
    0.0
  } else {
    metrics.top_bar_height + metrics.status_bar_height
  }
  let total_height = match window_height {
    Some(value) => value
    None =>
      viewport_height + bars_height + metrics.island_margin * 2.0
  }
  let shell = @views.column(
    shell_children,
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  ).frame(
    width=markdown_editor_max_double(
      0.0,
      viewport_width - metrics.island_margin * 2.0,
    ),
    height=markdown_editor_max_double(
      0.0,
      total_height - metrics.island_margin * 2.0,
    ),
  )
  let inset = @views.padding_edges(
    shell,
    top=metrics.island_margin,
    right=metrics.island_margin,
    bottom=metrics.island_margin,
    left=metrics.island_margin,
  )
  // Stack: frame fill → island shell → minimal overlays → dialogs.
  let no_views : Array[@moui.View[MarkdownEditorMsg]] = []
  let window_bg = @views.custom_children_layout(
    children=no_views,
    measure=ctx => ctx.constraints.constrain(ctx.constraints.max),
    place=_ctx => {
      let rects : Array[@geometry.Rect] = []
      rects
    },
    paint=(ctx, bounds) => fill_rect(ctx, bounds, tokens.frame),
    semantics_label="Window background",
  )
  let layers : Array[@moui.View[MarkdownEditorMsg]] = [window_bg, inset]
  let overlay_top = metrics.island_margin + metrics.top_bar_height + 8.0
  if !zen && self.find_visible {
    layers.push(
      markdown_top_overlay(
        self.find_bar(theme, selection, workspace_width),
        top=overlay_top,
      ),
    )
  }
  if !zen && self.format_palette_visible {
    layers.push(
      markdown_top_overlay(
        self.format_palette(theme, workspace_width),
        top=overlay_top,
      ),
    )
  }
  if !zen && self.settings_visible {
    layers.push(
      @views.align(
        self.markdown_settings_panel(tokens, metrics, theme),
        alignment=@geometry.Alignment::center(),
      ),
    )
  }
  layers.push(
    @views.align(
      self.toast_layer(),
      alignment=@geometry.Alignment::new(x=0.5, y=0.0),
    ),
  )
  layers.push(
    @views.align(
      self.confirm_dialog(theme),
      alignment=@geometry.Alignment::center(),
    ),
  )
  // Root fallback: any right-press that no inner handler claimed (chrome,
  // status bar, dialogs) lands here and gets the global menu. More specific
  // targets are recorded deeper in the tree and win by activation order.
  @views.stack(layers)
  .on_secondary_tap(ContextMenuTargeted(MarkdownEditorContextTarget::Global))
  .theme(theme)
}

///|
/// Adapt the host viewport to the editor's fixed chrome and auxiliary panels.
/// This keeps the app on the immutable Program/ViewEnvironment path without
/// requiring a component-scoped context.
fn MarkdownEditorApp::root_with_environment(
  self : MarkdownEditorApp,
  view_environment : @core.ViewEnvironment,
) -> @moui.View[MarkdownEditorMsg] {
  let viewport = view_environment.viewport_size()
  let system_scheme = view_environment.environment().system_scheme
  let dark = if self.follow_system_scheme {
    system_scheme is @core.ColorScheme::Dark
  } else {
    self.dark_mode_enabled
  }
  let metrics = markdown_shell_metrics(
    self.layout_mode,
    sidebar_width=self.sidebar_width,
  )
  let zen = self.zen_mode_enabled
  let mut fixed_height = metrics.island_margin * 2.0
  if !zen {
    fixed_height = fixed_height +
      metrics.top_bar_height +
      metrics.status_bar_height
  }
  let viewport_height = markdown_editor_max_double(
    320.0,
    viewport.height - fixed_height,
  )
  self.root(
    viewport_width=viewport.width,
    viewport_height~,
    window_height=viewport.height,
    dark=dark,
  )
}

///|
///|
fn markdown_editor_workspace_width(
  show_source : Bool,
  show_outline : Bool,
  show_files : Bool,
  show_info : Bool,
  appearance : MarkdownEditorAppearanceSpec,
  viewport_width~ : Double,
  sidebar_width~ : Double = markdown_editor_file_sidebar_width(),
) -> Double {
  let editor_width = markdown_editor_primary_editor_width_for_viewport(
    show_source,
    show_outline,
    show_files,
    show_info,
    appearance,
    viewport_width~,
    sidebar_width~,
  )
  let sidebars_width = markdown_editor_sidebar_total_width(
    show_source, show_outline, show_files, show_info, sidebar_width~,
  )
  markdown_editor_min_double(viewport_width, editor_width + sidebars_width)
}

///|
fn MarkdownEditorApp::find_bar(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
  selection : MarkdownEditorSelection,
  width : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let query = self.find_query
  let matches = self.find_matches
  let options = self.find_options
  frame(
    row(
      [
        text("Find", width=44.0, height=34.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text_field(
          query,
          on_input=value => UpdateFindQuery(value),
          on_submit=Some(FindNext),
          placeholder="Search Markdown",
          variant=@views.TextFieldVariant::Outline,
          width=196.0,
          height=34.0,
        ).key("markdown-find-query"),
        text("Replace", width=64.0, height=34.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text_field(
          self.replace_text,
          on_input=value => UpdateReplaceText(value),
          on_submit=Some(ReplaceFindCurrent),
          placeholder="Replacement",
          variant=@views.TextFieldVariant::Outline,
          width=196.0,
          height=34.0,
        ).key("markdown-replace-text"),
        editor_find_toggle(
          "Aa",
          "Match case",
          ToggleFindCaseSensitive,
          options.case_sensitive,
        ),
        editor_find_toggle(
          "W",
          "Whole word",
          ToggleFindWholeWord,
          options.whole_word,
        ),
        editor_find_toggle(".*", "Regex", ToggleFindRegex, options.regex),
        text(
          markdown_editor_find_status_label(query, matches, selection, options~),
          width=88.0,
          height=34.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        editor_find_icon_button(
          @views.IconName::ChevronLeft,
          "Previous match",
          FindPrevious,
        ),
        editor_find_icon_button(
          @views.IconName::ChevronRight,
          "Next match",
          FindNext,
        ),
        editor_button(
          "Replace",
          ReplaceFindCurrent,
          @views.ButtonVariant::Tonal,
        ),
        editor_button("All", ReplaceFindAll, @views.ButtonVariant::Tonal),
        editor_find_icon_button(
          @views.IconName::Close,
          "Close find bar",
          CloseFind,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=42.0,
  )
}

///|
fn MarkdownEditorApp::format_palette(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
  width : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let panel_width = markdown_editor_min_double(580.0, width)
  let content_width = markdown_editor_max_double(
    160.0,
    panel_width - 32.0,
  )
  let query = self.format_palette_query
  let rows : Array[@moui.View[MarkdownEditorMsg]] = []
  for item in markdown_editor_format_palette_filtered_items(query) {
    rows.push(
      markdown_editor_format_palette_row(item, theme, width=content_width),
    )
  }
  if rows.length() == 0 {
    rows.push(
      text("No commands", width=content_width, height=36.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    )
  }
  container(
    padding_edges(
      column(
        [
          row(
            [
              text("Commands", width=92.0, height=36.0)
              .font(theme.typography.caption)
              .foreground(theme.palette.muted),
              text_field(
                query,
                on_input=value => UpdateFormatPaletteQuery(value),
                on_submit=Some(ApplyFirstFormatPaletteAction),
                placeholder="Search commands",
                variant=@views.TextFieldVariant::Outline,
                width=markdown_editor_max_double(
                  120.0,
                  content_width - 92.0 - 76.0 - 16.0,
                ),
                height=36.0,
              ).key("markdown-format-palette-query"),
              editor_button(
                "Done",
                ToggleFormatPalette,
                @views.ButtonVariant::Ghost,
              ),
            ],
            spacing=theme.spacing_scale.sm,
            align=@views.CrossAlign::Center,
          ),
          scroll_view(
            column(
              rows,
              spacing=2.0,
              align=@views.CrossAlign::Start,
            ),
            width=content_width,
            height=286.0,
          ),
          text(
            "Enter applies the first match · Esc closes",
            width=content_width,
            height=18.0,
          )
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.md,
      bottom=theme.spacing_scale.sm,
      left=theme.spacing_scale.md,
    ),
    width=panel_width,
    height=384.0,
    variant=@views.ContainerVariant::Overlay,
    background=theme.palette.surface,
    border=Some(
      @core.BorderStyle::new(
        brush=@graphics.Brush::solid(theme.palette.outline),
        width=1.0,
      ),
    ),
    corner_radius=theme.radius_scale.lg,
    padding=0.0,
  ).shadow(
    @graphics.ShadowStyle::new(
      color=@graphics.Color::black().multiply_alpha(0.16),
      offset=@geometry.Point::new(x=0.0, y=8.0),
      blur_radius=28.0,
    ),
  )
}

///|
fn markdown_editor_format_palette_icon(
  group : String,
) -> @views.IconName {
  match group {
    "Inline" => @views.IconName::Bold
    "View" => @views.IconName::Eye
    "Document" => @views.IconName::FileMarkdown
    _ => @views.IconName::Heading
  }
}

///|
fn markdown_editor_format_palette_row(
  item : MarkdownEditorFormatPaletteItem,
  theme : @moui.Theme,
  width~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  let label_width = markdown_editor_max_double(140.0, width - 78.0 - 150.0 - 16.0)
  row(
    [
      button(
        item.label,
        on_click=ApplyFormatPaletteAction(item.action),
        variant=@views.ButtonVariant::Ghost,
        icon=Some(markdown_editor_format_palette_icon(item.group)),
        width=label_width,
        height=36.0,
      ),
      text(item.group, width=78.0, height=36.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
      text(item.shortcut, width=150.0, height=36.0)
      .font(theme.typography.caption)
      .foreground(theme.palette.muted),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  )
}

///|
fn markdown_editor_format_palette_filtered_items(
  query : String,
) -> Array[MarkdownEditorFormatPaletteItem] {
  let items = markdown_editor_format_palette_items()
  let needle = query.trim().to_owned().to_lower()
  if needle == "" {
    items
  } else {
    items.filter(item => markdown_editor_format_palette_matches(item, needle))
  }
}

///|
fn markdown_editor_fuzzy_subsequence(text : String, needle : String) -> Bool {
  if needle == "" {
    return true
  }
  let haystack = text.to_lower().to_array()
  let pattern = needle.to_array()
  let mut matched = 0
  for ch in haystack {
    if matched < pattern.length() && ch == pattern[matched] {
      matched = matched + 1
    }
  }
  matched == pattern.length()
}

///|
fn markdown_editor_format_palette_matches(
  item : MarkdownEditorFormatPaletteItem,
  needle : String,
) -> Bool {
  markdown_editor_fuzzy_subsequence(item.label, needle) ||
  markdown_editor_fuzzy_subsequence(item.group, needle) ||
  markdown_editor_fuzzy_subsequence(item.shortcut, needle)
}

///|
fn markdown_editor_format_palette_items() -> Array[
  MarkdownEditorFormatPaletteItem,
] {
  [
    {
      action: "paragraph",
      label: "Paragraph",
      group: "Block",
      shortcut: "Meta+0 / Ctrl+0",
    },
    {
      action: "h1",
      label: "Heading 1",
      group: "Block",
      shortcut: "Meta+1 / Ctrl+1",
    },
    {
      action: "h2",
      label: "Heading 2",
      group: "Block",
      shortcut: "Meta+2 / Ctrl+2",
    },
    {
      action: "h3",
      label: "Heading 3",
      group: "Block",
      shortcut: "Meta+3 / Ctrl+3",
    },
    {
      action: "bold",
      label: "Bold",
      group: "Inline",
      shortcut: "Meta+B / Ctrl+B",
    },
    {
      action: "italic",
      label: "Italic",
      group: "Inline",
      shortcut: "Meta+I / Ctrl+I",
    },
    {
      action: "code",
      label: "Inline Code",
      group: "Inline",
      shortcut: "Meta+E / Ctrl+E",
    },
    {
      action: "strike",
      label: "Strikethrough",
      group: "Inline",
      shortcut: "Meta+Shift+X",
    },
    {
      action: "highlight",
      label: "Highlight",
      group: "Inline",
      shortcut: "Meta+Shift+H",
    },
    {
      action: "link",
      label: "Link",
      group: "Inline",
      shortcut: "Meta+L / Ctrl+K",
    },
    {
      action: "image",
      label: "Image",
      group: "Inline",
      shortcut: "Meta+Shift+I",
    },
    { action: "ul", label: "Bullet List", group: "Block", shortcut: "Meta+U", },
    { action: "task", label: "Task List", group: "Block", shortcut: "Meta+T", },
    { action: "ol", label: "Ordered List", group: "Block", shortcut: "Meta+O", },
    { action: "quote", label: "Quote", group: "Block", shortcut: "Meta+Q", },
    {
      action: "codeblock",
      label: "Code Block",
      group: "Block",
      shortcut: "Meta+K",
    },
    { action: "table", label: "Table", group: "Block", shortcut: "", },
    {
      action: "toc",
      label: "Table of Contents",
      group: "Document",
      shortcut: "Meta+Alt+T",
    },
    {
      action: "front-matter",
      label: "YAML Front Matter",
      group: "Document",
      shortcut: "Meta+Alt+Y",
    },
    { action: "rule", label: "Horizontal Rule", group: "Block", shortcut: "", },
    {
      action: "duplicate-block",
      label: "Duplicate Block",
      group: "Block",
      shortcut: "Meta+Shift+D",
    },
    {
      action: "focus-mode",
      label: "Focus Mode",
      group: "View",
      shortcut: "Meta+Shift+F",
    },
    {
      action: "typewriter-mode",
      label: "Typewriter Mode",
      group: "View",
      shortcut: "Meta+Shift+T",
    },
    {
      action: "zen-mode",
      label: "Zen Mode",
      group: "View",
      shortcut: "Meta+Alt+Z",
    },
    {
      action: "source-mode",
      label: "Source Mode",
      group: "View",
      shortcut: "Meta+Shift+/",
    },
    { action: "files", label: "Files", group: "View", shortcut: "Meta+Alt+P", },
    {
      action: "image-center",
      label: "Center Image",
      group: "Block",
      shortcut: "",
    },
    {
      action: "html-export",
      label: "Export HTML",
      group: "Document",
      shortcut: "Meta+Alt+E",
    },
    {
      action: "document-info",
      label: "Document Info",
      group: "View",
      shortcut: "Meta+Alt+D",
    },
    { action: "look-paper", label: "Paper Look", group: "View", shortcut: "", },
    {
      action: "look-warm",
      label: "Warm Look",
      group: "View",
      shortcut: "Meta+Alt+L",
    },
    {
      action: "look-wide",
      label: "Wide Look",
      group: "View",
      shortcut: "Meta+Alt+L",
    },
  ]
}

///|
#warnings("-unused_value")
fn MarkdownEditorApp::source_mode_status_suffix(
  self : MarkdownEditorApp,
) -> String {
  if self.source_mode_enabled {
    " / Source Mode"
  } else {
    ""
  }
}

///|
#warnings("-unused_value")
fn MarkdownEditorApp::appearance_status_suffix(
  self : MarkdownEditorApp,
) -> String {
  let label = self.appearance_label()
  if label == "Paper" {
    ""
  } else {
    " / Look: " + label
  }
}

///|
#warnings("-unused_value")
fn MarkdownEditorApp::writing_mode_status_suffix(
  self : MarkdownEditorApp,
) -> String {
  let modes : Array[String] = []
  if self.focus_mode_enabled {
    modes.push("Focus")
  }
  if self.typewriter_mode_enabled {
    modes.push("Typewriter")
  }
  if self.zen_mode_enabled {
    modes.push("Zen")
  }
  if modes.length() == 0 {
    ""
  } else {
    " / " + markdown_join_strings_with_separator(modes, " + ")
  }
}

///|
fn markdown_join_strings_with_separator(
  parts : Array[String],
  separator : String,
) -> String {
  let chars : Array[Char] = []
  for index, part in parts {
    if index > 0 {
      chars.append(separator.to_array())
    }
    chars.append(part.to_array())
  }
  String::from_array(chars)
}

///|
#warnings("-unused_value")
fn markdown_editor_document_info(
  snapshot : MarkdownEditorSnapshot,
) -> MarkdownEditorDocumentInfo {
  markdown_editor_document_info_from_parts(snapshot.source, snapshot.blocks)
}

///|
fn markdown_editor_document_info_from_session(
  session : MarkdownDocumentSession,
) -> MarkdownEditorDocumentInfo {
  markdown_editor_document_info_from_parts(
    session.source(),
    session.editor_blocks,
  )
}

///|
fn markdown_editor_document_info_from_parts(
  source : String,
  blocks : Array[MarkdownEditorBlock],
) -> MarkdownEditorDocumentInfo {
  let mut heading_count = 0
  let mut paragraph_count = 0
  let mut list_item_count = 0
  let mut task_count = 0
  let mut checked_task_count = 0
  let mut quote_count = 0
  let mut code_block_count = 0
  let mut table_count = 0
  let mut link_count = 0
  let mut image_count = 0
  let mut footnote_reference_count = 0
  let mut footnote_definition_count = 0
  for editor_block in blocks {
    match editor_block.block.kind {
      Heading(_) => heading_count = heading_count + 1
      Paragraph =>
        if editor_block.block.text.trim().to_owned() != "" {
          paragraph_count = paragraph_count + 1
        }
      UnorderedListItem | OrderedListItem(_) =>
        list_item_count = list_item_count + 1
      TaskListItem(checked) => {
        task_count = task_count + 1
        list_item_count = list_item_count + 1
        if checked {
          checked_task_count = checked_task_count + 1
        }
      }
      Blockquote => quote_count = quote_count + 1
      CodeBlock => code_block_count = code_block_count + 1
      Table => table_count = table_count + 1
      FootnoteDefinition(_) =>
        footnote_definition_count = footnote_definition_count + 1
      HorizontalRule | HtmlBlock | FrontMatter => ()
    }
    for inline in editor_block.block.inlines {
      match inline.kind {
        Link | Autolink => link_count = link_count + 1
        Image => image_count = image_count + 1
        FootnoteReference =>
          footnote_reference_count = footnote_reference_count + 1
        Plain | Bold | Italic | Code | Strikethrough | Highlight | HtmlInline =>
          ()
      }
    }
  }
  {
    character_count: markdown_editor_text_length(source),
    heading_count,
    paragraph_count,
    list_item_count,
    task_count,
    checked_task_count,
    quote_count,
    code_block_count,
    table_count,
    link_count,
    image_count,
    footnote_reference_count,
    footnote_definition_count,
  }
}

///|
