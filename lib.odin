package thing_for_animating_with_code

import "base:intrinsics"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:os/os2"
import "core:slice"
import "core:strings"
import "core:thread"
import rl "vendor:raylib"

NUM_SAVING_THREADS :: 8

TimingProc :: proc(t: f32) -> f32

linear: TimingProc : proc(t: f32) -> f32 {
	return t
}

ease: TimingProc : proc(t: f32) -> f32 {
	return ease_in_out_cubic(t)
}

ease_in_quad: TimingProc : proc(t: f32) -> f32 {
	return t * t
}

ease_out_quad: TimingProc : proc(t: f32) -> f32 {
	return t * (2 - t)
}

ease_in_out_quad: TimingProc : proc(t: f32) -> f32 {
	return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
}

ease_in_cubic: TimingProc : proc(t: f32) -> f32 {
	return t * t * t
}

ease_out_cubic: TimingProc : proc(t: f32) -> f32 {
	t := t - 1
	return t * t * t + 1
}

ease_in_out_cubic: TimingProc : proc(t: f32) -> f32 {
	if t < 0.5 {
		return 4 * t * t * t
	} else {
		n := -2 * t + 2
		return 1 - (n * n * n) / 2
	}
}

smoothstep: TimingProc : proc(t: f32) -> f32 {
	clamped := t
	if clamped < 0.0 {clamped = 0.0}
	if clamped > 1.0 {clamped = 1.0}
	return clamped * clamped * (3 - 2 * clamped)
}

Thread_Data :: struct {
	frames: []rl.Image,
	stride: int,
	start:  int,
}

save_frames_threaded :: proc(data: Thread_Data) {
	digits := int(math.ceil(math.log10(f32(len(data.frames)))))

	for i := data.start; i < len(data.frames); i += data.stride {
		rl.ExportImage(data.frames[i], fmt.ctprintf("out/%0*d.png", digits, i))
	}
}

write_to_elements :: proc(
	values: Animated($T),
	$P: string,
	base: $E,
) -> []Animation_Element where intrinsics.type_has_field(E, P),
	(intrinsics.type_field_type(E, P) == T) {
	offset := offset_of_by_string(E, P)
	elements := make([]Animation_Element, len(values.values))

	for &elem, i in elements {
		rect := base
		(^T)(uintptr(&rect) + offset)^ = values.values[i]
		elem = rect
	}

	return elements
}

animate :: proc {
	animate_vector,
	animate_string,
	animate_property,
}

animate_string :: proc(
	target: ^string,
	dest: string,
	frames: int,
	timing: TimingProc = linear,
) -> Animated(string) {
	anim := make([]string, frames)

	for i in 0 ..< frames {
		intermediate := text_lerp(target^, dest, timing(1 / f32(frames) * f32(i)))
		anim[i] = intermediate
	}

	target^ = dest
	return {anim}
}

animate_vector :: proc(
	target: ^$T/[$N]$E,
	dest: T,
	frames: int,
	timing: TimingProc = linear,
) -> Animated(T) {
	anim := make([]T, frames)

	for i in 0 ..< frames {
		intermediate := array_lerp(target^, dest, timing(1 / f32(frames) * f32(i)))
		anim[i] = intermediate
	}

	target^ = dest
	return {anim}
}

animate_property :: proc(
	target: ^$T,
	dest: T,
	frames: int,
	timing: TimingProc = linear,
	interpolator: proc(a, b: T, value: f32) -> T,
) -> Animated(T) {
	anim := make([]T, frames)

	for i in 0 ..< frames {
		intermediate := interpolator(target^, dest, timing(1 / f32(frames) * f32(i)))
		anim[i] = intermediate
	}

	target^ = dest
	return {anim}
}

elements_to_frames :: proc(elem_list: ..[]Animation_Element) -> []Frame {
	duration := 0
	for rect_anim in elem_list {
		if duration < len(rect_anim) {
			duration = len(rect_anim)
		}
	}

	frames := make([]Frame, duration)

	for frame_index in 0 ..< duration {
		elements := make([]Animation_Element, len(elem_list))
		for elem_steps, n in elem_list {
			elements[n] = elem_steps[frame_index]
		}
		frames[frame_index].elements = elements
	}
	return frames
}

