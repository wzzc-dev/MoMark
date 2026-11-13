///|

///|
/// Compact control theme for the 32px chrome band. MoUI buttons derive their
/// height from `typography.control` plus `2 * spacing.sm`, so the explicit
/// 20–22px heights only take effect with tighter padding and a smaller
/// control font. Everything else (palette, radii, motion) stays the shell's.
fn markdown_shell_compact_theme(theme : @moui.Theme) -> @moui.Theme {
  let control_font = @core.FontSpec::new(size=12.0, weight=500)
  @views.theme(
    base=theme,
    spacing_scale={ ..theme.spacing_scale, sm: 2.0, lg: 4.0, },
    typography={
      ..theme.typography,
      control: control_font,
      label: control_font,
    },
  )
}

///|
/// A shell icon button with a tooltip and a compact hit area. The top bar uses
/// one idiom for every action so the right cluster reads as a group.
fn markdown_shell_icon_button(
  icon : @views.IconName,
  label : String,
  message : MarkdownEditorMsg,
  theme : @moui.Theme,
  active~ : Bool = false,
) -> @moui.View[MarkdownEditorMsg] {
  let variant = if active {
    @views.ButtonVariant::Tonal
  } else {
    @views.ButtonVariant::Ghost
  }
  tooltip(
    button(
      "",
      on_click=message,
      variant~,
      icon=Some(icon),
      theme=markdown_shell_compact_theme(theme),
      width=22.0,
      height=22.0,
    ),
    label,
  )
}

///|
/// One segment inside the sidebar-view control: a ghost icon button, raised
/// onto a card-colored pill when active (the Winc segmented-control look)
/// instead of the accent-tinted tonal fill.
fn markdown_shell_segment(
  icon : @views.IconName,
  label : String,
  message : MarkdownEditorMsg,
  tokens : MarkdownUiTokens,
  theme : @moui.Theme,
  active~ : Bool = false,
) -> @moui.View[MarkdownEditorMsg] {
  let segment = tooltip(
    button(
      "",
      on_click=message,
      variant=@views.ButtonVariant::Ghost,
      icon=Some(icon),
      theme=markdown_shell_compact_theme(theme),
      width=20.0,
      height=20.0,
    ),
    label,
  )
  if active {
    @views.container(
      segment,
      variant=@views.ContainerVariant::Base,
      background=tokens.card,
      border=Some(
        @core.BorderStyle::new(
          brush=@graphics.Brush::solid(tokens.page_border),
          width=1.0,
        ),
      ),
      corner_radius=6.0,
      padding=0.0,
    )
  } else {
    segment
  }
}

///|

///|
/// The chrome controls: sidebar toggle plus the Files/Outline segmented view
/// switch. The workspace shell puts them in the sidebar card's header; the
/// minimal shell puts them at the left edge of the editor tab strip, since it
/// has no persistent sidebar card to host them.
fn MarkdownEditorApp::markdown_shell_sidebar_controls(
  self : MarkdownEditorApp,
  tokens : MarkdownUiTokens,
  theme : @moui.Theme,
) -> Array[@moui.View[MarkdownEditorMsg]] {
  let files_active = self.sidebar_panel is FilesPanel &&
    self.file_sidebar_visible
  let outline_active = self.sidebar_panel is OutlinePanel &&
    self.outline_visible
  let segmented = @views.container(
    @views.row(
      [
        markdown_shell_segment(
          @views.IconName::Folder,
          "Files",
          SetSidebarPanel(FilesPanel),
          tokens,
          theme,
          active=files_active,
        ),
        markdown_shell_segment(
          @views.IconName::ListBullet,
          "Outline",
          SetSidebarPanel(OutlinePanel),
          tokens,
          theme,
          active=outline_active,
        ),
      ],
      spacing=2.0,
      align=@views.CrossAlign::Center,
    ),
    variant=@views.ContainerVariant::Base,
    background=tokens.hover,
    corner_radius=8.0,
    padding=2.0,
  )
  let sidebar_toggle = markdown_shell_icon_button(
    @views.IconName::Sidebar,
    "Toggle sidebar",
    ToggleFileSidebar,
    theme,
  )
  [sidebar_toggle, segmented]
}

