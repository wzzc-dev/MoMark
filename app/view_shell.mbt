///|
///|
/// A shell icon button with a tooltip and a 28-ish hit area. The top bar uses
/// one idiom for every action so the right cluster reads as a group.
fn markdown_shell_icon_button(
  icon : @views.IconName,
  label : String,
  message : MarkdownEditorMsg,
  _tokens : MarkdownUiTokens,
  metrics : MarkdownShellMetrics,
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
      width=metrics.control_height,
      height=metrics.control_height,
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
  metrics : MarkdownShellMetrics,
  active~ : Bool = false,
) -> @moui.View[MarkdownEditorMsg] {
  let segment = tooltip(
    button(
      "",
      on_click=message,
      variant=@views.ButtonVariant::Ghost,
      icon=Some(icon),
      width=metrics.control_height,
      height=metrics.control_height,
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
/// The shared top bar for both shells. The workspace variant is 40px tall and
/// the minimal one 32px; both keep the traffic-light inset, a sidebar toggle,
/// a centered-ish document title, and the action cluster inset from the
/// window edge by `island_margin + bar_inset`.
fn MarkdownEditorApp::markdown_shell_top_bar(
  self : MarkdownEditorApp,
  tokens : MarkdownUiTokens,
  metrics : MarkdownShellMetrics,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let title = markdown_editor_document_title(
    path=self.document_path,
    fallback="Untitled",
  )
  let unsaved = if self.is_dirty() {
    text("•", width=10.0, height=20.0)
    .font(theme.typography.caption)
    .foreground(tokens.dirty_dot)
  } else {
    empty()
  }
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
          metrics,
          active=files_active,
        ),
        markdown_shell_segment(
          @views.IconName::ListBullet,
          "Outline",
          SetSidebarPanel(OutlinePanel),
          tokens,
          metrics,
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
    tokens,
    metrics,
    active=self.sidebar_visible(),
  )
  let left_width = markdown_editor_max_double(180.0, metrics.sidebar_width)
  let left_cluster = @views.frame(
    @views.row(
      [
        spacer(min_length=78.0, weight=0.0),
        sidebar_toggle,
        spacer(min_length=6.0, weight=0.0),
        segmented,
        spacer(min_length=0.0, weight=1.0),
      ],
      spacing=0.0,
      align=@views.CrossAlign::Center,
    ),
    width=left_width,
  )
  let close_tab = tooltip(
    button(
      "",
      on_click=NewDocument,
      variant=@views.ButtonVariant::Ghost,
      icon=Some(@views.IconName::Close),
      width=20.0,
      height=20.0,
    ),
    "Close tab",
  )
  let tab = @views.container(
    @views.padding_edges(
      @views.row(
        [
          @views.icon(
            @views.IconName::FileMarkdown,
            size=14.0,
            color=tokens.accent,
          ),
          button(
            title,
            on_click=ToggleDocumentInfo,
            variant=@views.ButtonVariant::Ghost,
            width=150.0,
            height=20.0,
            label_align=@text.TextAlign::TextStart,
          )
          .font(theme.typography.caption)
          .foreground(tokens.text),
          unsaved,
          close_tab,
        ],
        spacing=6.0,
        align=@views.CrossAlign::Center,
      ),
      top=2.0,
      right=6.0,
      bottom=2.0,
      left=10.0,
    ),
    variant=@views.ContainerVariant::Base,
    background=tokens.hover,
    border=Some(
      @core.BorderStyle::new(
        brush=@graphics.Brush::solid(tokens.page_border),
        width=1.0,
      ),
    ),
    corner_radius=8.0,
    padding=0.0,
  )
  let new_tab = markdown_shell_icon_button(
    @views.IconName::FileNew,
    "New document",
    NewDocument,
    tokens,
    metrics,
  )
  let actions = row(
    [
      markdown_shell_icon_button(
        @views.IconName::Search,
        "Find",
        ToggleFind,
        tokens,
        metrics,
        active=self.find_visible,
      ),
      markdown_shell_icon_button(
        @views.IconName::Heading,
        "Quick Format",
        ToggleFormatPalette,
        tokens,
        metrics,
        active=self.format_palette_visible,
      ),
      markdown_shell_icon_button(
        @views.IconName::Settings,
        "Settings",
        OpenSettings,
        tokens,
        metrics,
        active=self.settings_visible,
      ),
    ],
    spacing=2.0,
    align=@views.CrossAlign::Center,
  )
  frame(
    row(
      [
        left_cluster,
        spacer(min_length=6.0, weight=0.0),
        tab,
        new_tab,
        spacer(min_length=0.0, weight=1.0),
        actions,
        spacer(min_length=metrics.bar_inset, weight=0.0),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Center,
    ),
    height=metrics.top_bar_height,
  ).background(tokens.frame).repaint_boundary()
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
  let context = markdown_editor_session_status_label(
    self.block_label, session, selection,
  )
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
  let right_text = saved + " · " + context
  frame(
    row(
      [
        spacer(min_length=metrics.bar_inset, weight=0.0),
        text(breadcrumb, width=left_width, height=metrics.status_bar_height)
        .font(theme.typography.caption)
        .foreground(tokens.text_muted),
        spacer(min_length=0.0, weight=1.0),
        text(right_text, width=right_width, height=metrics.status_bar_height)
        .font(theme.typography.caption)
        .foreground(tokens.text_muted),
        spacer(min_length=metrics.bar_inset, weight=0.0),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    height=metrics.status_bar_height,
  ).background(tokens.frame).repaint_boundary()
}

///|
/// A compact choice chip used by the settings sheet. Active choices use the
/// tonal fill; inactive ones stay ghost so the current value reads at a glance.
fn markdown_shell_choice(
  label : String,
  active : Bool,
  message : MarkdownEditorMsg,
  metrics : MarkdownShellMetrics,
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
    width~,
    height=metrics.control_height,
  )
}

///|
/// Settings skeleton: shell layout, color scheme, and the existing writing
/// look. The full Appearance/Editor/Files/Shortcuts sheets build on this in
/// M2; keeping the message plumbing here means those pages only add rows.
fn MarkdownEditorApp::markdown_settings_panel(
  self : MarkdownEditorApp,
  tokens : MarkdownUiTokens,
  metrics : MarkdownShellMetrics,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let layout_row = row(
    [
      text("Layout", width=96.0, height=metrics.control_height)
      .font(theme.typography.caption)
      .foreground(tokens.text_muted),
      markdown_shell_choice(
        "Workspace",
        self.layout_mode is WorkspaceMode,
        SetLayoutMode(WorkspaceMode),
        metrics,
      ),
      markdown_shell_choice(
        "Minimal",
        self.layout_mode is MinimalMode,
        SetLayoutMode(MinimalMode),
        metrics,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
  let scheme_row = row(
    [
      text("Appearance", width=96.0, height=metrics.control_height)
      .font(theme.typography.caption)
      .foreground(tokens.text_muted),
      markdown_shell_choice(
        "Light",
        !self.dark_mode_enabled && !self.follow_system_scheme,
        SetDarkMode(false),
        metrics,
      ),
      markdown_shell_choice(
        "Dark",
        self.dark_mode_enabled && !self.follow_system_scheme,
        SetDarkMode(true),
        metrics,
      ),
      markdown_shell_choice(
        "System",
        self.follow_system_scheme,
        SetFollowSystemScheme(true),
        metrics,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
  let look_row = row(
    [
      text("Page look", width=96.0, height=metrics.control_height)
      .font(theme.typography.caption)
      .foreground(tokens.text_muted),
      markdown_shell_choice(
        "Paper",
        self.appearance_label() == "Paper",
        SetWritingAppearance("Paper"),
        metrics,
      ),
      markdown_shell_choice(
        "Warm",
        self.appearance_label() == "Warm",
        SetWritingAppearance("Warm"),
        metrics,
      ),
      markdown_shell_choice(
        "Wide",
        self.appearance_label() == "Wide",
        SetWritingAppearance("Wide"),
        metrics,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
  let font_row = row(
    [
      text("Font", width=96.0, height=metrics.control_height)
      .font(theme.typography.caption)
      .foreground(tokens.text_muted),
      markdown_shell_choice(
        "Sans",
        self.font_family is SansFont,
        SetFontFamily(SansFont),
        metrics,
      ),
      markdown_shell_choice(
        "Serif",
        self.font_family is SerifFont,
        SetFontFamily(SerifFont),
        metrics,
      ),
      markdown_shell_choice(
        "Mono",
        self.font_family is MonoFont,
        SetFontFamily(MonoFont),
        metrics,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
  let sidebar_row = row(
    [
      text("Sidebar", width=96.0, height=metrics.control_height)
      .font(theme.typography.caption)
      .foreground(tokens.text_muted),
      markdown_shell_choice(
        "Files",
        self.sidebar_panel is FilesPanel && self.file_sidebar_visible,
        SetSidebarPanel(FilesPanel),
        metrics,
      ),
      markdown_shell_choice(
        "Outline",
        self.sidebar_panel is OutlinePanel && self.outline_visible,
        SetSidebarPanel(OutlinePanel),
        metrics,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
  let body = column(
    [
      row(
        [
          text("Settings", width=300.0, height=30.0)
          .font(theme.typography.title)
          .foreground(tokens.text),
          spacer(min_length=0.0, weight=1.0),
          button(
            "Done",
            on_click=CloseSettings,
            variant=@views.ButtonVariant::Ghost,
            width=72.0,
            height=28.0,
          ),
        ],
        spacing=0.0,
        align=@views.CrossAlign::Center,
      ),
      layout_row,
      scheme_row,
      look_row,
      font_row,
      sidebar_row,
    ],
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Start,
  )
  container(
    padding_edges(
      body,
      top=theme.spacing_scale.lg,
      right=theme.spacing_scale.lg,
      bottom=theme.spacing_scale.lg,
      left=theme.spacing_scale.lg,
    ),
    width=560.0,
    height=360.0,
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
