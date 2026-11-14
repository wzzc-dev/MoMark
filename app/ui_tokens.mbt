///|
/// The two shells MoMark ships.
///
/// `Workspace` is the Winc-like layout: a persistent sidebar, a denser top
/// bar, and island cards around the editor. `Minimal` keeps the Typora-style
/// single page: the sidebar and inspectors open as floating overlay cards.
#derive(Eq, Debug, ToJson)
pub enum MarkdownEditorLayoutMode {
  WorkspaceMode
  MinimalMode
}

///|
pub extend MarkdownEditorLayoutMode with Eq::{not_equal, equal}

///|
pub extend MarkdownEditorLayoutMode with Debug::{to_repr}

///|
pub extend MarkdownEditorLayoutMode with ToJson::{to_json}

///|
/// Which panel the persistent sidebar shows. The two panels share one card so
/// the workspace never grows two competing left columns.
#derive(Eq, Debug, ToJson)
pub enum MarkdownSidebarPanel {
  FilesPanel
  OutlinePanel
}

///|
pub extend MarkdownSidebarPanel with Eq::{not_equal, equal}

///|
pub extend MarkdownSidebarPanel with Debug::{to_repr}

///|
pub extend MarkdownSidebarPanel with ToJson::{to_json}

///|
/// One resolved set of surface/text/state colors for a light or dark window.
///
/// The values are deliberately semantic (frame/card/page/hover/selected), not
/// widget-specific: both shells and the settings sheet read the same tokens,
/// so a layout switch cannot drift the visual language. MoUI's `ColorPalette`
/// still covers built-in controls; the extra roles live here because the
/// framework palette has no hover/selected/current-line concepts.
pub struct MarkdownUiTokens {
  scheme : @core.ColorScheme
  /// Window frame behind the island cards.
  frame : @graphics.Color
  /// Sidebar and inspector cards.
  card : @graphics.Color
  /// The writing page.
  page : @graphics.Color
  page_border : @graphics.Color
  page_shadow : @graphics.ShadowStyle
  text : @graphics.Color
  text_muted : @graphics.Color
  text_dim : @graphics.Color
  accent : @graphics.Color
  accent_fill : @graphics.Color
  hover : @graphics.Color
  selected : @graphics.Color
  selected_inactive : @graphics.Color
  divider : @graphics.Color
  scrollbar : @graphics.Color
  scrollbar_active : @graphics.Color
  dirty_dot : @graphics.Color
  /// Colors baked into the markdown rich-text projection.
  rich_text : @moui_richtext.MarkdownRichTextPalette
}

///|
/// Island and bar dimensions for one shell.
///
/// `island_margin` is the window-edge inset, `island_gap` the space between
/// cards, and `bar_inset` the horizontal padding inside the top/status bars.
/// Controls never sit closer to the window edge than margin + inset.
pub struct MarkdownShellMetrics {
  layout_mode : MarkdownEditorLayoutMode
  island_margin : Double
  island_gap : Double
  island_radius : Double
  bar_inset : Double
  top_bar_height : Double
  status_bar_height : Double
  sidebar_width : Double
  sidebar_min_width : Double
  inspector_width : Double
  overlay_sidebar_width : Double
  overlay_inspector_width : Double
  page_width : Double
  side_page_width : Double
  tree_row_height : Double
  control_height : Double
}

///|
fn markdown_shell_metrics(
  layout_mode : MarkdownEditorLayoutMode,
  sidebar_width~ : Double = 300.0,
) -> MarkdownShellMetrics {
  match layout_mode {
    WorkspaceMode =>
      {
        layout_mode,
        island_margin: 4.0,
        island_gap: 6.0,
        island_radius: 10.0,
        bar_inset: 10.0,
        top_bar_height: 40.0,
        status_bar_height: 26.0,
        sidebar_width,
        sidebar_min_width: 230.0,
        inspector_width: 240.0,
        overlay_sidebar_width: 300.0,
        overlay_inspector_width: 240.0,
        page_width: markdown_editor_page_width(),
        side_page_width: markdown_editor_source_editor_width(),
        tree_row_height: 28.0,
        control_height: 28.0,
      }
    MinimalMode =>
      {
        layout_mode,
        island_margin: 4.0,
        island_gap: 0.0,
        island_radius: 10.0,
        bar_inset: 10.0,
        top_bar_height: 32.0,
        status_bar_height: 24.0,
        sidebar_width: 0.0,
        sidebar_min_width: 0.0,
        inspector_width: 0.0,
        overlay_sidebar_width: 280.0,
        overlay_inspector_width: 240.0,
        page_width: markdown_editor_page_width(),
        side_page_width: markdown_editor_source_editor_width(),
        tree_row_height: 28.0,
        control_height: 26.0,
      }
  }
}

