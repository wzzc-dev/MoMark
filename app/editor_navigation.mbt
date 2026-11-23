///|
fn MarkdownEditorApp::toggle_source_preview(self : MarkdownEditorApp) -> Unit {
  self.source_preview_visible = !self.source_preview_visible
}

///|
fn MarkdownEditorApp::toggle_source_mode(self : MarkdownEditorApp) -> Unit {
  self.source_mode_enabled = !self.source_mode_enabled
}

///|
/// The outline now lives inside the file sidebar card, docked under the tree.
/// Toggling it opens the sidebar if needed, otherwise it expands/collapses the
/// section without hiding the tree.
fn MarkdownEditorApp::toggle_outline(self : MarkdownEditorApp) -> Unit {
  if !self.file_sidebar_visible {
    self.set_sidebar_panel(OutlinePanel)
  } else {
    self.outline_visible = !self.outline_visible
    self.sidebar_panel = if self.outline_visible {
      OutlinePanel
    } else {
      FilesPanel
    }
  }
}

///|
fn MarkdownEditorApp::toggle_file_sidebar(self : MarkdownEditorApp) -> Unit {
  if self.sidebar_panel is FilesPanel && self.file_sidebar_visible {
    self.hide_sidebar_panel()
  } else {
    self.set_sidebar_panel(FilesPanel)
  }
}

///|
/// Pick the persistent sidebar's content: the file tree, or the file tree with
/// the outline section expanded beneath it. Both share one left card.
fn MarkdownEditorApp::set_sidebar_panel(
  self : MarkdownEditorApp,
  panel : MarkdownSidebarPanel,
) -> Unit {
  let was_visible = self.file_sidebar_visible
  self.sidebar_panel = panel
  self.file_sidebar_visible = true
  self.outline_visible = panel is OutlinePanel
  self.panel_anim_target = 1.0
  if !was_visible && self.panel_anim_enabled {
    self.panel_anim_progress = 0.0
  } else {
    self.panel_anim_progress = 1.0
  }
}

///|
fn MarkdownEditorApp::hide_sidebar_panel(self : MarkdownEditorApp) -> Unit {
  self.file_sidebar_visible = false
  self.outline_visible = false
  self.panel_anim_target = 0.0
  if !self.panel_anim_enabled {
    self.panel_anim_progress = 0.0
  }
}

///|
fn MarkdownEditorApp::advance_panel_anim(self : MarkdownEditorApp) -> Unit {
  let step = 1.0 / 12.0
  if self.panel_anim_progress < self.panel_anim_target {
    self.panel_anim_progress = markdown_editor_min_double(
      self.panel_anim_target,
      self.panel_anim_progress + step,
    )
  } else if self.panel_anim_progress > self.panel_anim_target {
    self.panel_anim_progress = markdown_editor_max_double(
      self.panel_anim_target,
      self.panel_anim_progress - step,
    )
  }
}

///|
fn MarkdownEditorApp::panel_anim_fraction(self : MarkdownEditorApp) -> Double {
  if self.panel_anim_enabled {
    self.panel_anim_progress
  } else if self.file_sidebar_visible {
    1.0
  } else {
    0.0
  }
}

///|
fn MarkdownEditorApp::set_sidebar_width(
  self : MarkdownEditorApp,
  width : Double,
) -> Unit {
  self.sidebar_width = markdown_editor_clamp_double(width, 230.0, 420.0)
}

///|
fn MarkdownEditorApp::sidebar_visible(self : MarkdownEditorApp) -> Bool {
  self.file_sidebar_visible
}

///|
fn MarkdownEditorApp::toggle_document_info(self : MarkdownEditorApp) -> Unit {
  self.document_info_visible = !self.document_info_visible
}

///|
fn MarkdownEditorApp::toggle_focus_mode(self : MarkdownEditorApp) -> Unit {
  self.focus_mode_enabled = !self.focus_mode_enabled
}

///|
fn MarkdownEditorApp::toggle_typewriter_mode(self : MarkdownEditorApp) -> Unit {
  self.typewriter_mode_enabled = !self.typewriter_mode_enabled
  self.maybe_center_typewriter_selection()
}

///|
fn MarkdownEditorApp::toggle_zen_mode(self : MarkdownEditorApp) -> Unit {
  if self.zen_mode_enabled {
    self.zen_mode_enabled = false
  } else {
    self.zen_mode_enabled = true
    self.close_find()
    self.reset_format_palette()
    self.settings_visible = false
    self.file_sidebar_visible = false
    self.document_info_visible = false
    self.outline_visible = false
    self.source_preview_visible = false
  }
}

