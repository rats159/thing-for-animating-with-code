package thing_for_animating_with_code

import "core:fmt"
import "core:math"
import "core:os/os2"
import "core:slice"
import "core:text/edit"
import "core:thread"
import rl "vendor:raylib"

font: rl.Font

main :: proc() {
	rl.SetTraceLogLevel(.WARNING)
	font = rl.LoadFontEx("./Inter_24pt-Regular.ttf", 24, nil, 0)
	steps := generate_animation()
	fmt.println("Animation generated!")
	frames := render_animation(steps)
	fmt.println("Animation rendered!")

	save_images(frames)
	fmt.println("Animation saved!")
}


generate_animation :: proc() -> []Frame {
	red := Rectangle {
		pos   = {0, 0},
		size  = {100, 100},
		color = {255, 127, 127, 255},
	}

	text := Text {
		pos   = {0, 100},
		size  = 24,
		text  = "Hello",
		color = {0, 0, 0, 255},
		font  = font,
	}

	red_slide := chain(
		[]Animated(Vector2) {
			animate(&red.pos, [2]f32{700, 0}, 60, ease),
			animate(&red.pos, [2]f32{700, 700}, 60, ease),
			animate(&red.pos, [2]f32{0, 700}, 60, ease),
			animate(&red.pos, [2]f32{0, 0}, 60, ease),
		},
	)

	text_typeout := chain(
		[]Animated(string) {
			animate(&text.text, "Hello, World!", 30, ease),
			animate(&text.text, "Hello!!", 30, ease),
			animate(
				&text.text,
				"Hello! Here's some much longer text to showcase tweening!",
				60,
				ease,
			),
			animate(&text.text, "", 60, ease_in_cubic),
			animate(
				&text.text,
				"Animating to an empty string, then back to this",
				60,
				ease_out_cubic,
			),
		},
	)


	red_path := write_to_elements(red_slide, "pos", red)
	text_path := write_to_elements(text_typeout, "text", text)

	full_anim := elements_to_frames(red_path, text_path)

	return full_anim
}
