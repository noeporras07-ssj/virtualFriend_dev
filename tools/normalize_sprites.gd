@tool
extends EditorScript

# ===== CONFIGURACIÓN =====
const INPUT_DIR := "res://assets/sprites/sleep/"
const OUTPUT_DIR := "res://assets/sprites/sleep_normalized/"

const CANVAS_WIDTH := 1254
const CANVAS_HEIGHT := 1254

# Altura visual deseada del personaje ya recortado.
const TARGET_CHARACTER_HEIGHT := 980

# Línea base donde deben quedar los pies.
# Mientras más grande, más abajo se coloca.
const BASELINE_Y := 1120

# Umbral mínimo de alpha para considerar un pixel visible.
const ALPHA_THRESHOLD := 0.01


func _run() -> void:
	var dir := DirAccess.open(INPUT_DIR)
	if dir == null:
		push_error("No se pudo abrir INPUT_DIR: " + INPUT_DIR)
		return

	# Crear carpeta de salida si no existe
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUTPUT_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if not dir.current_is_dir():
			if file_name.to_lower().ends_with(".png"):
				procesar_imagen(file_name)

		file_name = dir.get_next()

	dir.list_dir_end()

	print("✅ Normalización terminada.")


func procesar_imagen(file_name: String) -> void:
	var input_path := INPUT_DIR + file_name
	var output_path := OUTPUT_DIR + file_name

	var img := Image.new()
	var err := img.load(input_path)
	if err != OK:
		push_error("Error cargando: " + input_path)
		return

	var bounds := encontrar_bounds_alpha(img)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		push_warning("No se detectó contenido visible en: " + input_path)
		return

	# Recortar al contenido visible
	var cropped := img.get_region(bounds)

	# Escalar para que todos tengan la misma altura visual
	var target_height := TARGET_CHARACTER_HEIGHT
	var scale_factor := float(target_height) / float(cropped.get_height())
	var target_width := int(round(cropped.get_width() * scale_factor))

	cropped.resize(
		target_width,
		target_height,
		Image.INTERPOLATE_LANCZOS
	)

	# Crear lienzo final
	var final_img := Image.create(
		CANVAS_WIDTH,
		CANVAS_HEIGHT,
		false,
		Image.FORMAT_RGBA8
	)
	final_img.fill(Color(0, 0, 0, 0))

	# Centrar horizontalmente
	var pos_x := int((CANVAS_WIDTH - cropped.get_width()) / 2)

	# Alinear los pies a la misma línea base
	var pos_y := BASELINE_Y - cropped.get_height()

	# Pegar en el lienzo final
	final_img.blit_rect(
		cropped,
		Rect2i(0, 0, cropped.get_width(), cropped.get_height()),
		Vector2i(pos_x, pos_y)
	)

	var save_err := final_img.save_png(output_path)
	if save_err != OK:
		push_error("Error guardando: " + output_path)
	else:
		print("✔ Guardado: ", output_path)


func encontrar_bounds_alpha(img: Image) -> Rect2i:
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1

	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a > ALPHA_THRESHOLD:
				if x < min_x:
					min_x = x
				if y < min_y:
					min_y = y
				if x > max_x:
					max_x = x
				if y > max_y:
					max_y = y

	if max_x == -1 or max_y == -1:
		return Rect2i(0, 0, 0, 0)

	return Rect2i(
		min_x,
		min_y,
		max_x - min_x + 1,
		max_y - min_y + 1
	)
