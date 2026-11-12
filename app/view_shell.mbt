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
    text("•", width=10.0, height=metrics.control_height)
    .font(theme.typography.caption)
    .foreground(tokens.dirty_dot)
  } else {
    empty()
  }
  let title_button = button(
      title,
      on_click=ToggleDocumentInfo,
      variant=@views.ButtonVariant::Ghost,
      height=metrics.control_height,
    )
    .font(theme.typography.caption)
    .foreground(tokens.text)
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
        spacer(min_length=78.0, weight=0.0),
        markdown_shell_icon_button(
          @views.IconName::Sidebar,
          "Toggle sidebar",
          ToggleFileSidebar,
          tokens,
          metrics,
          active=self.sidebar_visible(),
        ),
        spacer(min_length=4.0, weight=0.0),
        title_button,
        unsaved,
        spacer(min_length=0.0, weight=1.0),
        actions,
        spacer(min_length=metrics.bar_inset, weight=0.0),
      ],
      spacing=0.0,
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
  let left_width = 220.0
  let center_width = 90.0
  let right_width = markdown_editor_max_double(
    180.0,
    viewport_width - left_width - center_width - 260.0,
  )
  frame(
    row(
      [
        spacer(min_length=metrics.bar_inset, weight=0.0),
        text(title, width=left_width, height=metrics.status_bar_height)
        .font(theme.typography.caption)
        .foreground(tokens.text_muted),
        spacer(min_length=0.0, weight=1.0),
        text(saved, width=center_width, height=metrics.status_bar_height)
        .font(theme.typography.caption)
        .foreground(if self.is_dirty() {
          tokens.dirty_dot
        } else {
          tokens.text_muted
        }),
        spacer(min_length=0.0, weight=1.0),
        text(context, width=right_width, height=metrics.status_bar_height)
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
        self.appearance_label(),
        false,
        CycleWritingAppearance,
        metrics,
        width=132.0,
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
    height=260.0,
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
