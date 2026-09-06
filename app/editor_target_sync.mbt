///|
fn markdown_editor_session_active_block(
  session : @moui_richtext.MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
) -> @moui_richtext.MarkdownEditorBlock? {
  let anchor = match markdown_editor_active_selection(selection.selection) {
    Some(range) => range.start
    None => selection.caret
  }
  let anchor = markdown_editor_clamp_int(anchor, 0, session.source_length)
  let blocks = session.editor_blocks
  if blocks.length() == 0 {
    return None
  }
  let mut low = 0
  let mut high = blocks.length() - 1
  while low <= high {
    let mid = (low + high) / 2
    let block = blocks[mid]
    if anchor < block.source_range.start {
      high = mid - 1
    } else if anchor > block.source_range.end {
      low = mid + 1
    } else {
      return Some(block)
    }
  }
  None
}

///|
fn markdown_editor_session_active_block_label(
  block : @moui_richtext.MarkdownEditorBlock?,
) -> String {
  match block {
    Some(block) => markdown_editor_session_block_kind_label(block.block.kind)
    None => "Paragraph"
  }
}

///|
fn markdown_editor_session_block_kind_label(
  kind : @moui_richtext.MarkdownBlockKind,
) -> String {
  match kind {
    @moui_richtext.MarkdownBlockKind::Heading(level) =>
      "Heading " + level.to_string()
    @moui_richtext.MarkdownBlockKind::UnorderedListItem => "Bullet list"
    @moui_richtext.MarkdownBlockKind::TaskListItem(_) => "Task list"
    @moui_richtext.MarkdownBlockKind::OrderedListItem(_) => "Ordered list"
    @moui_richtext.MarkdownBlockKind::Blockquote => "Quote"
    @moui_richtext.MarkdownBlockKind::CodeBlock => "Code block"
    @moui_richtext.MarkdownBlockKind::HorizontalRule => "Rule"
    @moui_richtext.MarkdownBlockKind::Table => "Table"
    @moui_richtext.MarkdownBlockKind::FootnoteDefinition(label) =>
      "Footnote " + label
    @moui_richtext.MarkdownBlockKind::HtmlBlock => "HTML"
    @moui_richtext.MarkdownBlockKind::FrontMatter => "Front matter"
    @moui_richtext.MarkdownBlockKind::Paragraph => "Paragraph"
  }
}

///|
/// Caret-only probes narrow to the active block: reference syntax cannot
/// span blocks, so extraction over the block's own text is semantically
/// equal to scanning the whole document while skipping its O(document)
/// character copy. Selection probes keep whole-document scope unchanged.
fn markdown_editor_session_block_scoped_probe(
  selection : MarkdownEditorSelection,
  block : @moui_richtext.MarkdownEditorBlock?,
) -> (String, MarkdownEditorSelection)? {
  if markdown_editor_active_selection(selection.selection) is Some(_) {
    return None
  }
  match block {
    Some(block) => {
      let text = block.block.text
      let caret = markdown_editor_clamp_int(
        selection.caret - block.source_range.start,
        0,
        markdown_editor_text_length(text),
      )
      Some((text, { caret, selection: None }))
    }
    None => None
  }
}

///|
fn markdown_editor_session_selected_link_target(
  session : @moui_richtext.MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  block : @moui_richtext.MarkdownEditorBlock?,
) -> String? {
  if markdown_editor_session_should_probe_reference(
      selection,
      block,
      image=false,
    ) {
    match markdown_editor_session_block_scoped_probe(selection, block) {
      Some((text, block_local)) =>
        markdown_editor_selected_link_target(text, block_local)
      None => markdown_editor_selected_link_target(session.source(), selection)
    }
  } else {
    None
  }
}

///|
fn markdown_editor_session_selected_image_target(
  session : @moui_richtext.MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  block : @moui_richtext.MarkdownEditorBlock?,
) -> String? {
  if markdown_editor_session_should_probe_reference(
      selection,
      block,
      image=true,
    ) {
    match markdown_editor_session_block_scoped_probe(selection, block) {
      Some((text, block_local)) =>
        markdown_editor_selected_image_target(text, block_local)
      None =>
        markdown_editor_selected_image_target(session.source(), selection)
    }
  } else {
    None
  }
}

