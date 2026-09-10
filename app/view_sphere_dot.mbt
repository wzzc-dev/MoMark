///|
using @views {draw_path}

///|
/// A soft gray sphere dot: light gray disc with a medium gray ring, drawn
/// as one stroked + filled circle. `PathVerb` has no arc primitive, so the
/// circle is approximated with four cubic Bézier segments (control-point
/// offset = r * 0.5523).
fn sphere_dot(
  size~ : Double,
  fill? : @graphics.Color = @graphics.Color::rgba(r=0.93, g=0.93, b=0.93),
  ring? : @graphics.Color = @graphics.Color::rgba(r=0.75, g=0.75, b=0.75),
  ring_width~ : Double = 2.0,
) -> @moui.View[MarkdownEditorMsg] {
  custom_layout(
    measure=constraints =>
      constraints.constrain(@geometry.Size::new(width=size, height=size)),
    paint=(ctx, frame) => {
      // Inset by half the stroke width so the ring stays inside the frame.
      let radius =
        markdown_editor_min_double(frame.size.width, frame.size.height) / 2.0 -
        ring_width / 2.0
      let cx = frame.origin.x + frame.size.width / 2.0
      let cy = frame.origin.y + frame.size.height / 2.0
      let k = radius * 0.5523
      let p = (dx : Double, dy : Double) =>
        @geometry.Point::new(x=cx + dx, y=cy + dy)
      let circle = [
        @graphics.PathVerb::MoveTo(p(0.0, -radius)),
        @graphics.PathVerb::CubicTo(p(k, -radius), p(radius, -k), p(radius, 0.0)),
        @graphics.PathVerb::CubicTo(p(radius, k), p(k, radius), p(0.0, radius)),
        @graphics.PathVerb::CubicTo(
          p(-k, radius),
          p(-radius, k),
          p(-radius, 0.0),
        ),
        @graphics.PathVerb::CubicTo(
          p(-radius, -k),
          p(-k, -radius),
          p(0.0, -radius),
        ),
        @graphics.PathVerb::Close,
      ]
      draw_path(
        ctx,
        @graphics.PathSpec::new(
          verbs=circle,
          fill=Some(@graphics.Brush::solid(fill)),
          stroke=Some(@graphics.Brush::solid(ring)),
          stroke_width=ring_width,
        ),
      )
    },
    semantics_label="Sphere dot",
  )
}