///|
fn MarkdownEditorApp::toggle_format_palette(self : MarkdownEditorApp) -> Unit {
  if self.format_palette_visible {
    self.reset_format_palette()
  } else {
    self.format_palette_visible = true
    self.overlay_anim_frame = 0
  }
}

///|
/// Flip one find-option flag by name. The string dispatch keeps the call sites
/// compact; the field names mirror the struct fields.
fn MarkdownEditorApp::toggle_find_option(
  self : MarkdownEditorApp,
  field~ : String,
) -> Unit {
  let options = self.find_options
  let next = match field {
    "case_sensitive" => { ..options, case_sensitive: !options.case_sensitive, }
    "whole_word" => { ..options, whole_word: !options.whole_word, }
    "regex" => { ..options, regex: !options.regex, }
    _ => options
  }
  self.find_options = next
  self.refresh_find_matches_if_visible()
}

///|
fn MarkdownEditorApp::reset_format_palette(self : MarkdownEditorApp) -> Unit {
  self.format_palette_visible = false
  self.format_palette_query = ""
}

///|
fn MarkdownEditorApp::cycle_writing_appearance(
  self : MarkdownEditorApp,
) -> Unit {
  self.writing_appearance = self.writing_appearance.next()
}

///|
fn MarkdownEditorApp::set_writing_appearance(
  self : MarkdownEditorApp,
  appearance : MarkdownEditorAppearance,
) -> Unit {
  self.writing_appearance = appearance
}

///|
fn MarkdownEditorApp::toggle_find(self : MarkdownEditorApp) -> Unit {
  if self.find_visible {
    self.find_visible = false
  } else {
    self.open_find()
  }
}

///|
fn MarkdownEditorApp::open_find(self : MarkdownEditorApp) -> Unit {
  self.find_visible = true
  self.overlay_anim_frame = 0
  match
    markdown_editor_find_query_from_selection(self.document, self.selection) {
    Some(query) => self.find_query = query
    None =>
      match
        markdown_editor_find_seed_from_caret_word(self.document, self.selection) {
        Some(seed) => {
          self.find_query = seed.query
          self.select_find_match(seed.range)
        }
        None => ()
      }
  }
  ignore(self.refresh_find_matches())
}

///|
fn MarkdownEditorApp::close_find(self : MarkdownEditorApp) -> Unit {
  self.find_visible = false
  self.find_matches = []
}

///|
fn MarkdownEditorApp::reset_find_session(self : MarkdownEditorApp) -> Unit {
  self.find_visible = false
  self.find_query = ""
  self.find_matches = []
  self.replace_text = ""
}

///|
fn MarkdownEditorApp::dismiss_auxiliary_panels(
  self : MarkdownEditorApp,
) -> Unit {
  if self.zen_mode_enabled {
    self.zen_mode_enabled = false
  } else if self.find_visible {
    self.close_find()
  } else if self.format_palette_visible ||
    self.settings_visible ||
    self.file_sidebar_visible ||
    self.document_info_visible ||
    self.outline_visible ||
    self.source_preview_visible ||
    self.more_menu_visible ||
    self.active_menu != "" {
    self.reset_format_palette()
    self.settings_visible = false
    self.file_sidebar_visible = false
    self.document_info_visible = false
    self.outline_visible = false
    self.source_preview_visible = false
    self.more_menu_visible = false
    self.active_menu = ""
  } else {
    let selection = self.selection
    if selection.selection is Some(_) {
      self.selection = { caret: selection.caret, selection: None, }
      self.sync_target_inputs()
    }
  }
}

///|
fn MarkdownEditorApp::jump_to_outline(
  self : MarkdownEditorApp,
  source_start : Int32,
) -> Unit {
  let caret = markdown_editor_clamp_int(
    source_start,
    0,
    markdown_editor_text_length(self.document),
  )
  self.selection = { caret, selection: None, }
  self.sync_target_inputs()
  self.scroll_to_source(caret)
}

///|
fn MarkdownEditorApp::maybe_center_typewriter_selection(
  self : MarkdownEditorApp,
) -> Unit {
  if self.typewriter_mode_enabled {
    let selection = self.selection
    let anchor = match selection.selection {
      Some(range) => range.normalized().start
      None => selection.caret
    }
    self.center_typewriter_source(anchor)
  }
}