///|
fn markdown_editor_session_should_probe_reference(
  selection : MarkdownEditorSelection,
  block : @moui_richtext.MarkdownEditorBlock?,
  image~ : Bool,
) -> Bool {
  match markdown_editor_active_selection(selection.selection) {
    Some(_) => true
    None =>
      match block {
        Some(block) =>
          match block.block.kind {
            @moui_richtext.MarkdownBlockKind::Paragraph =>
              markdown_editor_paragraph_reference_probe(
                block.block.text,
                selection.caret - block.source_range.start,
                image~,
              )
            _ =>
              if image {
                block.block.text.contains("![")
              } else {
                block.block.text.contains("[") || block.block.text.contains("<")
              }
          }
        None => false
      }
  }
}

///|
fn markdown_editor_paragraph_reference_probe(
  text : String,
  caret : Int,
  image~ : Bool,
) -> Bool {
  let text_length = markdown_editor_text_length(text)
  let caret = markdown_editor_clamp_int(caret, 0, text_length)
  let utf16_length = text.length()
  let caret_offset = if caret == text_length {
    utf16_length
  } else {
    text.offset_of_nth_char(caret).unwrap_or(utf16_length)
  }
  let mut offset = 0
  let mut index = 0
  let mut previous : Char? = None
  let mut angle_open_seen = false
  let mut bracket_open_seen = false
  let mut bracket_previous : Char? = None
  while index < caret && offset < utf16_length {
    match text.get_char(offset) {
      Some(ch) => {
        if ch == '\n' {
          angle_open_seen = false
          bracket_open_seen = false
          bracket_previous = None
        } else {
          if ch == '<' {
            angle_open_seen = true
          }
          if ch == '[' {
            bracket_open_seen = true
            bracket_previous = previous
          }
        }
        previous = Some(ch)
        offset = offset + ch.utf16_len()
        index = index + 1
      }
      None => break
    }
  }
  if !image &&
    angle_open_seen &&
    markdown_editor_paragraph_has_closing_reference(
      text, caret_offset, utf16_length, '>',
    ) {
    return true
  }
  if !bracket_open_seen {
    return false
  }
  match (image, bracket_previous) {
    (true, Some('!')) => ()
    (true, _) => return false
    (false, Some('!')) => return false
    (false, _) => ()
  }
  markdown_editor_paragraph_has_closing_reference(
    text, caret_offset, utf16_length, ']',
  )
}

///|
fn markdown_editor_paragraph_has_closing_reference(
  text : String,
  start_offset : Int,
  utf16_length : Int,
  close : Char,
) -> Bool {
  let mut offset = start_offset
  while offset < utf16_length {
    match text.get_char(offset) {
      Some(ch) =>
        if ch == close {
          return true
        } else if ch == '\n' {
          return false
        } else {
          offset = offset + ch.utf16_len()
        }
      None => return false
    }
  }
  false
}

///|
/// Block-scoped footnote lookup. The reference near the caret is found in
/// the active block's own text; its definition is located through the block
/// table's footnote blocks. Both steps stay bounded — the whole-document
/// fallback materializes a full document character array on every keystroke
/// typed near footnote syntax. A label "defined" only inside a non-footnote
/// block (e.g. inside a code fence) no longer resolves, matching the block
/// semantics everywhere else in the editor.
fn markdown_editor_session_selected_footnote_text(
  session : @moui_richtext.MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  block : @moui_richtext.MarkdownEditorBlock?,
) -> String? {
  match markdown_editor_active_selection(selection.selection) {
    Some(_) => markdown_editor_selected_footnote_text(session.source(), selection)
    None =>
      match block {
        Some(
          {
            block: {
              kind: @moui_richtext.MarkdownBlockKind::FootnoteDefinition(_),
              text,
              ..,
            },
            ..,
          }
        ) => Some(text)
        Some({ block: { text, .. }, .. }) =>
          if text.contains("[^") {
            match markdown_editor_session_block_scoped_probe(selection, block) {
              Some((block_text, block_local)) =>
                match markdown_editor_session_footnote_reference_label(
                    block_text, block_local.caret,
                  ) {
                  Some(label) =>
                    markdown_editor_session_footnote_definition_text(
                      session, label,
                    )
                  None => None
                }
              None =>
                markdown_editor_selected_footnote_text(session.source(), selection)
            }
          } else {
            None
          }
        None => None
      }
  }
}