render_animation :: proc(frames: []Frame) -> []rl.Image {
	images := make([]rl.Image, len(frames))
	for &image in images {
		image = rl.GenImageColor(800, 800, rl.WHITE)
	}

	for frame, i in frames {
		draw_frame(frame, &images[i])
	}

	return images
}

save_images :: proc(frames: []rl.Image) {
	os2.remove("output.mp4")
	os2.remove_all("out/")
	os2.make_directory("out")

	threads := make([]^thread.Thread, NUM_SAVING_THREADS)

	for i in 0 ..< NUM_SAVING_THREADS {
		threads[i] = thread.create_and_start_with_poly_data(
			Thread_Data{stride = NUM_SAVING_THREADS, start = i, frames = frames},
			save_frames_threaded,
		)
	}

	thread.join_multiple(..threads)
}

Vector2 :: [2]f32
Color :: [4]f32

Rectangle :: struct {
	pos:   Vector2,
	size:  Vector2,
	color: Color,
}

Text :: struct {
    pos: Vector2,
	text:  string,
	size:  f32,
	color: Color,
}

Animation_Element :: union {
	Rectangle,
	Text,
}

Frame :: struct {
	elements: []Animation_Element,
}

draw_frame :: proc(frame: Frame, image: ^rl.Image) {
	for element in frame.elements {
		switch type in element {
		case Rectangle:
			draw_rect(image, element.(Rectangle))
        case Text:
            draw_text(image, element.(Text))
		}

	}
}

to_rl_color :: proc(color: Color) -> rl.Color {
    return {
			u8(color.r),
			u8(color.g),
			u8(color.b),
			u8(color.a),
		}
}

draw_rect :: proc(image: ^rl.Image, rectangle: Rectangle) {
	rl.ImageDrawRectangleV(
		image,
		rectangle.pos,
		rectangle.size,
		to_rl_color(rectangle.color)
	)
}

draw_text :: proc(image: ^rl.Image, text:Text) {
    cstr := strings.clone_to_cstring(text.text)
    rl.ImageDrawText(image, cstr,i32(text.pos.x),i32(text.pos.y),i32(math.round(text.size)),to_rl_color(text.color))
    fmt.println("hi!")
}

Animated :: struct($T: typeid) {
	values: []T,
}

chain :: proc(sub_animations: []Animated($T)) -> Animated(T) {
	if len(sub_animations) == 0 {
		return {}
	}

	total_len := 0

	for anim in sub_animations {
		total_len += len(anim.values)
	}

	full_anim := make([]T, total_len)

	i := 0

	for anim in sub_animations {
		i += copy(full_anim[i:], anim.values)
	}

	return {full_anim}
}

text_lerp :: proc(from_string: string, to_string: string, value: f32) -> string {
	from := transmute([]u8)(strings.clone(from_string))
	to := transmute([]u8)(strings.clone(to_string))

	// left to right
	if len(to) >= len(from) {
		current := math.floor(f32(len(to)) * value)
		currentLength := int(math.floor(math.lerp(f32(len(from) - 1), f32(len(to)), value)))
		text := strings.Builder{}
		for i in 0 ..< len(to) {
			if f32(i) < current {
				strings.write_byte(&text, to[i])
			} else if i < len(from) || i <= currentLength {
				if i < len(from) {
					strings.write_byte(&text, from[i])
				} else {
					strings.write_byte(&text, to[i])
				}
			}
		}

		return strings.to_string(text)
	} else {
		current := int(math.round(f32(len(from)) * (1 - value)))
		currentLength := int(math.floor(math.lerp(f32(len(from) + 1), f32(len(to)), value)))
		// Reversed
		text := strings.Builder{}
		for i := len(from) - 1; i >= 0; i -= 1 {
			if i < current {
				strings.write_byte(&text, from[i])
			} else if (i < len(to) || i < currentLength) {
				if i < len(to) {
					strings.write_byte(&text, to[i])
				} else {
					strings.write_byte(&text, from[i])
				}
			}
		}

		return strings.reverse(strings.to_string(text))
	}
}

array_lerp :: proc(a, b: $T/[$N]$E, value: f32) -> T {
	out := [N]E{}

	for i in 0 ..< N {
		out[i] = math.lerp(a[i], b[i], value)
	}

	return out
}
