///|
fn main {
  let runtime = @momark.runtime(
    environment=@web.app_environment(),
    width=1200.0,
  )
  @runtime.run_app("MoMark", runtime)
  .render_all(@webgpu_adapter.from_env())
  .backend(@web.entry())
  .run()
}
