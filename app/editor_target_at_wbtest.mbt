///|
/// The unicode-prefix case used to drift in the app-local reference probe: a
/// surrogate-pair emoji before the link shifted the UTF-16 offset. The probe
/// now lives in the richtext session, and this pins the app's mirror of it.
test "markdown editor target probe avoids unicode boundary drift" {
  let app = MarkdownEditorApp::new()
  app.set_document("前缀 🤣 [MoUI](https://wzzc-dev.github.io/MoUI) tail")
  app.selection = { caret: 9, selection: None, }
  app.sync_target_inputs()
  assert_true(app.target_kind is LinkTarget)
  inspect(app.link_target, content="https://wzzc-dev.github.io/MoUI")

  app.set_document("前缀 🤣 ![logo](assets/logo.png) tail")
  app.selection = { caret: 10, selection: None, }
  app.sync_target_inputs()
  assert_true(app.target_kind is ImageTarget)
  inspect(app.image_target, content="assets/logo.png")
}

///|
/// A reference cannot span lines, so a bracket that opens on one line and
/// closes on the next is neither a link nor an image target.
test "markdown editor target probe stays on current line" {
  let app = MarkdownEditorApp::new()
  app.set_document("[old\ntext]")
  app.selection = { caret: 6, selection: None, }
  app.sync_target_inputs()
  assert_false(app.target_kind is LinkTarget)

  app.set_document("<old\ntext>")
  app.selection = { caret: 6, selection: None, }
  app.sync_target_inputs()
  assert_false(app.target_kind is LinkTarget)
}
