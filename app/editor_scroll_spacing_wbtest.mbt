///|
fn markdown_editor_text_layer_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @geometry.Rect? {
  let mut layer_frame : @geometry.Rect? = None
  for command in commands {
    match command {
      BeginRetainedLayer(spec) => layer_frame = Some(spec.frame)
      EndRetainedLayer(_) => layer_frame = None
      DrawText(run) if run.text == text => return layer_frame
      _ => ()
    }
  }
  None
}

///|
test "sample heading and first list item keep their spacing through the viewport top" {
  // The screenshots park the caret at Ln 1, Col 1 and Ln 4, Col 28.
  for caret in [0, 81] {
    let app = MarkdownEditorApp::new()
    app.set_document(sample_markdown())
    app.selection = { caret, selection: None, }
    let runtime = app.runtime(width=992.0, height=634.0)
    let mut expected_gap : Double? = None
    let mut expected_layer_inset : Double? = None
    let mut checks = 0
    let mut crossed_top = false
    let mut clock_ms = 0.0
    for direction in [-1.0, 1.0] {
      clock_ms = clock_ms + 2000.0
      runtime.advance_time(clock_ms)
      ignore(runtime.draw_frame())
      for _ in 0..<90 {
        let commands = runtime.draw_frame().commands
        match
          (
            markdown_editor_text_frame(commands, "列表与任务"),
            markdown_editor_text_frame(commands, "无序项 alpha"),
          ) {
          (Some(heading), Some(item)) => {
            if heading.origin.y < 0.0 {
              crossed_top = true
            }
            let layer = markdown_editor_text_layer_frame(
              commands, "列表与任务",
            ).unwrap()
            let inset = heading.origin.y - layer.origin.y
            match expected_layer_inset {
              Some(expected) =>
                assert_true(
                  (inset - expected).abs() < 0.001,
                  msg="heading y=\{heading.origin.y} moved inside its retained layer from \{expected} to \{inset}",
                )
              None => expected_layer_inset = Some(inset)
            }
            let gap = item.origin.y - heading.origin.y
            match expected_gap {
              Some(expected) =>
                assert_true(
                  (gap - expected).abs() < 0.001,
                  msg="caret \{caret} heading y=\{heading.origin.y}, list gap changed from \{expected} to \{gap}",
                )
              None => expected_gap = Some(gap)
            }
            checks = checks + 1
          }
          _ => ()
        }
        smooth_scroll_dispatch_wheel(app, runtime, direction * 8.0)
        clock_ms = clock_ms + 32.0
        runtime.advance_time(clock_ms)
      }
    }
    assert_true(checks > 20)
    assert_true(crossed_top)
  }
}

///|
test "heading and body spacing stays fixed while scrolling in both directions" {
  let app = MarkdownEditorApp::new()
  let parts : Array[String] = []
  for index in 0..<60 {
    parts.push("## Scroll heading \{index}\n\n\n\nScroll body \{index}.")
  }
  app.set_document(parts.join("\n\n"))
  let runtime = app.runtime(width=980.0, height=640.0)
  let gaps : Map[Int32, Double] = Map([])
  let mut checks = 0
  let mut clock_ms = 0.0
  for direction in [-1.0, 1.0] {
    clock_ms = clock_ms + 2000.0
    runtime.advance_time(clock_ms)
    ignore(runtime.draw_frame())
    let positions : Map[Int32, Double] = Map([])
    for _ in 0..<100 {
      let commands = runtime.draw_frame().commands
      for index in 1..<60 {
        match
          (
            markdown_editor_text_frame(commands, "Scroll heading \{index}"),
            markdown_editor_text_frame(commands, "Scroll body \{index}."),
          ) {
          (Some(heading), Some(body)) => {
            match positions.get(index) {
              Some(previous) =>
                assert_true(
                  direction * (heading.origin.y - previous) >= -0.001,
                  msg="heading \{index} moved against scrolling from \{previous} to \{heading.origin.y}",
                )
              None => ()
            }
            positions[index] = heading.origin.y
            let gap = body.origin.y - heading.origin.y
            match gaps.get(index) {
              Some(previous) => {
                assert_true(
                  (gap - previous).abs() < 0.001,
                  msg="heading \{index} gap changed from \{previous} to \{gap}",
                )
                checks = checks + 1
              }
              None => gaps[index] = gap
            }
          }
          _ => ()
        }
      }
      smooth_scroll_dispatch_wheel(app, runtime, direction * 80.0)
      clock_ms = clock_ms + 32.0
      runtime.advance_time(clock_ms)
    }
  }
  assert_true(checks > 100)
  assert_true(gaps.length() > 20)
}
