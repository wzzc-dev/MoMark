///|
/// Register the native filesystem reader that backs the markdown image
/// intrinsic-size probe. The rich-text layout reads image headers
/// synchronously at projection time so percentage-width galleries and
/// plain images reserve their real box; the renderer keeps loading full
/// pixels asynchronously. Remote and data sources are skipped here (and in
/// the layout lookup) so only local files touch the disk, once per source.
pub fn register_image_metrics() -> Unit {
  @richtext.markdown_set_image_metrics_reader(source => {
    if source.has_prefix("http://") ||
      source.has_prefix("https://") ||
      source.has_prefix("data:") ||
      source.has_prefix("file://") {
      None
    } else {
      Some(@fs.read_file_to_bytes(source)) catch {
        _ => None
      }
    }
  })
}