///|
fn MarkdownEditorApp::jump_to_next_heading(self : MarkdownEditorApp) -> Unit {
  match
    markdown_editor_next_outline_start(
      self.document_session.outline,
      self.selection.caret,
    ) {
    Some(source_start) => self.jump_to_outline(source_start)
    None => ()
  }
}

///|
fn MarkdownEditorApp::jump_to_previous_heading(
  self : MarkdownEditorApp,
) -> Unit {
  match
    markdown_editor_previous_outline_start(
      self.document_session.outline,
      self.selection.caret,
    ) {
    Some(source_start) => self.jump_to_outline(source_start)
    None => ()
  }
}

///|
fn markdown_editor_next_outline_start(
  outline : Array[MarkdownEditorOutlineItem],
  caret : Int32,
) -> Int32? {
  if outline.length() == 0 {
    return None
  }
  for item in outline {
    if item.source_start > caret {
      return Some(item.source_start)
    }
  }
  Some(outline[0].source_start)
}

///|
fn markdown_editor_previous_outline_start(
  outline : Array[MarkdownEditorOutlineItem],
  caret : Int32,
) -> Int32? {
  if outline.length() == 0 {
    return None
  }
  let mut previous : Int32? = None
  for item in outline {
    if item.source_start < caret {
      previous = Some(item.source_start)
    }
  }
  match previous {
    Some(source_start) => Some(source_start)
    None => Some(outline[outline.length() - 1].source_start)
  }
}

///|
fn MarkdownEditorApp::scroll_to_source(
  self : MarkdownEditorApp,
  source_start : Int32,
) -> Unit {
  self.scroll_to_source_with_anchor(source_start, center=false)
}

///|
fn MarkdownEditorApp::center_typewriter_source(
  self : MarkdownEditorApp,
  source_start : Int32,
) -> Unit {
  self.scroll_to_source_with_anchor(source_start, center=true)
}

///|
fn MarkdownEditorApp::scroll_to_source_with_anchor(
  self : MarkdownEditorApp,
  source_start : Int32,
  center~ : Bool,
) -> Unit {
  let appearance = self.appearance_spec()
  let editor_font = markdown_editor_appearance_font(appearance)
  let session = self.document_session
  let source_mode = self.source_mode_enabled
  let editor_width = markdown_editor_primary_editor_width(
    self.source_preview_visible,
    self.outline_visible,
    self.file_sidebar_visible,
    self.document_info_visible,
    appearance,
  )
  let viewport_height = markdown_editor_viewport_height()
  let y = session.source_offset_y(
    source_start,
    base=editor_font,
    source_mode~,
    content_width=markdown_editor_max_double(0.0, editor_width - 28.0),
  )
  let rect = @geometry.Rect::new(
    x=0.0,
    y~,
    width=editor_width,
    height=editor_font.size * 1.55,
  )
  // Anchor jumps replace any in-flight wheel animation outright.
  self.editor_scroll_jump_to(
    markdown_editor_scroll_anchor_y(rect, viewport_height, center~),
    viewport_height,
  )
}

///|
fn markdown_editor_scroll_anchor_y(
  rect : @geometry.Rect,
  viewport_height : Double,
  center~ : Bool,
) -> Double {
  if center {
    rect.origin.y + rect.size.height / 2.0 - viewport_height / 2.0
  } else {
    rect.origin.y - 48.0
  }
}

///|
fn MarkdownEditorApp::find_next(self : MarkdownEditorApp) -> Unit {
  self.find_visible = true
  let matches = self.refresh_find_matches()
  if matches.length() == 0 {
    return
  }
  let index = markdown_editor_find_next_index(matches, self.selection)
  self.select_find_match(matches[index])
}

///|
fn MarkdownEditorApp::find_previous(self : MarkdownEditorApp) -> Unit {
  self.find_visible = true
  let matches = self.refresh_find_matches()
  if matches.length() == 0 {
    return
  }
  let index = markdown_editor_find_previous_index(matches, self.selection)
  self.select_find_match(matches[index])
}

///|
fn MarkdownEditorApp::update_find_query(
  self : MarkdownEditorApp,
  query : String,
) -> Unit {
  self.find_query = query
  if !self.find_visible {
    return
  }
  let matches = self.refresh_find_matches()
  if query == "" {
    let selection = self.selection
    if selection.selection is Some(_) {
      self.selection = { caret: selection.caret, selection: None, }
      self.sync_target_inputs()
    }
    return
  }
  if matches.length() == 0 {
    let selection = self.selection
    if selection.selection is Some(_) {
      self.selection = { caret: selection.caret, selection: None, }
      self.sync_target_inputs()
    }
    return
  }
  let index = markdown_editor_find_live_update_index(matches, self.selection)
  if index >= 0 {
    self.select_find_match(matches[index])
  }
}

