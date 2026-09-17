///|
/// Smooth wheel scrolling for the editor surface.
///
/// The host already delivers precise per-pixel wheel deltas (macOS
/// `scrollingDeltaY`), but jumping the document straight to the target on
/// every event reads as jumpy next to VS Code's preview, whose scroller
/// animates each wheel notch over several frames. The wheel handler
/// therefore only moves a target offset (plus an immediate first step so
/// the page answers the flick at once) and a frame-rate subscription closes
/// the remaining distance with an exponential ease. Each tick snaps to whole
/// logical pixels so glyphs stay crisp while moving.

///|
/// Fraction of the remaining distance one animation tick covers. At ~60fps
/// this settles within roughly 180ms, matching VS Code's scroll animation
/// feel without gliding long after the wheel stops.
fn markdown_editor_scroll_ease_factor() -> Double {
  0.22
}

///|
/// Once the remaining distance drops below this many logical pixels the
/// animation finishes early; sub-pixel creep is invisible and only keeps the
/// timer subscription alive.
fn markdown_editor_scroll_settle_threshold() -> Double {
  0.5
}

///|
/// Timer cadence for the scroll animation subscription, in milliseconds.
fn markdown_editor_scroll_tick_interval_ms() -> Double {
  16.0
}

///|
/// The scrollable range for the current document/layout: the same estimated
/// content height `editor_source_layout` clamps against (estimate + bottom
/// breathing room), minus one viewport.
fn MarkdownEditorApp::editor_scroll_max_offset(
  self : MarkdownEditorApp,
  viewport_height : Double,
) -> Double {
  let appearance = self.appearance_spec()
  let editor_font = markdown_editor_appearance_font(appearance)
  let editor_width = markdown_editor_primary_editor_width(
    self.source_preview_visible,
    self.outline_visible,
    self.file_sidebar_visible,
    self.document_info_visible,
    appearance,
  )
  let content_height = markdown_editor_max_double(
    viewport_height,
    self.document_session.estimated_content_height(
      base=editor_font,
      source_mode=self.source_mode_enabled,
      content_width=markdown_editor_max_double(0.0, editor_width - 28.0),
    ) +
    96.0,
  )
  markdown_editor_max_double(0.0, content_height - viewport_height)
}

///|
/// Feed a wheel tick into the smooth-scroll state machine.
///
/// `delta_y` is the host's pixel delta for this event (positive scrolls
/// down). The target moves by the full delta and the visible offset takes an
/// immediate first eased step, so the document reacts on the very event the
/// finger produced and the rest of the notch glides in behind it.
fn MarkdownEditorApp::editor_scroll_wheel(
  self : MarkdownEditorApp,
  delta_y : Double,
  viewport_height : Double,
) -> Unit {
  if delta_y == 0.0 {
    return ()
  }
  let max_scroll = self.editor_scroll_max_offset(viewport_height)
  let current_target = if self.editor_scroll_animating {
    self.editor_scroll_target
  } else {
    self.editor_scroll.y
  }
  let next_target = markdown_editor_clamp_double(
    current_target + delta_y,
    0.0,
    max_scroll,
  )
  // Immediate first step keeps the scroll responsive to the flick itself.
  let immediate_step = markdown_editor_clamp_double(
    self.editor_scroll.y +
    (next_target - self.editor_scroll.y) *
    markdown_editor_scroll_ease_factor(),
    0.0,
    max_scroll,
  )
  self.editor_scroll_target = next_target
  self.editor_scroll = @geometry.Point::new(
    x=0.0,
    y=markdown_editor_scroll_quantize(immediate_step),
  )
  self.editor_scroll_animating = next_target != self.editor_scroll.y
}

///|
/// One eased step toward the target. Returns false when the animation has
/// settled and the ticking subscription may stop.
fn MarkdownEditorApp::editor_scroll_animation_step(
  self : MarkdownEditorApp,
  viewport_height : Double,
) -> Bool {
  if !self.editor_scroll_animating {
    return false
  }
  let max_scroll = self.editor_scroll_max_offset(viewport_height)
  let target = markdown_editor_clamp_double(
    self.editor_scroll_target,
    0.0,
    max_scroll,
  )
  let remaining = target - self.editor_scroll.y
  let next = if remaining.abs() <= markdown_editor_scroll_settle_threshold() {
    target
  } else {
    let eased = self.editor_scroll.y +
      remaining * markdown_editor_scroll_ease_factor()
    // Pixel snapping can swallow a whole eased step (remaining under ~5px
    // eases to a sub-pixel that floors back to the same offset), which
    // would stall the glide forever; snap to the target when quantization
    // eats the motion.
    markdown_editor_scroll_quantize(eased)
  }
  let next = if next == self.editor_scroll.y {
    target
  } else {
    next
  }
  self.editor_scroll = @geometry.Point::new(
    x=0.0,
    y=markdown_editor_scroll_quantize(next),
  )
  if
    (target - self.editor_scroll.y).abs() <=
    markdown_editor_scroll_settle_threshold() {
    self.editor_scroll = @geometry.Point::new(x=0.0, y=target)
    self.editor_scroll_animating = false
  }
  self.editor_scroll_animating
}

///|
/// Interrupt any in-flight animation and park the scroll at `y` (used when
/// a scroll anchor jump replaces the wheel-driven motion).
fn MarkdownEditorApp::editor_scroll_jump_to(
  self : MarkdownEditorApp,
  y : Double,
  viewport_height : Double,
) -> Unit {
  let max_scroll = self.editor_scroll_max_offset(viewport_height)
  self.editor_scroll_target = markdown_editor_clamp_double(y, 0.0, max_scroll)
  self.editor_scroll = @geometry.Point::new(
    x=0.0,
    y=markdown_editor_clamp_double(y, 0.0, max_scroll),
  )
  self.editor_scroll_animating = false
}

///|
/// Snap a scroll offset to a whole logical pixel. Fractional offsets make
/// glyph rasterization shimmer while scrolling; whole pixels keep text crisp.
fn markdown_editor_scroll_quantize(offset : Double) -> Double {
  offset.floor()
}