///|
/// The sidebar card's header band: traffic-light inset, sidebar toggle, and
/// the view segmented control on the card surface. This is half of the
/// single 32px chrome band — the editor card's tab strip is the other half.
fn MarkdownEditorApp::markdown_shell_sidebar_header(
  self : MarkdownEditorApp,
  tokens : MarkdownUiTokens,
  metrics : MarkdownShellMetrics,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let controls = self.markdown_shell_sidebar_controls(tokens, theme)
  // The native traffic lights sit a few points above the card's vertical
  // center; nudge the header controls up so their centers line up.
  @views.frame(
    @views.row(
      [
        @views.spacer(min_length=78.0, weight=0.0),
        controls[0],
        @views.spacer(min_length=6.0, weight=0.0),
        controls[1],
        @views.spacer(min_length=0.0, weight=1.0),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Center,
    ),
    height=metrics.top_bar_height,
  ).offset(dy=-4.0)
}

///|
/// Status bar: path on the left, save state in the middle, cursor/word context
/// on the right. The workspace bar is 26px and the minimal one 24px; both use
/// the frame surface so the island cards stay the only raised content.
fn MarkdownEditorApp::markdown_shell_status_bar(
  self : MarkdownEditorApp,
  tokens : MarkdownUiTokens,
  metrics : MarkdownShellMetrics,
  theme : @moui.Theme,
  session : @moui_richtext.MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  viewport_width~ : Double = 1000.0,
) -> @moui.View[MarkdownEditorMsg] {
  let title = markdown_editor_document_title(
    path=self.document_path,
    fallback="Untitled",
  )
  let saved = if self.transfer_in_progress() {
    "Saving…"
  } else if self.is_dirty() {
    "Unsaved"
  } else {
    "Saved"
  }
  let line_column = markdown_editor_line_column_label(
    session.source(),
    selection.caret,
  )
  let mode = if self.source_mode_enabled {
    "Source"
  } else if self.source_preview_visible {
    "Split"
  } else {
    "Markdown"
  }
  let folder = if self.working_directory != "" {
    markdown_editor_file_name(self.working_directory)
  } else {
    "MoMark"
  }
  let breadcrumb = folder + "  ›  " + title
  let left_width = 320.0
  let right_width = markdown_editor_max_double(
    180.0,
    viewport_width - left_width - 220.0,
  )
  let right_text = saved +
    " · " +
    line_column +
    " · " +
    session.word_count.to_string() +
    " words · " +
    mode
  let settings_button = tooltip(
    button(
      "",
      on_click=OpenSettings,
      variant=if self.settings_visible {
        @views.ButtonVariant::Tonal
      } else {
        @views.ButtonVariant::Ghost
      },
      icon=Some(@views.IconName::Settings),
      width=22.0,
      height=22.0,
    ),
    "Settings",
  )
  frame(
    row(
      [
        spacer(min_length=metrics.bar_inset + metrics.island_margin, weight=0.0),
        text(
          breadcrumb,
          width=left_width,
          height=metrics.status_bar_height,
          align=@text.TextAlign::TextStart,
        )
        .font(theme.typography.caption)
        .foreground(tokens.text_muted),
        spacer(min_length=0.0, weight=1.0),
        text(
          right_text,
          width=right_width,
          height=metrics.status_bar_height,
          align=@text.TextAlign::TextEnd,
        )
        .font(theme.typography.caption)
        .foreground(tokens.text_muted),
        settings_button,
        spacer(min_length=metrics.bar_inset + metrics.island_margin, weight=0.0),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    height=metrics.status_bar_height,
  )
  .background(tokens.frame)
  .repaint_boundary()
}

///|
/// One-based source line and column for the caret. Counts characters, matching
/// the `MarkdownEditorSelection` offset space; line breaks advance the line and
/// reset the column.
fn markdown_editor_line_column_label(source : String, caret : Int32) -> String {
  let target = markdown_editor_clamp_int(
    caret,
    0,
    markdown_editor_text_length(source),
  )
  let mut line = 1
  let mut column = 1
  let mut offset = 0
  for ch in source {
    if offset >= target {
      break
    }
    if ch == '\n' {
      line = line + 1
      column = 1
    } else {
      column = column + 1
    }
    offset = offset + 1
  }
  "Ln " + line.to_string() + ", Col " + column.to_string()
}

///|
/// A compact choice chip used by the settings sheet. Active choices use the
/// tonal fill; inactive ones stay ghost so the current value reads at a glance.
fn markdown_shell_choice(
  label : String,
  active : Bool,
  message : MarkdownEditorMsg,
  metrics : MarkdownShellMetrics,
  theme : @moui.Theme,
  width~ : Double = 112.0,
) -> @moui.View[MarkdownEditorMsg] {
  button(
    label,
    on_click=message,
    variant=if active {
      @views.ButtonVariant::Tonal
    } else {
      @views.ButtonVariant::Ghost
    },
    theme=markdown_shell_compact_theme(theme),
    width~,
    height=metrics.control_height,
  )
}

///|
/// One segmented control row in the settings sheet: text choices in a track,
/// the active one raised on a card-colored pill (Winc's settings idiom).
fn markdown_settings_segmented(
  choices : Array[(String, MarkdownEditorMsg, Bool)],
  theme : @moui.Theme,
  tokens : MarkdownUiTokens,
  metrics : MarkdownShellMetrics,
  width~ : Double = 84.0,
) -> @moui.View[MarkdownEditorMsg] {
  let buttons : Array[@moui.View[MarkdownEditorMsg]] = []
  for choice in choices {
    buttons.push(
      markdown_shell_choice(
        choice.0,
        choice.2,
        choice.1,
        metrics,
        theme,
        width~,
      ),
    )
  }
  @views.container(
    @views.row(buttons, spacing=2.0, align=@views.CrossAlign::Center),
    variant=@views.ContainerVariant::Base,
    background=tokens.hover,
    corner_radius=8.0,
    padding=2.0,
  )
}

///|
/// One settings row: label (and optional description) on the left, control on
/// the right, with a hairline divider between rows supplied by the group.
fn markdown_settings_row(
  label : String,
  description : String,
  control : @moui.View[MarkdownEditorMsg],
  theme : @moui.Theme,
  tokens : MarkdownUiTokens,
) -> @moui.View[MarkdownEditorMsg] {
  let texts : Array[@moui.View[MarkdownEditorMsg]] = [
    text(label, width=240.0, height=22.0, align=@text.TextAlign::TextStart)
    .font(theme.typography.label)
    .foreground(tokens.text),
  ]
  if description != "" {
    texts.push(
      text(
        description,
        width=260.0,
        height=18.0,
        align=@text.TextAlign::TextStart,
      )
      .font(theme.typography.caption)
      .foreground(tokens.text_muted),
    )
  }
  @views.padding_edges(
    @views.row(
      [
        @views.column(texts, spacing=2.0, align=@views.CrossAlign::Start),
        @views.spacer(min_length=0.0, weight=1.0),
        control,
      ],
      spacing=12.0,
      align=@views.CrossAlign::Center,
    ),
    top=10.0,
    bottom=10.0,
  )
}

///|
/// A settings card: rounded surface-variant group with hairline dividers.
fn markdown_settings_group(
  rows : Array[@moui.View[MarkdownEditorMsg]],
  tokens : MarkdownUiTokens,
) -> @moui.View[MarkdownEditorMsg] {
  let children : Array[@moui.View[MarkdownEditorMsg]] = []
  for index, row_view in rows {
    if index > 0 {
      children.push(
        @views.frame(@views.empty(), height=1.0).background(tokens.divider),
      )
    }
    children.push(row_view)
  }
  @views.container(
    @views.padding_edges(
      @views.column(children, spacing=0.0, align=@views.CrossAlign::Stretch),
      top=6.0,
      right=12.0,
      bottom=6.0,
      left=12.0,
    ),
    variant=@views.ContainerVariant::Base,
    background=tokens.frame,
    corner_radius=10.0,
    padding=0.0,
  )
}

///|
/// Settings sheet, Winc-style: a left section nav and grouped rows on the
/// right. Only real, wired options are shown.
fn MarkdownEditorApp::markdown_settings_panel(
  self : MarkdownEditorApp,
  tokens : MarkdownUiTokens,
  metrics : MarkdownShellMetrics,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let section = self.settings_section
  let nav_item = fn(
    index : Int32,
    label : String,
  ) -> @moui.View[MarkdownEditorMsg] {
    button(
      label,
      on_click=SetSettingsSection(index),
      variant=if section == index {
        @views.ButtonVariant::Tonal
      } else {
        @views.ButtonVariant::Ghost
      },
      width=176.0,
      height=34.0,
      label_align=@text.TextAlign::TextStart,
    )
  }
  let nav = @views.padding_edges(
    @views.column(
      [
        text("Settings", width=176.0, height=30.0)
        .font(theme.typography.title)
        .foreground(tokens.text),
        @views.spacer(min_length=8.0, weight=0.0),
        nav_item(0, "Appearance"),
        nav_item(1, "Editor"),
        nav_item(2, "About"),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Start,
    ),
    top=18.0,
    right=12.0,
    bottom=18.0,
    left=12.0,
  )
  let nav_card = @views.container(
    @views.frame(nav, width=200.0, height=540.0),
    width=200.0,
    height=540.0,
    variant=@views.ContainerVariant::Base,
    background=tokens.frame,
    corner_radius=10.0,
    padding=0.0,
  )
  let title = match section {
    1 => "Editor"
    2 => "About"
    _ => "Appearance"
  }
  let body : Array[@moui.View[MarkdownEditorMsg]] = []
  match section {
    1 => {
      let zoom_row = markdown_settings_row(
        "Zoom",
        "Scale the document without changing the layout",
        @views.row(
          [
            markdown_shell_choice(
              "−",
              false,
              ZoomOut,
              metrics,
              theme,
              width=36.0,
            ),
            button(
              (self.editor_zoom * 100.0).to_int().to_string() + "%",
              on_click=ResetZoom,
              variant=@views.ButtonVariant::Ghost,
              width=64.0,
              height=metrics.control_height,
            ),
            markdown_shell_choice(
              "+",
              false,
              ZoomIn,
              metrics,
              theme,
              width=36.0,
            ),
          ],
          spacing=2.0,
          align=@views.CrossAlign::Center,
        ),
        theme,
        tokens,
      )
      let outline_row = markdown_settings_row(
        "Outline section",
        "Dock the document outline under the file tree",
        @views.checkbox(
          "",
          checked=self.outline_visible,
          on_change=_ => ToggleOutline,
          theme~,
          height=28.0,
        ),
        theme,
        tokens,
      )
      body.push(markdown_settings_group([zoom_row, outline_row], tokens))
    }
    2 => {
      let about = @views.padding_edges(
        @views.column(
          [
            text("MoMark", width=480.0, height=26.0)
            .font(theme.typography.title)
            .foreground(tokens.text),
            text(
              "A WYSIWYG Markdown editor built on MoUI and moui_richtext.",
              width=480.0,
              height=20.0,
            )
            .font(theme.typography.caption)
            .foreground(tokens.text_muted),
            text(
              "Source view, outline and file tree live in one workspace shell.",
              width=480.0,
              height=20.0,
            )
            .font(theme.typography.caption)
            .foreground(tokens.text_muted),
          ],
          spacing=6.0,
          align=@views.CrossAlign::Start,
        ),
        top=12.0,
        right=16.0,
        bottom=12.0,
        left=16.0,
      )
      body.push(
        @views.container(
          about,
          variant=@views.ContainerVariant::Base,
          background=tokens.frame,
          corner_radius=10.0,
          padding=0.0,
        ),
      )
    }
    _ => {
      let follow = self.follow_system_scheme
      let mode_row = markdown_settings_row(
        "Mode",
        "Follow the system or pin a color scheme",
        markdown_settings_segmented(
          [
            ("System", SetFollowSystemScheme(true), follow),
            ("Light", SetDarkMode(false), !follow && !self.dark_mode_enabled),
            ("Dark", SetDarkMode(true), !follow && self.dark_mode_enabled),
          ],
          theme,
          tokens,
          metrics,
          width=72.0,
        ),
        theme,
        tokens,
      )
      let look_row = markdown_settings_row(
        "Page look",
        "Paper, warm or wide writing surface",
        markdown_settings_segmented(
          [
            (
              "Paper",
              SetWritingAppearance("Paper"),
              self.appearance_label() == "Paper",
            ),
            (
              "Warm",
              SetWritingAppearance("Warm"),
              self.appearance_label() == "Warm",
            ),
            (
              "Wide",
              SetWritingAppearance("Wide"),
              self.appearance_label() == "Wide",
            ),
          ],
          theme,
          tokens,
          metrics,
          width=72.0,
        ),
        theme,
        tokens,
      )
      let font_row = markdown_settings_row(
        "Font",
        "Body font family",
        markdown_settings_segmented(
          [
            ("Sans", SetFontFamily(SansFont), self.font_family is SansFont),
            ("Serif", SetFontFamily(SerifFont), self.font_family is SerifFont),
            ("Mono", SetFontFamily(MonoFont), self.font_family is MonoFont),
          ],
          theme,
          tokens,
          metrics,
          width=72.0,
        ),
        theme,
        tokens,
      )
      let layout_row = markdown_settings_row(
        "Layout",
        "Persistent sidebar or floating panels",
        markdown_settings_segmented(
          [
            (
              "Workspace",
              SetLayoutMode(WorkspaceMode),
              self.layout_mode is WorkspaceMode,
            ),
            (
              "Minimal",
              SetLayoutMode(MinimalMode),
              self.layout_mode is MinimalMode,
            ),
          ],
          theme,
          tokens,
          metrics,
          width=96.0,
        ),
        theme,
        tokens,
      )
      body.push(
        markdown_settings_group(
          [mode_row, look_row, font_row, layout_row],
          tokens,
        ),
      )
    }
  }
  let header = @views.row(
    [
      text(title, width=320.0, height=30.0)
      .font(theme.typography.title)
      .foreground(tokens.text),
      @views.spacer(min_length=0.0, weight=1.0),
      tooltip(
        button(
          "",
          on_click=CloseSettings,
          variant=@views.ButtonVariant::Ghost,
          icon=Some(@views.IconName::Close),
          width=28.0,
          height=28.0,
        ),
        "Close settings",
      ),
    ],
    spacing=8.0,
    align=@views.CrossAlign::Center,
  )
  let content = @views.padding_edges(
    @views.column(
      [
        header,
        @views.column(body, spacing=12.0, align=@views.CrossAlign::Stretch),
      ],
      spacing=16.0,
      align=@views.CrossAlign::Stretch,
    ),
    top=18.0,
    right=20.0,
    bottom=18.0,
    left=20.0,
  )
  @views.container(
    @views.row(
      [nav_card, @views.frame(content, width=580.0, height=540.0)],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    width=780.0,
    height=540.0,
    variant=@views.ContainerVariant::Overlay,
    background=tokens.card,
    border=Some(
      @core.BorderStyle::new(
        brush=@graphics.Brush::solid(tokens.page_border),
        width=1.0,
      ),
    ),
    corner_radius=metrics.island_radius,
    padding=0.0,
  ).shadow(theme.shadow_scale.lg)
}

///|
/// Pin a floating bar/card below the top bar and center it horizontally
/// without letting its intrinsic size push the shell layout. Stack children
/// are stretched to the window, so a column with a fixed top spacer, a
/// centering row, and a flex bottom spacer is an exact overlay.
fn markdown_top_overlay(
  child : @moui.View[MarkdownEditorMsg],
  top~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  @views.column(
    [
      @views.spacer(min_length=top, weight=0.0),
      @views.row(
        [
          @views.spacer(min_length=0.0, weight=1.0),
          child,
          @views.spacer(min_length=0.0, weight=1.0),
        ],
        spacing=0.0,
        align=@views.CrossAlign::Center,
      ),
      @views.spacer(min_length=0.0, weight=1.0),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Stretch,
  )
}
