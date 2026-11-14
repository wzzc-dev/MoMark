///|
/// Scroll helpers for the editor surface.
///
/// The live glide belongs to the editor element: it lives in the element's
/// `ViewStateSlot`, is sampled at paint time from the runtime clock, and turns
/// a wheel gesture into zero program messages. The app keeps only the scroll
/// range (for layout and the indicator), one-shot programmatic requests, and
/// the last settled position reported by `EditorScrollSettled`.
///
/// Keeping the live offset out of the model is what removes the per-tick root
/// rebuild: a wheel event mutates only the editor element's transient state and
/// marks paint dirty.

///|
/// The scrollable range for the current document/layout: the same estimated
/// content height `editor_source_layout` clamps against (estimate + bottom
/// breathing room), minus one viewport.
fn MarkdownEditorApp::editor_scroll_max_offset(
  self : MarkdownEditorApp,
  viewport_height : Double,
  viewport_width~ : Double = 1120.0,
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
    sidebar_width=self.sidebar_width,
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
/// Issue a one-shot scroll target. The editor element applies a newer request
/// id once; reusing an id is a no-op, so a rebuild that carries the same request
/// does not restart a jump.
fn MarkdownEditorApp::editor_scroll_request_to(
  self : MarkdownEditorApp,
  y : Double,
  viewport_height : Double,
  viewport_width~ : Double = 1120.0,
) -> Unit {
  let max_scroll = self.editor_scroll_max_offset(
    viewport_height,
    viewport_width~,
  )
  let clamped = markdown_editor_clamp_double(y, 0.0, max_scroll)
  self.editor_scroll_settled_y = clamped
  self.next_editor_scroll_request_id = self.next_editor_scroll_request_id + 1
  self.editor_scroll_request = Some(
    @core.ScrollRequest::new(
      id=self.next_editor_scroll_request_id,
      offset=@core.Point::new(x=0.0, y=clamped),
    ),
  )
}

///|
/// Park the scroll at `y` (anchor jumps, typewriter centring, document
/// switches). The element applies it as a settled position on its next event or
/// paint pass.
fn MarkdownEditorApp::editor_scroll_jump_to(
  self : MarkdownEditorApp,
  y : Double,
  viewport_height : Double,
) -> Unit {
  self.editor_scroll_request_to(y, viewport_height)
}

///|
/// Apply an already-clamped scroll target from a scrollbar drag. The
/// indicator knows the content/viewport ratio, so the app only needs to
/// materialise the one-shot request; reusing the id keeps a rebuild that
/// carries the same request from restarting the jump.
fn MarkdownEditorApp::editor_scroll_request_to_clamped(
  self : MarkdownEditorApp,
  y : Double,
) -> Unit {
  let clamped = markdown_editor_max_double(0.0, y)
  self.editor_scroll_settled_y = clamped
  self.next_editor_scroll_request_id = self.next_editor_scroll_request_id + 1
  self.editor_scroll_request = Some(
    @core.ScrollRequest::new(
      id=self.next_editor_scroll_request_id,
      offset=@core.Point::new(x=0.0, y=clamped),
    ),
  )
}
