///|
/// Translate the app's find options into the package-level find options. The
/// app keeps its own type because the find bar persists it as part of the app
/// JSON surface; the matching engine itself now lives in `moui_markdown`.
fn markdown_editor_find_options(
  options : MarkdownEditorFindOptions,
) -> @moui_markdown.MarkdownFindOptions {
  {
    case_sensitive: options.case_sensitive,
    whole_word: options.whole_word,
    regex: options.regex,
  }
}

///|
fn markdown_editor_find_matches(
  source : String,
  query : String,
  options~ : MarkdownEditorFindOptions = MarkdownEditorFindOptions::default(),
) -> Array[@text.TextRange] {
  @moui_markdown.markdown_find_matches(
    source,
    query,
    options=markdown_editor_find_options(options),
  )
}

///|
fn markdown_editor_find_query_from_selection(
  source : String,
  selection : MarkdownEditorSelection,
) -> String? {
  @moui_markdown.markdown_find_query_from_selection(source, selection)
}

///|
fn markdown_editor_find_seed_from_caret_word(
  source : String,
  selection : MarkdownEditorSelection,
) -> @moui_markdown.MarkdownFindSeed? {
  @moui_markdown.markdown_find_seed_from_caret_word(source, selection)
}

///|
fn markdown_editor_find_next_index(
  matches : Array[@text.TextRange],
  selection : MarkdownEditorSelection,
) -> Int32 {
  @moui_markdown.markdown_find_next_index(matches, selection)
}

///|
fn markdown_editor_find_previous_index(
  matches : Array[@text.TextRange],
  selection : MarkdownEditorSelection,
) -> Int32 {
  @moui_markdown.markdown_find_previous_index(matches, selection)
}

///|
fn markdown_editor_find_active_index(
  matches : Array[@text.TextRange],
  selection : MarkdownEditorSelection,
) -> Int32 {
  @moui_markdown.markdown_find_active_index(matches, selection)
}

///|
fn markdown_editor_find_live_update_index(
  matches : Array[@text.TextRange],
  selection : MarkdownEditorSelection,
) -> Int32 {
  @moui_markdown.markdown_find_live_update_index(matches, selection)
}

///|
fn markdown_editor_replace_source_range(
  source : String,
  range : @text.TextRange,
  replacement : String,
) -> String {
  @moui_markdown.markdown_replace_source_range(source, range, replacement)
}

///|
fn MarkdownEditorApp::refresh_find_matches(
  self : MarkdownEditorApp,
) -> Array[@text.TextRange] {
  let query = self.find_query
  let matches : Array[@text.TextRange] = if query == "" {
    []
  } else {
    markdown_editor_find_matches(
      self.document,
      query,
      options=self.find_options,
    )
  }
  self.find_matches = matches
  matches
}

///|
fn MarkdownEditorApp::refresh_find_matches_if_visible(
  self : MarkdownEditorApp,
) -> Unit {
  if self.find_visible {
    ignore(self.refresh_find_matches())
  }
}

///|
fn markdown_editor_replacement_selection(
  start : Int32,
  end : Int32,
) -> @text.TextRange? {
  if start == end {
    None
  } else {
    Some(@text.TextRange::new(start~, end~))
  }
}

///|
fn markdown_editor_next_match_after_replacement(
  matches : Array[@text.TextRange],
  replaced_start : Int32,
  replacement_end : Int32,
) -> @text.TextRange? {
  @moui_markdown.markdown_next_match_after_replacement(
    matches, replaced_start, replacement_end,
  )
}

///|
fn markdown_editor_replace_all_matches(
  source : String,
  matches : Array[@text.TextRange],
  replacement : String,
) -> String {
  @moui_markdown.markdown_replace_all_matches(source, matches, replacement)
}

///|
fn markdown_editor_find_status_label(
  query : String,
  matches : Array[@text.TextRange],
  selection : MarkdownEditorSelection,
  options~ : MarkdownEditorFindOptions = MarkdownEditorFindOptions::default(),
) -> String {
  @moui_markdown.markdown_find_status_label(
    query,
    matches,
    selection,
    options=markdown_editor_find_options(options),
  )
}
