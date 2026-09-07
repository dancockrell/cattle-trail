extends Control

var speaker: Node2D
var remaining := 0.0
var priority := 0
var panel: PanelContainer
var name_label: Label
var words: Label
var pointer_x := 30.0
var pointer_below := true
var head_height := 44.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff0cc")
	style.border_color = Color("674529")
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.anti_aliasing = false
	style.shadow_color = Color(0.12,0.08,0.03,0.35)
	style.shadow_size = 3
	style.shadow_offset = Vector2(2,3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation",3)
	panel.add_child(stack)
	name_label = Label.new()
	name_label.add_theme_color_override("font_color",Color("98613a"))
	name_label.add_theme_font_size_override("font_size",12)
	stack.add_child(name_label)
	words = Label.new()
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_theme_color_override("font_color",Color("3e2a1d"))
	words.add_theme_font_size_override("font_size",16)
	stack.add_child(words)
	visible = false

func say(who: Node2D, display_name: String, text: String, height: float, importance := 0) -> bool:
	if remaining>0 and importance<=priority: return false
	speaker = who
	head_height = height
	priority = importance
	name_label.text = display_name
	words.text = text
	remaining = clampf(1.6+text.length()*0.045,2.5,4.8)
	visible = true
	return true

func tick(delta: float, world_view: TextureRect) -> void:
	remaining = maxf(0,remaining-delta)
	visible = remaining>0 and is_instance_valid(speaker) and speaker.visible
	if not visible: return
	var narrow := get_viewport_rect().size.x<600
	words.add_theme_font_size_override("font_size",14 if narrow else 16)
	var width := minf(228,world_view.size.x-16)
	panel.custom_minimum_size = Vector2(width,0)
	panel.size = Vector2(width,0)
	size = panel.get_combined_minimum_size()
	size.x = width
	panel.size = size
	var head := world_view.position+(speaker.position+Vector2(0,-head_height))*world_view.size/Vector2(640,360)
	var left := clampf(head.x-width*0.5,world_view.position.x+8,world_view.position.x+world_view.size.x-width-8)
	var above := head.y-size.y-14
	pointer_below = above>=world_view.position.y+6
	var top := above if pointer_below else head.y+16
	if narrow and not pointer_below: top = world_view.position.y+world_view.size.y-size.y-6
	top = clampf(top,world_view.position.y+6,world_view.position.y+world_view.size.y-size.y-6)
	position = Vector2(left,top).round()
	pointer_x = clampf(head.x-left,15,width-15)
	queue_redraw()

func _draw() -> void:
	var y := size.y-1 if pointer_below else 1.0
	var sign_y := 1.0 if pointer_below else -1.0
	draw_colored_polygon(PackedVector2Array([Vector2(pointer_x-8,y),Vector2(pointer_x+8,y),Vector2(pointer_x,y+sign_y*12)]),Color("674529"))
	draw_colored_polygon(PackedVector2Array([Vector2(pointer_x-5,y),Vector2(pointer_x+5,y),Vector2(pointer_x,y+sign_y*8)]),Color("fff0cc"))