///|
fn markdown_ui_tokens(
  scheme : @core.ColorScheme,
) -> MarkdownUiTokens {
  match scheme {
    Light =>
      {
        scheme,
        frame: @graphics.Color::rgba(r=0.949, g=0.953, b=0.961),
        card: @graphics.Color::white(),
        page: @graphics.Color::white(),
        page_border: @graphics.Color::rgba(r=0.898, g=0.906, b=0.922),
        page_shadow: @graphics.ShadowStyle::new(
          color=@graphics.Color::black().multiply_alpha(0.10),
          offset=@geometry.Point::new(x=0.0, y=2.0),
          blur_radius=24.0,
        ),
        text: @graphics.Color::rgba(r=0.122, g=0.137, b=0.157),
        text_muted: @graphics.Color::rgba(r=0.361, g=0.388, b=0.439),
        text_dim: @graphics.Color::rgba(r=0.541, g=0.569, b=0.620),
        accent: @graphics.Color::rgba(r=0.169, g=0.400, b=0.824),
        accent_fill: @graphics.Color::rgba(r=0.169, g=0.400, b=0.824),
        hover: @graphics.Color::black().multiply_alpha(0.045),
        selected: @graphics.Color::rgba(r=0.169, g=0.400, b=0.824, a=0.12),
        selected_inactive: @graphics.Color::black().multiply_alpha(0.07),
        divider: @graphics.Color::black().multiply_alpha(0.08),
        scrollbar: @graphics.Color::black().multiply_alpha(0.18),
        scrollbar_active: @graphics.Color::black().multiply_alpha(0.36),
        dirty_dot: @graphics.Color::rgba(r=0.169, g=0.400, b=0.824),
        rich_text: @moui_richtext.MarkdownRichTextPalette::light(),
      }
    Dark =>
      {
        scheme,
        frame: @graphics.Color::rgba(r=0.090, g=0.094, b=0.106),
        card: @graphics.Color::rgba(r=0.122, g=0.129, b=0.145),
        page: @graphics.Color::rgba(r=0.122, g=0.129, b=0.145),
        page_border: @graphics.Color::white().multiply_alpha(0.07),
        page_shadow: @graphics.ShadowStyle::new(
          color=@graphics.Color::black().multiply_alpha(0.50),
          offset=@geometry.Point::new(x=0.0, y=4.0),
          blur_radius=28.0,
        ),
        text: @graphics.Color::rgba(r=0.847, g=0.863, b=0.890),
        text_muted: @graphics.Color::rgba(r=0.604, g=0.635, b=0.682),
        text_dim: @graphics.Color::rgba(r=0.420, g=0.447, b=0.502),
        accent: @graphics.Color::rgba(r=0.471, g=0.682, b=0.949),
        accent_fill: @graphics.Color::rgba(r=0.239, g=0.435, b=0.769),
        hover: @graphics.Color::white().multiply_alpha(0.06),
        selected: @graphics.Color::rgba(r=0.471, g=0.682, b=0.949, a=0.20),
        selected_inactive: @graphics.Color::white().multiply_alpha(0.12),
        divider: @graphics.Color::white().multiply_alpha(0.08),
        scrollbar: @graphics.Color::white().multiply_alpha(0.18),
        scrollbar_active: @graphics.Color::white().multiply_alpha(0.36),
        dirty_dot: @graphics.Color::rgba(r=0.471, g=0.682, b=0.949),
        rich_text: @moui_richtext.MarkdownRichTextPalette::dark(),
      }
  }
}

///|
/// Build the MoUI theme from the app tokens. Built-in controls keep working
/// through `ColorPalette`; the app's island/state colors are read directly
/// from `MarkdownUiTokens` by the shell and custom rows.
fn markdown_ui_theme(
  tokens : MarkdownUiTokens,
  reduced_motion~ : Bool = false,
) -> @moui.Theme {
  let base = match tokens.scheme {
    Light => @views.light_theme()
    Dark => @views.dark_theme()
  }
  let palette = {
    ..base.palette,
    background: tokens.frame,
    surface: tokens.card,
    surface_variant: tokens.frame,
    foreground: tokens.text,
    on_foreground: tokens.text,
    on_surface: tokens.text,
    on_surface_variant: tokens.text_muted,
    muted: tokens.text_muted,
    outline: tokens.page_border,
    outline_variant: tokens.divider,
    primary: tokens.accent,
    on_primary: @graphics.Color::white(),
    primary_container: tokens.selected,
    on_primary_container: tokens.text,
    secondary: tokens.text_muted,
    on_secondary: @graphics.Color::white(),
    focus: tokens.accent,
  }
  let radius : @core.RadiusScale = {
    sm: 6.0,
    md: 8.0,
    lg: 10.0,
    pill: 999.0,
  }
  let motion = if reduced_motion {
    { ..@core.MotionScale::default(), fast_ms: 0.0, normal_ms: 0.0, slow_ms: 0.0, }
  } else {
    @core.MotionScale::default()
  }
  @views.theme(
    base=base,
    scheme=tokens.scheme,
    palette=palette,
    radius_scale=radius,
    motion=motion,
  )
}

///|
/// Island card: a surface with a one-pixel edge and the shell radius. Padding
/// and layout are the caller's responsibility so the same primitive serves the
/// sidebar, the editor page, and the overlay panels.
#warnings("-unused_value")
fn markdown_island_card(
  child : @moui.View[MarkdownEditorMsg],
  tokens : MarkdownUiTokens,
  radius~ : Double,
  padding~ : @geometry.Insets = @geometry.Insets::all(0.0),
) -> @moui.View[MarkdownEditorMsg] {
  @views.container(
    @views.padding_edges(
      child,
      top=padding.top,
      right=padding.right,
      bottom=padding.bottom,
      left=padding.left,
    ),
    variant=@views.ContainerVariant::Base,
    background=tokens.card,
    border=Some(
      @core.BorderStyle::new(
        brush=@graphics.Brush::solid(tokens.page_border),
        width=1.0,
      ),
    ),
    corner_radius=radius,
    padding=0.0,
  )
}

///|
/// Hairline used between cards/sections; the shell draws it on the frame or
/// card surface instead of relying on a widget divider.
#warnings("-unused_value")
fn markdown_ui_divider(
  tokens : MarkdownUiTokens,
  width~ : Double,
  height~ : Double = 1.0,
) -> @moui.View[MarkdownEditorMsg] {
  @views.frame(@views.empty(), width=width, height=height).background(
    tokens.divider,
  )
}
