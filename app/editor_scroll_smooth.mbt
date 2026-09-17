///|
/// Smooth wheel scrolling for the editor surface.
///
/// The host already delivers precise per-pixel wheel deltas (macOS
/// `scrollingDeltaY`), but jumping the document straight to the target on
/// every event reads as jumpy next to VS Code's preview, whose scroller
/// animates each wheel notch over several frames. Discrete wheel notches
/// (a classic mouse wheel) move a target offset — with an immediate first
/// step so the page answers the flick at once — and a frame-rate timer
/// closes the remaining distance with a time-based exponential ease.
/// Continuous delta streams (trackpads and their platform momentum) are
/// passed through untouched: the OS already animates those, layering a
/// second ease on top would fight it and feel sluggish.

///|
/// Time constant of the exponential ease, in milliseconds: the fraction of
/// the remaining distance still ahead after this much time is 1/e ≈ 37%.
/// 90ms settles a notch with the same crisp glide VS Code's editor uses.
fn markdown_editor_scroll_ease_time_constant_ms() -> Double {
  90.0
}

///|
/// Timer cadence for the scroll animation subscription, in milliseconds.
/// The eased step itself is time-based, so cadence only bounds latency
/// between ticks; 8ms keeps ticks close to the display frame interval.
fn markdown_editor_scroll_tick_interval_ms() -> Double {
  8.0
}

///|
/// A wheel event that arrives while an animation is already running, with
/// no animation tick between the two, belongs to a continuous stream
/// (trackpad gesture or platform momentum): those deltas are already
/// animated by the OS and must be passed through, not eased again.
/// `markdown_editor_scroll_continuous_gap_ticks` is the number of animation
/// ticks that must intervene for the event to count as discrete again.
fn markdown_editor_scroll_continuous_gap_ticks() -> Int {
  1
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
/// down). Discrete notches move the target by the full delta and take an
/// immediate first eased step, so the document reacts on the very event
/// the finger produced and the rest of the notch glides in behind it.
/// Continuous streams pass straight through.
fn MarkdownEditorApp::editor_scroll_wheel(
  self : MarkdownEditorApp,
  delta_y : Double,
  viewport_height : Double,
) -> Unit {
  if delta_y == 0.0 {
    return ()
  }
  let max_scroll = self.editor_scroll_max_offset(viewport_height)
  // A wheel event landing on an in-flight animation with no tick in between
  // marks a continuous stream (trackpad/momentum): the OS already animates
  // it; interrupting with our own ease would double-smooth the motion.
  let continuous = self.editor_scroll_animating &&
    self.editor_scroll_ticks_since_wheel <
    markdown_editor_scroll_continuous_gap_ticks()
  if continuous {
    let next = markdown_editor_clamp_double(
      self.editor_scroll_target + delta_y,
      0.0,
      max_scroll,
    )
    self.editor_scroll_target = next
    self.editor_scroll = @geometry.Point::new(x=0.0, y=next)
    return ()
  }
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
  // Immediate first step (one tick's worth of the ease) keeps the scroll
  // responsive to the flick itself instead of waiting for the first tick.
  let first_step = markdown_editor_scroll_eased_step(
    self.editor_scroll.y,
    next_target,
    markdown_editor_scroll_tick_interval_ms(),
  )
  self.editor_scroll_target = next_target
  self.editor_scroll = @geometry.Point::new(
    x=0.0,
    y=markdown_editor_scroll_quantize(first_step),
  )
  self.editor_scroll_animating = next_target != self.editor_scroll.y
  self.editor_scroll_ticks_since_wheel = 0
}

///|
/// One eased step toward the target, covering `elapsed_ms` of the ease.
/// Returns false when the animation has settled and the ticking
/// subscription may stop.
fn MarkdownEditorApp::editor_scroll_animation_step(
  self : MarkdownEditorApp,
  elapsed_ms : Double,
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
  let next = markdown_editor_scroll_eased_step(
    self.editor_scroll.y,
    target,
    elapsed_ms,
  )
  let quantized = markdown_editor_scroll_quantize(next)
  // Settle when the eased motion rounds to at most one pixel per step:
  // sub-pixel creep is invisible and, with whole-pixel snapping, can stall
  // forever just short of the target (floor eats a <1px step). The glide
  // must always terminate, regardless of floating-point tails.
  let step_pixels = (next - self.editor_scroll.y).abs()
  let settled = (target - next).abs() <= 0.75 || step_pixels <= 1.0
  if settled {
    self.editor_scroll = @geometry.Point::new(
      x=0.0,
      y=markdown_editor_scroll_quantize(target),
    )
    self.editor_scroll_animating = false
  } else {
    self.editor_scroll = @geometry.Point::new(x=0.0, y=quantized)
  }
  if self.editor_scroll_ticks_since_wheel < 1024 {
    self.editor_scroll_ticks_since_wheel = self.editor_scroll_ticks_since_wheel +
    1
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
  let clamped = markdown_editor_clamp_double(y, 0.0, max_scroll)
  self.editor_scroll_target = clamped
  self.editor_scroll = @geometry.Point::new(x=0.0, y=clamped)
  self.editor_scroll_animating = false
}

///|
/// Time-based exponential ease from `current` toward `target` over
/// `elapsed_ms`: the remaining distance decays as exp(-elapsed / τ), which
/// composes across steps (two 16ms steps equal one 32ms step), so the glide
/// speed is independent of the timer cadence — a late tick simply covers
/// more time instead of visibly slowing the motion.
fn markdown_editor_scroll_eased_step(
  current : Double,
  target : Double,
  elapsed_ms : Double,
) -> Double {
  if elapsed_ms <= 0.0 {
    return current
  }
  let decay = @math.exp(
    -elapsed_ms / markdown_editor_scroll_ease_time_constant_ms(),
  )
  target - (target - current) * decay
}

///|
/// Snap a scroll offset to a whole logical pixel. Fractional offsets make
/// glyph rasterization shimmer while scrolling; whole pixels keep text
/// crisp. Round-to-nearest (not floor) so quantization stays unbiased
/// across steps — a floored glide drifts visibly slower than its target.
fn markdown_editor_scroll_quantize(offset : Double) -> Double {
  offset.round()
}
