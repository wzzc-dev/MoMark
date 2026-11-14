///|
using @views {fill_rect, draw_text}

///|
fn MarkdownEditorApp::target_bar(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let kind = self.target_kind
  let block_label = self.block_label
  let block_badge = text("Block: " + block_label, width=132.0, height=34.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.muted)
  match kind {
    LinkTarget =>
      row(
        [
          block_badge,
          text("Link target", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field(
            self.link_target,
            on_input=value => UpdateLinkTarget(value),
            on_submit=Some(ApplyLinkTarget),
            placeholder="https://example.com",
            variant=@views.TextFieldVariant::Outline,
            width=360.0,
            height=34.0,
          ).key("markdown-link-target"),
          editor_button("Apply", ApplyLinkTarget, @views.ButtonVariant::Tonal),
          editor_button("Open", OpenTarget, @views.ButtonVariant::Ghost),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    ImageTarget =>
      row(
        [
          block_badge,
          text("Image src", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field(
            self.image_target,
            on_input=value => UpdateImageTarget(value),
            on_submit=Some(ApplyImageTarget),
            placeholder="assets/image.png",
            variant=@views.TextFieldVariant::Outline,
            width=360.0,
            height=34.0,
          ).key("markdown-image-target"),
          editor_button("Apply", ApplyImageTarget, @views.ButtonVariant::Tonal),
          editor_button("Open", OpenTarget, @views.ButtonVariant::Ghost),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    FootnoteTarget =>
      row(
        [
          block_badge,
          text("Footnote", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field(
            self.footnote_text,
            on_input=value => UpdateFootnoteText(value),
            on_submit=Some(ApplyFootnoteText),
            placeholder="Footnote text",
            variant=@views.TextFieldVariant::Outline,
            width=360.0,
            height=34.0,
          ).key("markdown-footnote-text"),
          editor_button("Apply", ApplyFootnoteText, @views.ButtonVariant::Tonal),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    HtmlBlockTarget =>
      row(
        [
          block_badge,
          text("HTML block", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field(
            self.html_block_text,
            on_input=value => UpdateHtmlBlockText(value),
            on_submit=Some(ApplyHtmlBlockText),
            placeholder="<div>HTML</div>",
            variant=@views.TextFieldVariant::Outline,
            width=360.0,
            height=34.0,
          ).key("markdown-html-block-text"),
          editor_button(
            "Apply",
            ApplyHtmlBlockText,
            @views.ButtonVariant::Tonal,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    TableTools =>
      row(
        [
          block_badge,
          text("Table tools", width=92.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          editor_button(
            "+Row",
            ApplyCommand(InsertTableRow),
            @views.ButtonVariant::Tonal,
          ),
          editor_button(
            "+Col",
            ApplyCommand(InsertTableColumn),
            @views.ButtonVariant::Tonal,
          ),
          editor_button(
            "-Col",
            ApplyCommand(DeleteTableColumn),
            @views.ButtonVariant::Tonal,
          ),
          editor_button(
            "-Row",
            ApplyCommand(DeleteTableRow),
            @views.ButtonVariant::Tonal,
          ),
          editor_button(
            "Left",
            ApplyCommand(
              MarkdownEditorCommand::SetTableColumnAlignment(
                Some(@text.TextAlign::TextStart),
              ),
            ),
            @views.ButtonVariant::Tonal,
          ),
          editor_button(
            "Center",
            ApplyCommand(
              MarkdownEditorCommand::SetTableColumnAlignment(
                Some(@text.TextAlign::TextCenter),
              ),
            ),
            @views.ButtonVariant::Tonal,
          ),
          editor_button(
            "Right",
            ApplyCommand(
              MarkdownEditorCommand::SetTableColumnAlignment(
                Some(@text.TextAlign::TextEnd),
              ),
            ),
            @views.ButtonVariant::Tonal,
          ),
          editor_button(
            "Auto",
            ApplyCommand(SetTableColumnAlignment(None)),
            @views.ButtonVariant::Tonal,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    PlainSelection => empty()
  }
}

///|
fn markdown_editor_session_caret_rect(
  session : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  caret : Int32,
  editor_frame : @geometry.Rect,
  editor_font : @text.FontSpec,
  scroll_offset : @geometry.Point,
  viewport_height~ : Double,
  source_mode~ : Bool = false,
  focus_mode~ : Bool = false,
  base_dir~ : String? = None,
) -> @geometry.Rect? {
  let window = session.rich_text_window(
    selection,
    base=editor_font,
    source_mode~,
    focus_mode~,
    base_dir~,
    scroll_y=scroll_offset.y,
    viewport_height~,
    overscan=markdown_editor_visible_overscan(viewport_height),
    content_width=@moui_richtext.rich_text_editor_content_rect(editor_frame).size.width,
  )
  let content = @moui_richtext.rich_text_editor_content_rect(editor_frame).offset(
    dx=0.0,
    dy=window.top_padding - scroll_offset.y,
  )
  @moui_richtext.rich_text_document_caret_rect_at_source(
    window.document,
    caret,
    content,
    editor_font,
  )
}

///|
fn editor_button(
  label : String,
  message : MarkdownEditorMsg,
  variant : @views.ButtonVariant,
) -> @moui.View[MarkdownEditorMsg] {
  let width = if markdown_editor_text_length(label) > 5 { 78.0 } else { 64.0 }
  button(label, on_click=message, variant~, width~, height=34.0)
}

///|
/// A compact ghost icon button for the find bar (prev/next/close), with a
/// tooltip describing the action.
fn editor_find_icon_button(
  icon : @views.IconName,
  tooltip_label : String,
  message : MarkdownEditorMsg,
) -> @moui.View[MarkdownEditorMsg] {
  tooltip(
    button(
      "",
      on_click=message,
      variant=@views.ButtonVariant::Ghost,
      icon=Some(icon),
      width=34.0,
      height=34.0,
    ),
    tooltip_label,
  )
}

///|
/// A compact toggle chip for find/replace options. Renders as a small ghost
/// button that switches to Tonal when active, with a tooltip describing the
/// option.
fn editor_find_toggle(
  glyph : String,
  tooltip_label : String,
  message : MarkdownEditorMsg,
  active : Bool,
) -> @moui.View[MarkdownEditorMsg] {
  let variant = if active {
    @views.ButtonVariant::Tonal
  } else {
    @views.ButtonVariant::Ghost
  }
  tooltip(
    button(glyph, on_click=message, variant~, width=34.0, height=34.0),
    tooltip_label,
  )
}

///|
fn MarkdownEditorApp::appearance_spec(
  self : MarkdownEditorApp,
  dark? : Bool,
) -> MarkdownEditorAppearanceSpec {
  let dark = match dark {
    Some(value) => value
    None => self.dark_mode_enabled
  }
  let base = self.writing_appearance.spec(dark~)
  {
    ..base,
    editor_font_size: base.editor_font_size * self.editor_zoom,
    font_family: markdown_editor_font_family_stack(self.font_family),
  }
}

///|
/// Map the user's font-family choice to a FontFamilyStack.
fn markdown_editor_font_family_stack(
  family : MarkdownEditorFontFamily,
) -> @text.FontFamilyStack {
  match family {
    SansFont => markdown_editor_typora_github_font_family_stack()
    SerifFont => @text.FontFamilyStack::serif()
    MonoFont => @text.FontFamilyStack::monospace()
  }
}

///|
/// Typora's default Github theme uses Open Sans first, then platform sans
/// fallbacks. Native Skia will use the first installed family in this stack.
fn markdown_editor_typora_github_font_family_stack() -> @text.FontFamilyStack {
  @text.FontFamilyStack::named("Open Sans")
  .with_fallback(@text.FontFamily::Name("Clear Sans"))
  .with_fallback(@text.FontFamily::Name("Helvetica Neue"))
  .with_fallback(@text.FontFamily::Name("Helvetica"))
  .with_fallback(@text.FontFamily::Name("Arial"))
  .with_fallback(@text.FontFamily::Name("Segoe UI Emoji"))
  .with_fallback(@text.FontFamily::Name("SF Pro"))
  .with_fallback(@text.FontFamily::SansSerif)
}

///|
fn MarkdownEditorApp::appearance_label(self : MarkdownEditorApp) -> String {
  self.appearance_spec().label
}

///|
fn MarkdownEditorAppearance::next(
  self : MarkdownEditorAppearance,
) -> MarkdownEditorAppearance {
  match self {
    PaperAppearance => WarmAppearance
    WarmAppearance => WideAppearance
    WideAppearance => PaperAppearance
  }
}

///|
fn MarkdownEditorAppearance::spec(
  self : MarkdownEditorAppearance,
  dark~ : Bool = false,
) -> MarkdownEditorAppearanceSpec {
  match self {
    PaperAppearance =>
      if dark {
        {
          label: "Paper",
          editor_font_size: 17.0,
          page_width: markdown_editor_page_width(),
          side_editor_width: markdown_editor_source_editor_width(),
          foreground: @graphics.Color::rgba(r=0.90, g=0.90, b=0.90),
          placeholder: @graphics.Color::white().multiply_alpha(0.32),
          page_background: @graphics.Color::rgba(r=0.13, g=0.14, b=0.16),
          font_family: @text.FontFamilyStack::sans_serif(),
        }
      } else {
        {
          label: "Paper",
          editor_font_size: 17.0,
          page_width: markdown_editor_page_width(),
          side_editor_width: markdown_editor_source_editor_width(),
          foreground: @graphics.Color::rgba(r=0.12, g=0.12, b=0.12),
          placeholder: @graphics.Color::black().multiply_alpha(0.35),
          page_background: @graphics.Color::white(),
          font_family: @text.FontFamilyStack::sans_serif(),
        }
      }
    WarmAppearance =>
      if dark {
        {
          label: "Warm",
          editor_font_size: 18.0,
          page_width: 724.0,
          side_editor_width: 604.0,
          foreground: @graphics.Color::rgba(r=0.92, g=0.88, b=0.80),
          placeholder: @graphics.Color::rgba(r=0.80, g=0.72, b=0.60, a=0.40),
          page_background: @graphics.Color::rgba(r=0.16, g=0.14, b=0.11),
          font_family: @text.FontFamilyStack::sans_serif(),
        }
      } else {
        {
          label: "Warm",
          editor_font_size: 18.0,
          page_width: 724.0,
          side_editor_width: 604.0,
          foreground: @graphics.Color::rgba(r=0.18, g=0.14, b=0.10),
          placeholder: @graphics.Color::rgba(r=0.38, g=0.28, b=0.18, a=0.46),
          page_background: @graphics.Color::rgba(r=1.0, g=0.984, b=0.936),
          font_family: @text.FontFamilyStack::sans_serif(),
        }
      }
    WideAppearance =>
      if dark {
        {
          label: "Wide",
          editor_font_size: 16.5,
          page_width: 920.0,
          side_editor_width: 720.0,
          foreground: @graphics.Color::rgba(r=0.86, g=0.90, b=0.94),
          placeholder: @graphics.Color::rgba(r=0.60, g=0.70, b=0.80, a=0.40),
          page_background: @graphics.Color::rgba(r=0.11, g=0.13, b=0.16),
          font_family: @text.FontFamilyStack::sans_serif(),
        }
      } else {
        {
          label: "Wide",
          editor_font_size: 16.5,
          page_width: 920.0,
          side_editor_width: 720.0,
          foreground: @graphics.Color::rgba(r=0.10, g=0.12, b=0.15),
          placeholder: @graphics.Color::rgba(r=0.16, g=0.20, b=0.26, a=0.36),
          page_background: @graphics.Color::rgba(r=0.986, g=0.990, b=0.994),
          font_family: @text.FontFamilyStack::sans_serif(),
        }
      }
  }
}

///|
fn markdown_editor_appearance_font(
  appearance : MarkdownEditorAppearanceSpec,
) -> @text.FontSpec {
  @text.FontSpec::new(
    size=appearance.editor_font_size,
    families=appearance.font_family,
  )
}

///|
fn markdown_editor_page_width() -> Double {
  780.0
}

///|
fn markdown_editor_primary_editor_width(
  show_source : Bool,
  show_outline : Bool,
  show_files : Bool,
  show_info : Bool,
  appearance : MarkdownEditorAppearanceSpec,
) -> Double {
  if show_source || show_outline || show_files || show_info {
    appearance.side_editor_width
  } else {
    appearance.page_width
  }
}

///|
fn markdown_editor_sidebar_total_width(
  show_source : Bool,
  show_outline : Bool,
  show_files : Bool,
  show_info : Bool,
  sidebar_width~ : Double = markdown_editor_file_sidebar_width(),
) -> Double {
  let mut width = 0.0
  // Files and outline share one left card; showing both puts the outline on
  // the right at its usual inspector width.
  if show_files || show_outline {
    width = width + sidebar_width
  }
  if show_files && show_outline {
    width = width + markdown_editor_outline_inspector_width()
  }
  if show_info {
    width = width + markdown_editor_info_inspector_width()
  }
  if show_source {
    width = width + markdown_editor_source_inspector_width()
  }
  width
}

///|
fn markdown_editor_primary_editor_width_for_viewport(
  show_source : Bool,
  show_outline : Bool,
  show_files : Bool,
  show_info : Bool,
  appearance : MarkdownEditorAppearanceSpec,
  viewport_width~ : Double,
  sidebar_width~ : Double = markdown_editor_file_sidebar_width(),
) -> Double {
  let preferred = markdown_editor_primary_editor_width(
    show_source, show_outline, show_files, show_info, appearance,
  )
  let sidebars_width = markdown_editor_sidebar_total_width(
    show_source,
    show_outline,
    show_files,
    show_info,
    sidebar_width~,
  )
  let available = markdown_editor_max_double(
    0.0,
    viewport_width - sidebars_width,
  )
  markdown_editor_min_double(preferred, available)
}

///|
fn markdown_editor_source_editor_width() -> Double {
  720.0
}

///|
fn markdown_editor_outline_inspector_width() -> Double {
  240.0
}

///|
fn markdown_editor_file_sidebar_width() -> Double {
  240.0
}

///|
fn markdown_editor_info_inspector_width() -> Double {
  240.0
}

///|
fn markdown_editor_outline_content_width() -> Double {
  212.0
}

///|
fn markdown_editor_file_sidebar_content_width() -> Double {
  212.0
}

///|
fn markdown_editor_info_content_width() -> Double {
  212.0
}

///|
fn markdown_editor_source_inspector_width() -> Double {
  292.0
}

///|
fn markdown_editor_viewport_height() -> Double {
  520.0
}

///|
fn markdown_editor_min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn markdown_editor_max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn markdown_editor_visible_overscan(viewport_height : Double) -> Double {
  markdown_editor_min_double(320.0, viewport_height * 0.5)
}

///|
fn markdown_editor_clamp_double(
  value : Double,
  min : Double,
  max : Double,
) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn editor_source_layout(
  app : MarkdownEditorApp,
  session : MarkdownDocumentSession,
  editor_font : @text.FontSpec,
  appearance : MarkdownEditorAppearanceSpec,
  theme : @moui.Theme,
  show_source : Bool,
  show_outline : Bool,
  show_files : Bool,
  show_info : Bool,
  target_bar : @moui.View[MarkdownEditorMsg],
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  scroll_request : @core.ScrollRequest?,
  on_selection_change : (Int32, @text.TextRange?) -> MarkdownEditorMsg,
  on_prefix_click : (Int32) -> MarkdownEditorMsg,
  viewport_width~ : Double = 1120.0,
  viewport_height~ : Double = 520.0,
  card_gap~ : Double = 0.0,
  sidebar_width~ : Double = markdown_editor_file_sidebar_width(),
  sidebar_anim~ : Double = 1.0,
  sidebar_header~ : @moui.View[MarkdownEditorMsg] = @views.empty(),
  sidebar_header_height~ : Double = 0.0,
  tab_leading~ : Array[@moui.View[MarkdownEditorMsg]] = [],
  tab_leading_width~ : Double = 0.0,
  tab_left_inset~ : Double = 8.0,
  page_radius~ : Double = 4.0,
) -> @moui.View[MarkdownEditorMsg] {
  let tab_height = if app.zen_mode_enabled {
    0.0
  } else {
    markdown_editor_tab_strip_height()
  }
  let body_height = markdown_editor_max_double(
    0.0,
    viewport_height - tab_height,
  )
  // The editor surface fills the card below the tab strip. The rich-text
  // surface owns its small content inset, so adding page padding here would
  // instead create fixed, non-interactive bands above and below the viewport.
  let editor_height = body_height
  let animated_sidebar_width = sidebar_width * sidebar_anim
  let sidebars_width = markdown_editor_sidebar_total_width(
    show_source,
    show_outline,
    show_files,
    show_info,
    sidebar_width=animated_sidebar_width,
  )
  let mut card_gaps = 0
  if show_files {
    card_gaps = card_gaps + 1
  }
  if show_info {
    card_gaps = card_gaps + 1
  }

  if show_source {
    card_gaps = card_gaps + 1
  }
  let available_width = markdown_editor_max_double(
    0.0,
    viewport_width - sidebars_width - card_gaps.to_double() * card_gap,
  )
  // The card always fills the space next to the sidebars (Winc's editor pane);
  // `page_width` only caps the document measure, which stays centered inside.
  let card_width = available_width
  let editor_width = markdown_editor_min_double(
    appearance.page_width,
    available_width,
  )
  let source_mode = app.source_mode_enabled
  let content_height = markdown_editor_max_double(
    editor_height,
    session.estimated_content_height(
      base=editor_font,
      source_mode~,
      content_width=markdown_editor_max_double(0.0, editor_width - 28.0),
    ) +
    96.0,
  )
  let page_brush = @graphics.Brush::solid(appearance.page_background)
  let editor_style : @views.TextFieldStyle = @views.TextFieldStyle::new(
    normal=@views.new_control_state_style(
      foreground=appearance.foreground,
      background=page_brush,
      radius=theme.radius_scale.md,
    ),
    focused=@views.new_control_state_style(
      foreground=appearance.foreground,
      background=page_brush,
      radius=theme.radius_scale.md,
    ),
    disabled=@views.new_control_state_style(
      foreground=appearance.foreground,
      background=page_brush,
      radius=theme.radius_scale.md,
    ),
    placeholder_color=appearance.placeholder,
    cursor_color=theme.palette.primary,
    font=editor_font,
  )
  let cursor_color = if app.caret_blink_visible {
    editor_style.cursor_color()
  } else {
    editor_style.cursor_color().with_alpha(0.0)
  }
  let editor_control = controlled_markdown_session_editor(
      session~,
      selection~,
      on_transaction=transaction => ApplyEditorTransaction(transaction),
      placeholder="Start writing Markdown",
      size=@geometry.Size::new(width=editor_width, height=editor_height),
      font=editor_style.font(),
      foreground=appearance.foreground,
      placeholder_color=editor_style.placeholder_color(),
      background=page_brush,
      border=None,
      focused_border=None,
      cursor_color~,
      corner_radius=page_radius,
      source_mode~,
      focus_mode=app.focus_mode_enabled,
      base_dir=markdown_editor_document_base_dir(app.document_path),
      on_selection_change=Some(on_selection_change),
      on_prefix_click=Some(on_prefix_click),
      on_command_click=Some(offset => CommandClickAt(offset)),
      accepts_tab_input=true,
      scroll_request~,
      scroll_mode=Element(
        MarkdownScrollGlide::settled(0.0),
        Some(y => EditorScrollSettled(y)),
      ),
      visible_viewport_height=editor_height,
      visible_overscan=markdown_editor_visible_overscan(editor_height),
    )
    // The document surface owns its own menu (clipboard, formatting, document
    // actions); the root view keeps a broader menu for the surrounding chrome.
    // Attached below the key so the keyed identity stays unique for focus and
    // scroll lookups.
    .on_secondary_tap(
      ContextMenuTargeted(MarkdownEditorContextTarget::EditorSurface),
    )
    .key("markdown-editor")
  let tab_strip = if tab_height <= 0.0 {
    empty()
  } else {
    markdown_editor_tab_strip(
      app,
      theme,
      width=card_width,
      height=tab_height,
      leading=tab_leading,
      leading_width=tab_leading_width,
      left_inset=tab_left_inset,
    )
  }
  let centered_editor = @views.row(
    [
      @views.spacer(min_length=0.0, weight=1.0),
      editor_control,
      @views.spacer(min_length=0.0, weight=1.0),
    ],
    spacing=0.0,
    align=@views.CrossAlign::Center,
  )
  let editor = editor_page(
    centered_editor,
    tab_strip~,
    background=appearance.page_background,
    border_color=theme.palette.outline,
    page_radius~,
    width=card_width,
    height=viewport_height,
  ).on_file_drop((paths, _position) => {
    match paths {
      [path, ..] if path != "" => InsertMediaFromFileDrop(path)
      _ => DismissAuxiliaryPanels
    }
  })
  // Temporarily disabled: floating block-target palette (the "Block: ..." /
  // Apply overlay). Uncomment the if/else below and drop the direct binding
  // to re-enable it.
  // let editor_view = if !show_source && !app.source_mode_enabled {
  //   floating_target_palette(
  //     editor, target_bar, session, selection, target_kind, editor_font, theme,
  //     normalized_offset, editor_width, viewport_height,
  //   )
  // } else {
  //   editor
  // }
  let editor_view = editor

  let side_children : Array[@moui.View[MarkdownEditorMsg]] = []
  if show_files {
    side_children.push(
      files_inspector(
        app,
        session,
        selection,
        theme,
        height=viewport_height,
        width=animated_sidebar_width,
        header=sidebar_header,
        header_height=sidebar_header_height,
        outline_expanded=app.outline_visible,
      )
      .clip()
      .opacity(sidebar_anim),
    )
    // Drag the gap between the cards to resize the sidebar. The pointer x is
    // mapped back to a width relative to the card's left edge, so the handle
    // keeps following the pointer even as the card re-lays out.
    if card_gap > 0.0 {
      side_children.push(
        @views.canvas(
          measure=_ctx => {
            @core.Size::new(width=card_gap, height=viewport_height)
          },
          draw=(_ctx, _frame) => (),
          semantics_label="Resize sidebar",
        ).on_drag_with_frame((event, frame) => {
          let base = frame.origin.x - animated_sidebar_width
          SetSidebarWidth(event.position.x - base - card_gap * 0.5)
        }),
      )
    } else {
      side_children.push(spacer(min_length=card_gap, weight=0.0))
    }
  }
  side_children.push(spacer(min_length=0.0, weight=1.0))
  side_children.push(editor_view)
  side_children.push(spacer(min_length=0.0, weight=1.0))
  if show_info {
    side_children.push(spacer(min_length=card_gap, weight=0.0))
    side_children.push(
      document_info_inspector(session, theme, height=viewport_height),
    )
  }
  if show_source {
    side_children.push(spacer(min_length=card_gap, weight=0.0))
    side_children.push(
      source_inspector(session.source(), theme, height=viewport_height),
    )
  }
  // The scroll indicator is stacked over the FULL-width row (not the
  // centered editor column), so its track pins to the right edge of the
  // window rather than the right edge of the page column.
  // Temporarily disabled: selection-triggered format bubble (B/I/S/... toolbar).
  // markdown_editor_format_bubble_overlay(
  //   app, session, selection, editor_font, theme, normalized_offset, editor_width,
  //   viewport_height,
  // )
  let editor_and_sidebars = @views.stack([
    row(side_children, spacing=0.0, align=@views.CrossAlign::Stretch).frame(
      width=viewport_width,
    ),
    @views.align(
      markdown_editor_scroll_indicator(
        MarkdownScrollGlide::settled(app.editor_scroll_settled_y),
        viewport_height=editor_height,
        content_height~,
        theme,
      ),
      alignment=@geometry.Alignment::new(x=1.0, y=0.0),
    ),
  ])
  column(
    if target_kind == PlainSelection || !show_source {
      [editor_and_sidebars]
    } else {
      [editor_and_sidebars, target_bar]
    },
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Stretch,
  )
}

///|

///|
fn markdown_editor_tab_strip_height() -> Double {
  32.0
}

///|
/// Approximate intrinsic width of a tab title, clamped so short names do not
/// leave a wide empty pill and long paths stop growing before they crowd the
/// strip's right actions.
fn markdown_editor_tab_title_width(title : String) -> Double {
  let width = markdown_editor_text_length(title).to_double() * 7.2 + 8.0
  markdown_editor_clamp_double(width, 96.0, 160.0)
}

///|
/// Total width of the tab pill: padding, file icon, title button, dirty dot,
/// close button, and the row spacing between them.
fn markdown_editor_tab_pill_width(title : String, dirty : Bool) -> Double {
  let dot = if dirty { 10.0 } else { 0.0 }
  68.0 + markdown_editor_tab_title_width(title) + dot
}

///|
/// One compact action on the tab strip's right edge. Active views use the
/// tonal fill so the current source/preview state reads at a glance.
fn markdown_editor_tab_action(
  icon : @views.IconName,
  label : String,
  message : MarkdownEditorMsg,
  theme : @moui.Theme,
  active : Bool,
) -> @moui.View[MarkdownEditorMsg] {
  tooltip(
    button(
      "",
      on_click=message,
      variant=if active {
        @views.ButtonVariant::Tonal
      } else {
        @views.ButtonVariant::Ghost
      },
      icon=Some(icon),
      theme=markdown_shell_compact_theme(theme),
      width=22.0,
      height=22.0,
    ),
    label,
  )
}

///|
/// The tab strip inside the editor card: one document tab with its file icon,
/// dirty dot, and close affordance, plus new-tab and view actions. Together
/// with the sidebar card's header it forms the single 32px chrome band; in the
/// minimal shell, which has no persistent sidebar, the sidebar controls ride
/// along at the strip's left edge (`leading` + a traffic-light `left_inset`).
fn markdown_editor_tab_strip(
  app : MarkdownEditorApp,
  theme : @moui.Theme,
  width~ : Double,
  height~ : Double,
  leading~ : Array[@moui.View[MarkdownEditorMsg]] = [],
  leading_width~ : Double = 0.0,
  left_inset~ : Double = 8.0,
) -> @moui.View[MarkdownEditorMsg] {
  let title = markdown_editor_document_title(
    path=app.document_path,
    fallback="Untitled",
  )
  let unsaved = if app.is_dirty() {
    text("•", width=10.0, height=16.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.primary)
  } else {
    empty()
  }
  let close_tab = tooltip(
    button(
      "",
      on_click=NewDocument,
      variant=@views.ButtonVariant::Ghost,
      icon=Some(@views.IconName::Close),
      theme=markdown_shell_compact_theme(theme),
      width=20.0,
      height=20.0,
    ),
    "Close tab",
  )
  let tab = container(
    padding_edges(
      row(
        [
          @views.icon(
            @views.IconName::FileMarkdown,
            size=14.0,
            color=theme.palette.primary,
          ),
          button(
            title,
            on_click=ToggleDocumentInfo,
            variant=@views.ButtonVariant::Ghost,
            theme=markdown_shell_compact_theme(theme),
            width=markdown_editor_tab_title_width(title),
            height=20.0,
            label_align=@text.TextAlign::TextStart,
          )
          .font(theme.typography.caption)
          .foreground(theme.palette.foreground),
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
    background=theme.palette.primary_container,
    border=Some(
      @core.BorderStyle::new(
        brush=@graphics.Brush::solid(theme.palette.outline),
        width=1.0,
      ),
    ),
    corner_radius=7.0,
    padding=0.0,
  )
  let new_tab = tooltip(
    button(
      "",
      on_click=NewDocument,
      variant=@views.ButtonVariant::Ghost,
      icon=Some(@views.IconName::FileNew),
      theme=markdown_shell_compact_theme(theme),
      width=22.0,
      height=22.0,
    ),
    "New document",
  )
  let view_actions = row(
    [
      markdown_editor_tab_action(
        @views.IconName::Search,
        "Find",
        ToggleFind,
        theme,
        app.find_visible,
      ),
      markdown_editor_tab_action(
        @views.IconName::FileCode,
        "Source mode",
        ToggleSourceMode,
        theme,
        app.source_mode_enabled,
      ),
      markdown_editor_tab_action(
        @views.IconName::Columns,
        "Source preview",
        ToggleSourcePreview,
        theme,
        app.source_preview_visible,
      ),
    ],
    spacing=2.0,
    align=@views.CrossAlign::Center,
  )
  let strip_children : Array[@moui.View[MarkdownEditorMsg]] = []
  for control in leading {
    strip_children.push(control)
  }
  if leading.length() > 0 {
    strip_children.push(spacer(min_length=8.0, weight=0.0))
  }
  strip_children.push(tab)
  strip_children.push(new_tab)
  let left_row = padding_edges(
    row(strip_children, spacing=4.0, align=@views.CrossAlign::Center),
    top=markdown_editor_max_double(0.0, (height - 24.0) / 2.0),
    bottom=markdown_editor_max_double(0.0, (height - 24.0) / 2.0),
    left=left_inset,
  )
  let left_layer = @views.align(
    left_row,
    alignment=@geometry.Alignment::new(x=-1.0, y=0.0),
  )
  // Absolute right inset: padding shifts the action row from the strip's left
  // edge by the remaining width, so it lands on the card edge regardless of
  // how the enclosing layout measures intrinsic widths.
  let right_layer = padding_edges(
    view_actions,
    left=markdown_editor_max_double(0.0, width - 8.0 - 70.0),
  )
  // One continuous card surface (no divider), and a stack instead of a row:
  // the stack hands its children the card's width, so the right-aligned
  // action cluster actually lands on the card's edge.
  // The sizing layer stays transparent: the editor card paints its own
  // rounded background, and a rectangular strip background would cover the
  // card's top-left/top-right corner radius.
  @views.stack([frame(empty(), width~, height~), left_layer, right_layer])
}

///|
fn editor_page(
  editor : @moui.View[MarkdownEditorMsg],
  tab_strip~ : @moui.View[MarkdownEditorMsg],
  background~ : @graphics.Color,
  border_color~ : @graphics.Color,
  page_radius~ : Double = 4.0,
  width~ : Double,
  height~ : Double,
) -> @moui.View[MarkdownEditorMsg] {
  container(
    column([tab_strip, editor], spacing=0.0, align=@views.CrossAlign::Stretch),
    width~,
    height~,
    variant=@views.ContainerVariant::Base,
    background~,
    border=Some(
      @core.BorderStyle::new(
        brush=@graphics.Brush::solid(border_color),
        width=1.0,
      ),
    ),
    corner_radius=page_radius,
    padding=0.0,
  )
}

///|
fn source_preview_lines(
  text : String,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let font = @text.FontSpec::new(
    families=@text.FontFamilyStack::named("SFMono-Regular")
      .with_fallback(@text.FontFamily::UiMonospace)
      .with_fallback(@text.FontFamily::Monospace),
    size=12.0,
    weight=400,
  )
  let children : Array[@moui.View[MarkdownEditorMsg]] = []
  for line in markdown_split_lines(markdown_editor_preview_text(text)) {
    children.push(source_preview_line(line, font, theme.palette.foreground))
  }
  column(children, spacing=0.0, align=@views.CrossAlign::Start)
}

///|
fn source_preview_line(
  line : String,
  font : @text.FontSpec,
  color : @graphics.Color,
) -> @moui.View[MarkdownEditorMsg] {
  custom_layout(
    measure=_ => @geometry.Size::new(width=260.0, height=18.0),
    paint=(ctx, frame) => {
      draw_text(
        ctx,
        @text.TextRun::new(
          text=line,
          frame~,
          font~,
          color~,
          align=@text.TextAlign::TextStart,
        ),
      )
    },
    semantics_label=line,
  )
}

///|
