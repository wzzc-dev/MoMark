///|
/// Scroll-glide helpers for the editor surface.
///
/// The scroll animation lives in the framework's paint-time animation model:
/// the app stores a `MarkdownScrollGlide` (from/to/start on the runtime's
/// animation clock) and the editor view evaluates it once per frame. The
/// position shown is therefore always sampled for the frame being drawn —
/// there is no timer tick grid to beat against the display refresh, the
/// animation runs in real time on 60Hz/120Hz/variable-refresh displays alike,
/// and no per-frame message or view rebuild is needed.
///
/// Continuous trackpad/momentum streams are eased too, just briefly: the OS
/// already animates their deltas, so they only get enough smoothing to land on
/// the display's frame grid rather than on the stream's own irregular cadence.
/// What no input kind ever does is *snap* — a re-keyed glide always starts from
/// the offset being shown, because starting from the pending target teleports
/// the view by whatever the ease still had to go (backwards, when the user
/// reverses direction or the target clamps at the document edge).

///|
/// Wheel events closer together than this belong to one continuous stream
/// (trackpad gesture or platform momentum): those deltas are already animated
/// by the OS, so the follow-up gets only light smoothing instead of a full
/// ease. Covers both 120Hz (8.3ms) and 60Hz (16.7ms) event streams; a spun
/// mouse wheel's notches land past it and keep the long ease.
fn markdown_editor_scroll_stream_gap_ms() -> Double {
  24.0
}

///|
/// Time constant for an isolated wheel notch (a mouse wheel click, or the
/// first event of a gesture, when there is no motion to continue): a visible
/// ease the user can aim with.
fn markdown_editor_scroll_notch_tau_ms() -> Double {
  90.0
}

///|
/// Time constant for a momentum stream: short enough that the shown position
/// lands within a frame or two of where the OS put it (no perceptible lag on
/// top of the platform's own animation), long enough to regularize the
/// stream's own irregular event cadence, which is what reads as silkiness.
fn markdown_editor_scroll_stream_tau_ms() -> Double {
  28.0
}

///|
/// The scrollable range for the current document/layout: the same estimated
/// content height `editor_source_layout` clamps against (estimate + bottom
/// breathing room), minus one viewport.
fn MarkdownEditorApp::editor_scroll_max_offset(
  self : MarkdownEditorApp,
  viewport_height : Double,
  viewport_width? : Double = 1120.0,
) -> Double {
  let appearance = self.appearance_spec()
  let editor_font = markdown_editor_appearance_font(appearance)
  let editor_width = markdown_editor_primary_editor_width_for_viewport(
    self.source_preview_visible,
    self.outline_visible,
    self.file_sidebar_visible,
    self.document_info_visible,
    appearance,
    viewport_width~,
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
/// Feed a wheel tick into the glide.
///
/// `wheel_delta_y` is the host's raw wheel delta (macOS convention: negative
/// scrolls down); `clock_ms` is the animation-clock time the event was handled
/// at, which stamps the new glide so it is evaluated on the same timeline it
/// was created on.
///
/// The delta accumulates onto the pending target for every event, so a rapid
/// spin or a long momentum flick sums its full intent instead of the shown
/// offset lagging a frame behind and shedding the remainder. What makes this
/// *not* a teleport is the `from_y`: the shown offset, never the target. The
/// original stream path re-keyed with `settled(next_target)` (from = to =
/// target), so the first frame that drew it leapt from wherever an in-flight
/// ease had reached straight to `target - delta` — and on a reversal that
/// point sits behind the shown offset, snapping the view backward (the
/// reported jump). Continuing from the shown offset keeps the position
/// continuous; `continuous` then only sets the easing speed.
///
/// The stream ease is deliberately short, not a snap. A snap would move the
/// content on the OS event grid, which is itself irregularly spaced; the short
/// follower re-times that motion onto the display's frame grid, which is what
/// makes a trackpad gesture read as smooth rather than steppy. It is short
/// enough (a couple of frames) that it adds no perceptible lag on top of the
/// platform's own momentum animation.
fn MarkdownEditorApp::editor_scroll_wheel(
  self : MarkdownEditorApp,
  wheel_delta_y : Double,
  viewport_height : Double,
  viewport_width? : Double = 1120.0,
  continuous~ : Bool,
  clock_ms~ : Double,
) -> Unit {
  if wheel_delta_y == 0.0 {
    return ()
  }
  let max_scroll = self.editor_scroll_max_offset(
    viewport_height,
    viewport_width~,
  )
  // Measured block heights can change while a document is being scrolled
  // (for example after a wrapped block or image is laid out). Keep the
  // re-key point inside the current range; otherwise a newly smaller range
  // makes the next wheel event ease backwards from an out-of-range offset,
  // which reads as a rebound at the bottom.
  let shown = markdown_editor_clamp_double(
    self.editor_scroll_glide.exact_offset_at(clock_ms),
    0.0,
    max_scroll,
  )
  let next_target = markdown_editor_clamp_double(
    self.editor_scroll_glide.to_y - wheel_delta_y,
    0.0,
    max_scroll,
  )
  self.editor_scroll_glide = MarkdownScrollGlide::new(
    // Continue from the exact shown offset, not the device-snapped display
    // value: rounding the hidden state each event would reintroduce the
    // sub-pixel jitter the paint-time snap exists to remove.
    from_y=shown,
    to_y=next_target,
    start_ms=clock_ms,
    tau_ms=if continuous {
      markdown_editor_scroll_stream_tau_ms()
    } else {
      markdown_editor_scroll_notch_tau_ms()
    },
  )
}

///|
/// Park the scroll at `y` (anchor jumps, typewriter centring, document
/// switches): a settled glide paints `y` for every clock value.
fn MarkdownEditorApp::editor_scroll_jump_to(
  self : MarkdownEditorApp,
  y : Double,
  viewport_height : Double,
) -> Unit {
  let max_scroll = self.editor_scroll_max_offset(viewport_height)
  self.editor_scroll_glide = MarkdownScrollGlide::settled(
    markdown_editor_clamp_double(y, 0.0, max_scroll),
  )
  self.last_wheel_ms = 0.0
  self.last_wheel_stream = false
}

///|
/// The offset currently being shown. Uses the host clock when available so a
/// caller that is not painting (an edit re-anchoring the document) still sees
/// the frame-accurate position; without one it falls back to the glide's
/// destination, which is the closest clock-free answer.
fn MarkdownEditorApp::editor_scroll_displayed_y(
  self : MarkdownEditorApp,
) -> Double {
  match self.scroll_clock {
    Some(clock) => self.editor_scroll_glide.exact_offset_at(clock())
    None => self.editor_scroll_glide.to_y
  }
}
