///|
/// A thin scroll bar drawn at the right edge of the window (the indicator is
/// stacked over the full-width editor row, so its track hugs the window edge
/// instead of the centered page column).
///
/// The thumb is positioned by evaluating the scroll glide at *paint* time —
/// the same clock the editor content uses — so it tracks the animation frame
/// by frame instead of freezing at the position captured when the view was
/// built. It reports `animating` while the glide is in flight, which keeps
/// the host's redraw loop running until the scroll settles.

///|
fn markdown_editor_scroll_indicator(
  glide : MarkdownScrollGlide,
  viewport_height~ : Double,
  content_height~ : Double,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let indicator = @core.View::from_node(MarkdownEditorScrollIndicator::{
    glide,
    viewport_height,
    content_height,
    muted: theme.palette.muted,
  })
  indicator.on_drag_with_frame((event, frame) => {
    EditorScrollDragTo(
      markdown_editor_scroll_drag_offset(
        frame,
        event.position.y,
        content_height,
      ),
    )
  })
}

///|
priv struct MarkdownEditorScrollIndicator {
  glide : MarkdownScrollGlide
  viewport_height : Double
  content_height : Double
  muted : @graphics.Color
}

///|
impl @core.ViewNode for MarkdownEditorScrollIndicator with fn identity(_self) {
  @core.ViewIdentity::new(kind="MarkdownEditorScrollIndicator")
}

///|
impl @core.ViewNode for MarkdownEditorScrollIndicator with fn declaration(self) {
  @core.ViewDeclaration::channels(
    layout=@core.DeclarationChannel::Exact(
      @core.DeclarationKey::double(self.viewport_height),
    ),
    paint=@core.DeclarationChannel::Exact(
      @core.DeclarationKey::record(
        type_tag="momark.MarkdownEditorScrollIndicator.paint",
        fields=[
          (
            "glide",
            @core.DeclarationKey::record(
              type_tag="moui_richtext.MarkdownScrollGlide.v2",
              fields=[
                ("from_y", @core.DeclarationKey::double(self.glide.from_y)),
                ("to_y", @core.DeclarationKey::double(self.glide.to_y)),
                ("start_ms", @core.DeclarationKey::double(self.glide.start_ms)),
                ("tau_ms", @core.DeclarationKey::double(self.glide.tau_ms)),
              ],
            ),
          ),
          ("content_height", @core.DeclarationKey::double(self.content_height)),
          (
            "muted",
            @core.DeclarationKey::record(type_tag="graphics.Color", fields=[
              ("r", @core.DeclarationKey::double(self.muted.r)),
              ("g", @core.DeclarationKey::double(self.muted.g)),
              ("b", @core.DeclarationKey::double(self.muted.b)),
              ("a", @core.DeclarationKey::double(self.muted.a)),
            ]),
          ),
        ],
      ),
    ),
    semantics=@core.DeclarationChannel::Constant,
    platform=@core.DeclarationChannel::Constant,
  )
}

///|
impl @core.ViewNode for MarkdownEditorScrollIndicator with fn layout(self, ctx) {
  // Width 0: the stack stretches the indicator across the row and the paint
  // pins the track to its right edge.
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @geometry.Size::new(width=12.0, height=self.viewport_height),
    ),
  )
}

///|
/// Last painted thumb offset and the time it last moved, for the idle fade.
/// The scrollbar is a single-window overlay, so one slot is enough.
let markdown_scrollbar_motion : Ref[(Double, Double)] = Ref((0.0, 0.0))

