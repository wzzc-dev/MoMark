///|
/// Line-ending handling: the editor works in LF internally and restores the
/// document's original sequence on save. A CRLF document used to push a `\r`
/// into every text run, which the primary font does not cover — every run then
/// took the platform font-fallback path (a synchronous font-daemon query) and
/// a novel-sized document opened an order of magnitude slower.

///|
/// The enum carries no traits of its own: it is internal state, and deriving
/// `Eq`/`Debug` only to compare it in tests earns an unused-implementation
/// warning in the shipping build. Name it instead.
fn eol_name(eol : MarkdownEditorEol) -> String {
  match eol {
    Lf => "lf"
    CrLf => "crlf"
  }
}

///|
test "eol detection distinguishes lf, crlf, and lone cr" {
  inspect(eol_name(markdown_editor_detect_eol("")), content="lf")
  inspect(eol_name(markdown_editor_detect_eol("a\nb\n")), content="lf")
  inspect(eol_name(markdown_editor_detect_eol("a\r\nb\r\n")), content="crlf")
  inspect(eol_name(markdown_editor_detect_eol("a\rb\r")), content="lf")
  // Mixed input counts as CRLF: that is the sequence a save should restore,
  // and normalisation still collapses every form.
  inspect(eol_name(markdown_editor_detect_eol("a\r\nb\nc")), content="crlf")
}

///|
test "eol normalisation collapses every form to lf" {
  inspect(markdown_editor_normalize_eol("a\nb"), content="a\nb")
  inspect(markdown_editor_normalize_eol("a\r\nb"), content="a\nb")
  inspect(markdown_editor_normalize_eol("a\rb"), content="a\nb")
  inspect(markdown_editor_normalize_eol("a\r\n\r\nb"), content="a\n\nb")
  // An LF document is returned as-is, without a copy.
  let lf = "a\nb"
  assert_true(markdown_editor_normalize_eol(lf) == lf)
}

///|
test "eol restoration round-trips a crlf document byte for byte" {
  let crlf = "line one\r\nline two\r\n\r\nline four"
  let normalized = markdown_editor_normalize_eol(crlf)
  assert_true(!normalized.contains("\r"))
  inspect(markdown_editor_restore_eol(normalized, CrLf), content=crlf)
  inspect(markdown_editor_restore_eol(normalized, Lf), content=normalized)
}

///|
test "opening a crlf document normalises the text and keeps the line ending" {
  let app = MarkdownEditorApp::new()
  let services = markdown_editor_document_services(
    read_text="# Title\r\n\r\nBody line\r\nSecond line\r\n",
    selected_path="",
    seen_kind=Ref(@host.HostFileDialogKind::OpenFile),
    seen_title=Ref(""),
    seen_default_name=Ref(""),
  )
  app.open_recent_for_test("/tmp/crlf.md", services)
  // The editor never sees a carriage return.
  assert_true(!app.document().contains("\r"))
  inspect(app.document(), content="# Title\n\nBody line\nSecond line\n")
  // The document is not dirty just because it was normalised.
  assert_true(!app.dirty())
  // Line structure matches the LF equivalent exactly.
  let lf = MarkdownEditorApp::new()
  lf.load_document_for_test("# Title\n\nBody line\nSecond line\n", path="/tmp/lf.md")
  assert_true(
    app.document_session.blocks.length() == lf.document_session.blocks.length(),
  )
  assert_true(app.document_session.line_count == lf.document_session.line_count)
}

///|
test "saving a crlf document writes the original line ending back" {
  let app = MarkdownEditorApp::new()
  let written = Ref("")
  let services = markdown_editor_document_services(
    read_text="alpha\r\nbeta\r\n",
    selected_path="/tmp/out.md",
    seen_kind=Ref(@host.HostFileDialogKind::OpenFile),
    seen_title=Ref(""),
    seen_default_name=Ref(""),
    seen_written=Some(written),
  )
  app.open_recent_for_test("/tmp/crlf.md", services)
  app.save_as_dialog_for_test(services)
  inspect(written.val, content="alpha\r\nbeta\r\n")
}

///|
test "saving an lf document writes lf" {
  let app = MarkdownEditorApp::new()
  let written = Ref("")
  let services = markdown_editor_document_services(
    read_text="alpha\nbeta\n",
    selected_path="/tmp/out.md",
    seen_kind=Ref(@host.HostFileDialogKind::OpenFile),
    seen_title=Ref(""),
    seen_default_name=Ref(""),
    seen_written=Some(written),
  )
  app.open_recent_for_test("/tmp/lf.md", services)
  app.save_as_dialog_for_test(services)
  inspect(written.val, content="alpha\nbeta\n")
}

///|
test "a new document resets the line ending to lf" {
  let app = MarkdownEditorApp::new()
  let written = Ref("")
  let services = markdown_editor_document_services(
    read_text="alpha\r\nbeta\r\n",
    selected_path="/tmp/out.md",
    seen_kind=Ref(@host.HostFileDialogKind::OpenFile),
    seen_title=Ref(""),
    seen_default_name=Ref(""),
    seen_written=Some(written),
  )
  app.open_recent_for_test("/tmp/crlf.md", services)
  app.dispatch_message_for_test(services, NewDocument)
  app.set_document_from_input("fresh")
  app.save_as_dialog_for_test(services)
  inspect(written.val, content="fresh")
}