///|
fn MarkdownEditorApp::select_find_match(
  self : MarkdownEditorApp,
  range : @text.TextRange,
) -> Unit {
  self.selection = { caret: range.end, selection: Some(range), }
  self.sync_target_inputs()
  self.scroll_to_source(range.start)
}

///|
fn MarkdownEditorApp::replace_current_find_match(
  self : MarkdownEditorApp,
) -> Unit {
  let source = self.document
  let replacement = self.replace_text
  let matches = self.refresh_find_matches()
  if matches.length() == 0 {
    return
  }
  let active = markdown_editor_find_active_index(matches, self.selection)
  let index = if active >= 0 {
    active
  } else {
    markdown_editor_find_next_index(matches, self.selection)
  }
  let range = matches[index]
  let before = self.pre_edit_state()
  let next_source = markdown_editor_replace_source_range(
    source, range, replacement,
  )
  if next_source == source {
    return
  }
  self.replace_document_source(next_source, reason=ReplaceEdit)
  self.record_edit_history(before~)
  let end = range.start + markdown_editor_text_length(replacement)
  let next_matches = self.refresh_find_matches()
  match
    markdown_editor_next_match_after_replacement(next_matches, range.start, end) {
    Some(next_range) => self.select_find_match(next_range)
    None => {
      self.selection = {
        caret: end,
        selection: markdown_editor_replacement_selection(range.start, end),
      }
      self.sync_target_inputs()
      self.scroll_to_source(range.start)
    }
  }
}

///|
fn MarkdownEditorApp::replace_all_find_matches(
  self : MarkdownEditorApp,
) -> Unit {
  let source = self.document
  let replacement = self.replace_text
  let matches = self.refresh_find_matches()
  if matches.length() == 0 {
    return
  }
  let next_source = markdown_editor_replace_all_matches(
    source, matches, replacement,
  )
  if next_source == source {
    return
  }
  let before = self.pre_edit_state()
  self.replace_document_source(next_source, reason=ReplaceEdit)
  self.record_edit_history(before~)
  let start = matches[0].start
  let end = start + markdown_editor_text_length(replacement)
  self.selection = {
    caret: end,
    selection: markdown_editor_replacement_selection(start, end),
  }
  self.sync_target_inputs()
  self.scroll_to_source(start)
}

///|
fn MarkdownEditorApp::sync_target_inputs(self : MarkdownEditorApp) -> Unit {
  // The richtext session owns classification: one call decides precedence
  // (html block, footnote, link, image, table, plain) and resolves wiki links
  // with the host scheme. The app only mirrors the result into the fields its
  // target editors and menus read, keeping the app enum as the local
  // vocabulary.
  let target = self.document_session.target_at(self.selection)
  self.block_label = target.block_label
  self.target_kind = markdown_editor_target_kind(target.kind)
  match target.link_target {
    Some(target) => self.link_target = target
    None => ()
  }
  match target.image_target {
    Some(target) => self.image_target = target
    None => ()
  }
  match target.footnote_text {
    Some(text) => self.footnote_text = text
    None => ()
  }
  match target.html_block_text {
    Some(text) => self.html_block_text = text
    None => ()
  }
}

///|
fn markdown_editor_target_kind(
  kind : @moui_richtext.MarkdownEditorTargetKind,
) -> MarkdownEditorTargetKind {
  match kind {
    @moui_richtext.MarkdownEditorTargetKind::PlainSelection => PlainSelection
    @moui_richtext.MarkdownEditorTargetKind::LinkTarget => LinkTarget
    @moui_richtext.MarkdownEditorTargetKind::ImageTarget => ImageTarget
    @moui_richtext.MarkdownEditorTargetKind::FootnoteTarget => FootnoteTarget
    @moui_richtext.MarkdownEditorTargetKind::HtmlBlockTarget => HtmlBlockTarget
    @moui_richtext.MarkdownEditorTargetKind::TableTools => TableTools
  }
}

///|

///|
fn MarkdownEditorApp::set_editor_zoom(
  self : MarkdownEditorApp,
  zoom : Double,
) -> Unit {
  self.editor_zoom = markdown_editor_clamp_double(zoom, 0.75, 2.0)
}

///|
fn MarkdownEditorApp::overlay_anim_progress(self : MarkdownEditorApp) -> Double {
  markdown_editor_min_double(1.0, self.overlay_anim_frame.to_double() / 12.0)
}