///|
impl @core.ViewNode for MarkdownEditorScrollIndicator with fn paint(self, ctx) {
  // The editor paints before this sibling (it is earlier in the stack) and
  // publishes the frame-local scroll snapshot. While that snapshot is
  // animating, follow it instead of the settled app glide: the thumb stays
  // live without per-tick app state or a root rebuild.
  let live = @moui_richtext.markdown_scroll_peek_painted_animating()
  let offset_y = if live {
    @moui_richtext.markdown_scroll_peek_painted_offset()
  } else {
    self.glide.display_offset(
      ctx.now_ms,
      compensation=@moui_richtext.markdown_scroll_peek_geometry_compensation(),
      scale=ctx.environment.scale_factor,
    )
  }
  let now = ctx.now_ms
  let (last_offset, last_motion) = markdown_scrollbar_motion.val
  if offset_y != last_offset {
    markdown_scrollbar_motion.val = (offset_y, now)
  }
  let idle_ms = now - last_motion
  let fade = if idle_ms <= 600.0 {
    1.0
  } else {
    markdown_editor_max_double(0.0, 1.0 - (idle_ms - 600.0) / 600.0)
  }
  let animating = live ||
    self.glide.is_animating(now) ||
    (offset_y > 0.0 && idle_ms < 1200.0)
  let commands : Array[@core.DrawCommand] = []
  // Hide entirely while at the top (no content scrolled past); the glide
  // still reports animating so a scroll back to the top keeps drawing.
  if offset_y > 0.0 {
    // A 3px-wide track pinned to the right edge of the laid-out frame.
    let track_x = ctx.frame.origin.x + ctx.frame.size.width - 3.0
    let track = @geometry.Rect::new(
      x=track_x,
      y=ctx.frame.origin.y,
      width=3.0,
      height=ctx.frame.size.height,
    )
    // Thumb length = visible fraction of the document, clamped so short
    // documents still show a grabbable thumb.
    let viewport = markdown_editor_max_double(1.0, ctx.frame.size.height)
    let content = markdown_editor_max_double(viewport, self.content_height)
    let thumb_height = markdown_editor_min_double(
      viewport * 0.5,
      markdown_editor_max_double(30.0, viewport * viewport / content),
    )
    // Thumb travel maps the scroll offset linearly across the track.
    let max_scroll = markdown_editor_max_double(1.0, content - viewport)
    let scroll_fraction = markdown_editor_clamp_double(
        offset_y, 0.0, max_scroll,
      ) /
      max_scroll
    let thumb_y = track.origin.y + scroll_fraction * (viewport - thumb_height)
    // Fade in from the top so the page edge stays clean when unscrolled.
    let indicator_alpha = (if offset_y > 40.0 {
      0.65
    } else {
      offset_y / 40.0 * 0.65
    }) * fade
    commands.push(
      @core.DrawCommand::FillRect(track, self.muted.multiply_alpha(0.28)),
    )
    commands.push(
      @core.DrawCommand::FillRect(
        @geometry.Rect::new(
          x=track.origin.x,
          y=thumb_y,
          width=track.size.width,
          height=thumb_height,
        ),
        self.muted.multiply_alpha(indicator_alpha),
      ),
    )
  }
  { ..@core.ViewPaintPlan::commands(commands), animating, }
}

///|
impl @core.ViewNode for MarkdownEditorScrollIndicator with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::ScrollView,
    label="Editor scroll indicator",
  )
}

///|
/// Map a pointer y on the scrollbar track to a document offset. The thumb is
/// clamped to the track and its travel maps linearly to the scroll range; the
/// same geometry as `paint`, so grabbing anywhere on the thumb does not jump.
fn markdown_editor_scroll_drag_offset(
  frame : @geometry.Rect,
  pointer_y : Double,
  content_height : Double,
) -> Double {
  let viewport = markdown_editor_max_double(1.0, frame.size.height)
  let content = markdown_editor_max_double(viewport, content_height)
  let thumb_height = markdown_editor_min_double(
    viewport * 0.5,
    markdown_editor_max_double(30.0, viewport * viewport / content),
  )
  let max_scroll = markdown_editor_max_double(1.0, content - viewport)
  let travel = markdown_editor_max_double(1.0, viewport - thumb_height)
  let top = frame.origin.y
  let thumb_top = markdown_editor_clamp_double(
    pointer_y - thumb_height / 2.0,
    top,
    top + travel,
  )
  (thumb_top - top) / travel * max_scroll
}
