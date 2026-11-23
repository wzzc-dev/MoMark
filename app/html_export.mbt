///|
/// Export the live document as a standalone HTML file. The document model and
/// its HTML projection live in `moui_markdown`; the app only picks the title
/// from the path and supplies the session snapshot.
fn MarkdownEditorApp::html_export_document(self : MarkdownEditorApp) -> String {
  let snapshot = self.document_session.snapshot()
  let title = markdown_editor_document_title(
    path=self.document_path,
    fallback=snapshot.active_heading,
  )
  @moui_markdown.markdown_html_document(snapshot, title)
}