///|
/// `[^label]` surrounding the caret inside one block's text — the
/// block-scoped twin of the session-level reference scan.
fn markdown_editor_session_footnote_reference_label(
  text : String,
  caret : Int,
) -> String? {
  let chars = text.to_array()
  if chars.length() == 0 {
    return None
  }
  let anchor = markdown_editor_clamp_int(caret, 0, chars.length() - 1)
  let mut open = anchor
  while open > 0 && chars[open] != '[' {
    open = open - 1
  }
  if open + 3 >= chars.length() ||
    chars[open] != '[' ||
    chars[open + 1] != '^' {
    return None
  }
  let mut close = open + 2
  while close < chars.length() && chars[close] != ']' && chars[close] != '\n' {
    close = close + 1
  }
  if close >= chars.length() || chars[close] != ']' {
    return None
  }
  if anchor < open + 2 || anchor > close {
    return None
  }
  Some(String::from_array(chars[open + 2:close]))
}

///|
/// First footnote definition whose label matches, located through the
/// session's footnote blocks in document order.
fn markdown_editor_session_footnote_definition_text(
  session : @moui_richtext.MarkdownDocumentSession,
  label : String,
) -> String? {
  let key = markdown_editor_session_reference_label_key(label)
  for block in session.editor_blocks {
    if block.block.kind is
      @moui_richtext.MarkdownBlockKind::FootnoteDefinition(_) {
      for line_view in block.block.text.split("\n").to_array() {
        match markdown_editor_session_footnote_definition_line(
            line_view.to_owned(),
          ) {
          Some((definition_label, content)) =>
            if markdown_editor_session_reference_label_key(definition_label) ==
              key {
              return Some(content)
            }
          None => ()
        }
      }
    }
  }
  None
}

///|
/// Parses one `[^label]: content` definition line into its label and the
/// content after the colon (leading spaces skipped, trailing newline never
/// present in the input line).
fn markdown_editor_session_footnote_definition_line(
  line : String,
) -> (String, String)? {
  let chars = line.to_array()
  let mut start = 0
  while start < chars.length() &&
        (chars[start] == ' ' || chars[start] == '\t') {
    start = start + 1
  }
  if start + 4 >= chars.length() ||
    chars[start] != '[' ||
    chars[start + 1] != '^' {
    return None
  }
  let mut close = start + 2
  while close < chars.length() && chars[close] != ']' {
    close = close + 1
  }
  if close <= start + 2 ||
    close + 1 >= chars.length() ||
    chars[close + 1] != ':' {
    return None
  }
  let mut text_start = close + 2
  while text_start < chars.length() &&
        (chars[text_start] == ' ' || chars[text_start] == '\t') {
    text_start = text_start + 1
  }
  Some(
    (
      String::from_array(chars[start + 2:close]),
      String::from_array(chars[text_start:]),
    ),
  )
}

///|
/// Reference-label normalization: trim, collapse whitespace runs to one
/// space, lowercase — matching the session's label keys.
fn markdown_editor_session_reference_label_key(label : String) -> String {
  let normalized : Array[Char] = []
  let mut in_space = false
  for ch in label.trim().to_owned().to_array() {
    if ch == ' ' || ch == '\t' || ch == '\n' {
      if normalized.length() > 0 && !in_space {
        normalized.push(' ')
      }
      in_space = true
    } else {
      normalized.push(ch)
      in_space = false
    }
  }
  String::from_array(normalized).to_lower()
}

///|
fn markdown_editor_session_selected_html_block_text(
  block : @moui_richtext.MarkdownEditorBlock?,
) -> String? {
  match block {
    Some(
      {
        block: { kind: @moui_richtext.MarkdownBlockKind::HtmlBlock, text, .. },
        ..,
      }
    ) => Some(text)
    _ => None
  }
}
