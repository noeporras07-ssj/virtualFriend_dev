extends Node2D


enum Estado {
	IDLE,
	CAMINANDO,
	INTERACTUANDO,
	FELIZ,
	HAMBRIENTA,
	COMIENDO,
	ARRASTRANDO,
	CANSADA,
	DURMIENDOSE,
	DORMIDA
}


# =========================================================
# COMPORTAMIENTO AUTOMÁTICO
# =========================================================

@export var tiempo_caminando: float = 5.0
@export var tiempo_descanso: float = 3.0

@export var velocidad_caminata: float = 80.0
@export var margen_caminata: int = 30
@export var distancia_minima_caminata: float = 150.0
@export var distancia_maxima_caminata: float = 500.0



# =========================================================
# PARPADEO
# =========================================================

@export var parpadeo_minimo: float = 2.0
@export var parpadeo_maximo: float = 5.0


# =========================================================
# MOUSE
# =========================================================

@export var distancia_arrastre: float = 20.0


# =========================================================
# NECESIDADES
# =========================================================

@export var perdida_hambre_por_segundo: float = 0.5
@export var perdida_energia_por_segundo: float = 0.15
@export var perdida_felicidad_por_segundo: float = 0.08

@export var limite_hambre: float = 25.0
@export var limite_energia: float = 30.0


# =========================================================
# SUEÑO
# =========================================================

# Cuando la energía llegue a este valor,
# Bella comienza a quedarse dormida.
@export var limite_sueno: float = 10.0

# Cuando llegue a este valor,
# Bella despierta.
@export var energia_despertar: float = 80.0

# Energía recuperada por segundo mientras duerme.
@export var recuperacion_energia_sueno: float = 2.0


# =========================================================
# NODOS
# =========================================================

@onready var mascota: AnimatedSprite2D = $Mascota

@onready var blink_timer: Timer = $BlinkTimer
@onready var dialog_timer: Timer = $DialogTimer
@onready var click_timer: Timer = $ClickTimer
@onready var needs_timer: Timer = $NeedsTimer

@onready var dialogo: PanelContainer = $Dialogo
@onready var texto_dialogo: Label = $Dialogo/Texto


# =========================================================
# ESTADO
# =========================================================

var estado_actual: Estado = Estado.IDLE

var mouse_presionado: bool = false
var arrastrando: bool = false
var parpadeando: bool = false
var doble_clic_detectado: bool = false

var posicion_mouse_inicial: Vector2i
var diferencia_mouse: Vector2i

var tiempo_estado: float = 0.0

var destino_x: int = 0
var limite_izquierdo: int = 0
var limite_derecho: int = 0


# =========================================================
# NECESIDADES DE BELLA
# =========================================================

var hambre: float = 100.0
var energia: float = 100.0
var felicidad: float = 100.0
var afecto: float = 50.0


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	configurar_ventana()
	colocar_ventana()
	configurar_senales()

	dialogo.visible = false

	estado_actual = Estado.IDLE
	tiempo_estado = tiempo_descanso

	mascota.flip_h = false
	mascota.play("idle")

	needs_timer.start()

	programar_siguiente_parpadeo()


# =========================================================
# VENTANA
# =========================================================

func configurar_ventana() -> void:
	var ventana := get_window()

	get_viewport().transparent_bg = true

	ventana.transparent = true
	ventana.borderless = true
	ventana.always_on_top = true


func colocar_ventana() -> void:
	var ventana := get_window()
	var pantalla := DisplayServer.screen_get_usable_rect()
	var tamano_ventana := ventana.size

	ventana.position = Vector2i(
		pantalla.position.x
		+ pantalla.size.x
		- tamano_ventana.x
		- 30,

		pantalla.position.y
		+ pantalla.size.y
		- tamano_ventana.y
		- 30
	)


# =========================================================
# SEÑALES
# =========================================================

func configurar_senales() -> void:
	blink_timer.one_shot = true
	dialog_timer.one_shot = true
	click_timer.one_shot = true

	needs_timer.one_shot = false
	needs_timer.wait_time = 1.0

	click_timer.wait_time = 0.35


	if not blink_timer.timeout.is_connected(iniciar_parpadeo):
		blink_timer.timeout.connect(iniciar_parpadeo)

	if not dialog_timer.timeout.is_connected(ocultar_dialogo):
		dialog_timer.timeout.connect(ocultar_dialogo)

	if not click_timer.timeout.is_connected(procesar_clic_simple):
		click_timer.timeout.connect(procesar_clic_simple)

	if not needs_timer.timeout.is_connected(actualizar_necesidades):
		needs_timer.timeout.connect(actualizar_necesidades)

	if not mascota.animation_finished.is_connected(finalizar_animacion):
		mascota.animation_finished.connect(finalizar_animacion)


# =========================================================
# PROCESS
# =========================================================

func _process(delta: float) -> void:

	if arrastrando:
		mover_con_mouse()
		return

	if mouse_presionado:
		return

	if parpadeando:
		return

	if estado_actual == Estado.INTERACTUANDO:
		return

	if estado_actual == Estado.FELIZ:
		return

	if estado_actual == Estado.HAMBRIENTA:
		return

	if estado_actual == Estado.COMIENDO:
		return

	if estado_actual == Estado.CANSADA:
		return

	if estado_actual == Estado.DURMIENDOSE:
		return

	if estado_actual == Estado.DORMIDA:
		return

	if estado_actual == Estado.CAMINANDO:
		mover_hacia_destino(delta)
		return

	tiempo_estado -= delta

	match estado_actual:

		Estado.IDLE:
			if tiempo_estado <= 0.0:
				iniciar_caminata()


# =========================================================
# CAMINAR
# =========================================================

func iniciar_caminata() -> void:

	if estado_actual == Estado.INTERACTUANDO:
		return

	if estado_actual == Estado.FELIZ:
		return

	if estado_actual == Estado.HAMBRIENTA:
		return

	if estado_actual == Estado.CANSADA:
		return

	if estado_actual == Estado.DURMIENDOSE:
		return

	if estado_actual == Estado.DORMIDA:
		return

	# Obtener el área utilizable de la pantalla
	var pantalla := DisplayServer.screen_get_usable_rect()

	var ventana_posicion := pantalla.position
	var ventana_tamano := get_window().size

	limite_izquierdo = ventana_posicion.x + margen_caminata
	limite_derecho = ventana_posicion.x + pantalla.size.x - ventana_tamano.x - margen_caminata

	# Posición actual de la ventana
	var posicion_actual_x: int = get_window().position.x

	# Elegir un destino aleatorio dentro de una distancia razonable
	var minimo: int = maxi(
		limite_izquierdo,
		int(posicion_actual_x - distancia_maxima_caminata)
	)

	var maximo: int = mini(
		limite_derecho,
		int(posicion_actual_x + distancia_maxima_caminata)
	)

	destino_x = randi_range(minimo, maximo)

	# Asegurar que no sea una caminata demasiado corta
	if abs(destino_x - posicion_actual_x) < distancia_minima_caminata:

		if destino_x < posicion_actual_x:
			destino_x = max(
				limite_izquierdo,
				int(posicion_actual_x - distancia_minima_caminata)
			)
		else:
			destino_x = min(
				limite_derecho,
				int(posicion_actual_x + distancia_minima_caminata)
			)

	estado_actual = Estado.CAMINANDO
	tiempo_estado = tiempo_caminando

	parpadeando = false
	blink_timer.stop()

	# Girar según la dirección
	if destino_x < posicion_actual_x:
		mascota.flip_h = true
	else:
		mascota.flip_h = false

	mascota.play("walk")

func mover_hacia_destino(delta: float) -> void:
	var posicion := get_window().position

	#caunto falta para llegar
	var diferencia: float = float(destino_x - posicion.x)

	if abs(diferencia) <= 2.0:
		posicion.x = destino_x
		get_window().position = posicion

		iniciar_descanso()
		return

	var movimiento: float = velocidad_caminata * delta
	if diferencia > 0:
		posicion.x += int(movimiento)
	else:
		position.x += int(movimiento)

	get_window().position = posicion

# =========================================================
# DESCANSO / IDLE
# =========================================================

func iniciar_descanso() -> void:

	estado_actual = Estado.IDLE
	tiempo_estado = tiempo_descanso

	mouse_presionado = false
	arrastrando = false
	parpadeando = false
	doble_clic_detectado = false

	mascota.flip_h = false
	mascota.play("idle")

	programar_siguiente_parpadeo()


# =========================================================
# SALUDO
# =========================================================

func iniciar_saludo() -> void:

	if estado_actual in [
		Estado.FELIZ,
		Estado.HAMBRIENTA,
		Estado.COMIENDO,
		Estado.CANSADA,
		Estado.DURMIENDOSE,
		Estado.DORMIDA
	]:
		return


	estado_actual = Estado.INTERACTUANDO

	mouse_presionado = false
	arrastrando = false
	parpadeando = false

	blink_timer.stop()

	mascota.flip_h = false
	mascota.stop()
	mascota.play("wave")


	var saludos: Array[String] = [
		"Hola peshosho",
		"Qué gusto verte, bello",
		"UwU",
		"¿Seguimos programando, mi genio fav?",
		"¡Aquí estoy, niño!",
		"Espero que tengas un hermoso día, bello"
	]


	mostrar_dialogo(
		saludos.pick_random(),
		2.5
	)

	print("Bella está saludando")


# =========================================================
# FELICIDAD
# =========================================================

func iniciar_felicidad() -> void:

	estado_actual = Estado.FELIZ

	mouse_presionado = false
	arrastrando = false
	parpadeando = false
	doble_clic_detectado = false

	blink_timer.stop()
	click_timer.stop()

	mascota.flip_h = false
	mascota.stop()
	mascota.play("happy")


	var mensajes_felices: Array[String] = [
		"¡Qué feliz estoy! 💖",
		"¡Me hiciste muy feliz!",
		"¡Yujuu! ✨",
		"¡Gracias por estar aquí!",
		"¡Vamos a programar, mi genio fav!",
		"¡Me encanta verte! 😊"
	]


	mostrar_dialogo(
		mensajes_felices.pick_random(),
		2.5
	)

	print("Bella está feliz")


# =========================================================
# HAMBRE
# =========================================================

func iniciar_hambre() -> void:

	if estado_actual == Estado.HAMBRIENTA:
		return


	estado_actual = Estado.HAMBRIENTA

	mouse_presionado = false
	arrastrando = false
	parpadeando = false
	doble_clic_detectado = false

	blink_timer.stop()
	click_timer.stop()

	mascota.flip_h = false
	mascota.stop()
	mascota.play("hungry")


	var mensajes_hambre: Array[String] = [
		"Tengo hambrita...",
		"¿Comemos algo?",
		"Mi pancita hace ruiditos...",
		"Necesito un bocadito...",
		"¿Hay algo rico para mí?"
	]


	mostrar_dialogo(
		mensajes_hambre.pick_random(),
		3.0
	)

	print("Bella tiene hambre")


# =========================================================
# PARPADEO
# =========================================================

func programar_siguiente_parpadeo() -> void:

	if estado_actual != Estado.IDLE:
		return

	if mouse_presionado or arrastrando or parpadeando:
		return

	blink_timer.stop()

	blink_timer.wait_time = randf_range(
		parpadeo_minimo,
		parpadeo_maximo
	)

	blink_timer.start()


func iniciar_parpadeo() -> void:

	if estado_actual != Estado.IDLE:
		return

	if mouse_presionado or arrastrando:
		programar_siguiente_parpadeo()
		return

	if parpadeando:
		return

	parpadeando = true

	mascota.play("blink")


# =========================================================
# FINALIZAR ANIMACIONES
# =========================================================

func finalizar_animacion() -> void:

	match mascota.animation:

		&"blink":

			parpadeando = false

			if estado_actual == Estado.IDLE:
				mascota.play("idle")
				programar_siguiente_parpadeo()


		&"wave":

			print("Saludo finalizado")
			iniciar_descanso()


		&"happy":

			print("Animación feliz finalizada")
			iniciar_descanso()


		&"eat":

			finalizar_comida()


		&"sleep_start":

			# sleep_start terminó:
			# 01 → 02 → 03 → 04
			#
			# Ahora Bella está completamente dormida.

			if estado_actual == Estado.DURMIENDOSE:

				estado_actual = Estado.DORMIDA

				print("Bella se quedó dormida")

				# Comienza el ciclo:
				# 05 → 06 → 07 → 08 → ...
				mascota.play("sleep")


# =========================================================
# INPUT
# =========================================================

func _input(event: InputEvent) -> void:

	if event is InputEventMouseButton:

		procesar_boton_mouse(event)


	elif event is InputEventMouseMotion:

		procesar_movimiento_mouse()


	elif event is InputEventKey:

		if event.pressed and not event.echo:

			# W = saludo
			if event.keycode == KEY_W:
				iniciar_saludo()

			# H = felicidad
			elif event.keycode == KEY_H:
				iniciar_felicidad()

			# G = hambre
			elif event.keycode == KEY_G:

				if estado_actual == Estado.HAMBRIENTA:
					iniciar_descanso()
				else:
					iniciar_hambre()

			# F = alimentar
			elif event.keycode == KEY_F:
				alimentar_bella()

			# S = probar sueño
			elif event.keycode == KEY_S:
				probar_sueno()


# =========================================================
# MOUSE
# =========================================================

func procesar_boton_mouse(
	event: InputEventMouseButton
) -> void:

	if event.button_index != MOUSE_BUTTON_LEFT:
		return


	if event.pressed:

		if event.double_click:
			doble_clic_detectado = true
			click_timer.stop()
		else:
			doble_clic_detectado = false

		iniciar_presion_mouse()

	else:

		finalizar_presion_mouse()


func iniciar_presion_mouse() -> void:

	if estado_actual in [
		Estado.FELIZ,
		Estado.COMIENDO,
		Estado.CANSADA,
		Estado.DURMIENDOSE,
		Estado.DORMIDA
	]:
		return


	mouse_presionado = true
	arrastrando = false

	blink_timer.stop()


	if parpadeando:

		parpadeando = false
		mascota.play("idle")


	posicion_mouse_inicial = DisplayServer.mouse_get_position()

	diferencia_mouse = (
		posicion_mouse_inicial
		- get_window().position
	)


func procesar_movimiento_mouse() -> void:

	if not mouse_presionado:
		return

	if arrastrando:
		return


	var posicion_actual := DisplayServer.mouse_get_position()

	var distancia := Vector2(posicion_actual).distance_to(
		Vector2(posicion_mouse_inicial)
	)


	if distancia >= distancia_arrastre:
		iniciar_arrastre()


func iniciar_arrastre() -> void:

	click_timer.stop()

	arrastrando = true
	doble_clic_detectado = false

	estado_actual = Estado.ARRASTRANDO

	parpadeando = false

	mascota.stop()
	mascota.play("idle")


func mover_con_mouse() -> void:

	get_window().position = (
		DisplayServer.mouse_get_position()
		- diferencia_mouse
	)


func finalizar_presion_mouse() -> void:

	if not mouse_presionado:
		return


	mouse_presionado = false


	if arrastrando:

		arrastrando = false
		doble_clic_detectado = false

		iniciar_descanso()

		return


	if doble_clic_detectado:

		doble_clic_detectado = false
		click_timer.stop()

		iniciar_felicidad()

		return


	click_timer.stop()
	click_timer.start()


func procesar_clic_simple() -> void:

	if arrastrando or mouse_presionado:
		return

	if estado_actual in [
		Estado.FELIZ,
		Estado.DORMIDA,
		Estado.DURMIENDOSE
	]:
		return

	iniciar_saludo()


# =========================================================
# DIÁLOGO
# =========================================================

func mostrar_dialogo(
	mensaje: String,
	duracion: float = 2.5
) -> void:

	texto_dialogo.text = mensaje

	dialogo.visible = true

	dialog_timer.stop()
	dialog_timer.wait_time = duracion
	dialog_timer.start()


func ocultar_dialogo() -> void:

	dialogo.visible = false


# =========================================================
# NECESIDADES
# =========================================================

func actualizar_necesidades() -> void:

	# -----------------------------------------------------
	# HAMBRE
	# -----------------------------------------------------

	hambre = clamp(
		hambre - perdida_hambre_por_segundo,
		0.0,
		100.0
	)


	# -----------------------------------------------------
	# ENERGÍA
	# -----------------------------------------------------

	if estado_actual == Estado.DORMIDA:

		# Bella recupera energía únicamente
		# cuando ya está completamente dormida.

		energia = clamp(
			energia + recuperacion_energia_sueno,
			0.0,
			100.0
		)

	else:

		energia = clamp(
			energia - perdida_energia_por_segundo,
			0.0,
			100.0
		)


	# -----------------------------------------------------
	# FELICIDAD
	# -----------------------------------------------------

	felicidad = clamp(
		felicidad - perdida_felicidad_por_segundo,
		0.0,
		100.0
	)


	# -----------------------------------------------------
	# DEBUG
	# -----------------------------------------------------

	print(
		"Hambre: ", snapped(hambre, 0.1),
		" | Energía: ", snapped(energia, 0.1),
		" | Felicidad: ", snapped(felicidad, 0.1),
		" | Afecto: ", snapped(afecto, 0.1),
		" | Estado: ", Estado.keys()[estado_actual]
	)


	# -----------------------------------------------------
	# DORMIDA
	# -----------------------------------------------------

	if estado_actual == Estado.DORMIDA:

		if energia >= energia_despertar:
			despertar()

		return


	# -----------------------------------------------------
	# DURMIENDOSE
	# -----------------------------------------------------

	if estado_actual == Estado.DURMIENDOSE:
		return


	evaluar_necesidades()


# =========================================================
# EVALUAR NECESIDADES
# =========================================================

func evaluar_necesidades() -> void:

	if mouse_presionado or arrastrando or parpadeando:
		return


	if estado_actual == Estado.INTERACTUANDO:
		return

	if estado_actual == Estado.FELIZ:
		return

	if estado_actual == Estado.COMIENDO:
		return

	if estado_actual == Estado.CANSADA:
		return

	if estado_actual == Estado.DURMIENDOSE:
		return

	if estado_actual == Estado.DORMIDA:
		return


	# =====================================================
	# PRIORIDAD 1 — SUEÑO
	# =====================================================

	if energia <= limite_sueno:

		if (
			estado_actual != Estado.DORMIDA
			and estado_actual != Estado.DURMIENDOSE
		):
			iniciar_sueno()

		return


	# =====================================================
	# PRIORIDAD 2 — HAMBRE
	# =====================================================

	if hambre <= limite_hambre:

		if estado_actual != Estado.HAMBRIENTA:
			iniciar_hambre()

		return


	# =====================================================
	# PRIORIDAD 3 — CANSANCIO
	# =====================================================

	if energia <= limite_energia:

		if estado_actual != Estado.CANSADA:
			iniciar_cansancio()

		return


# =========================================================
# ALIMENTAR
# =========================================================

func alimentar_bella() -> void:

	if estado_actual == Estado.COMIENDO:
		return

	if estado_actual == Estado.DORMIDA:
		return

	if estado_actual == Estado.DURMIENDOSE:
		return


	estado_actual = Estado.COMIENDO

	mouse_presionado = false
	arrastrando = false
	parpadeando = false
	doble_clic_detectado = false

	blink_timer.stop()
	click_timer.stop()

	mascota.flip_h = false
	mascota.stop()
	mascota.play("eat")


	mostrar_dialogo(
		"¡Gracias! Se ve delicioso 💖",
		2.5
	)

	print("Bella comenzó a comer")


# =========================================================
# FINALIZAR COMIDA
# =========================================================

func finalizar_comida() -> void:

	hambre = clamp(
		hambre + 40.0,
		0.0,
		100.0
	)


	felicidad = clamp(
		felicidad + 5.0,
		0.0,
		100.0
	)


	afecto = clamp(
		afecto + 2.0,
		0.0,
		100.0
	)


	mostrar_dialogo(
		"¡Estuvo muy rico! 😊",
		2.5
	)


	print(
		"Bella terminó de comer",
		" | Hambre: ", hambre,
		" | Felicidad: ", felicidad,
		" | Afecto: ", afecto
	)


	iniciar_descanso()


# =========================================================
# CANSANCIO
# =========================================================

func iniciar_cansancio() -> void:

	if estado_actual == Estado.CANSADA:
		return

	if estado_actual == Estado.DURMIENDOSE:
		return

	if estado_actual == Estado.DORMIDA:
		return


	estado_actual = Estado.CANSADA

	mouse_presionado = false
	arrastrando = false
	parpadeando = false
	doble_clic_detectado = false

	blink_timer.stop()
	click_timer.stop()

	mascota.flip_h = false
	mascota.stop()
	mascota.play("tired")


	var mensajes_cansancio: Array[String] = [
		"Tengo sueñito Noecito...",
		"Estoy un poquito cansada...",
		"¿Puedo descansar un ratito?...",
		"Creo que necesito dormir...",
		"Mis ojitos ya pesan..."
	]


	mostrar_dialogo(
		mensajes_cansancio.pick_random(),
		3.0
	)


	print("Bella está cansada")


# =========================================================
# INICIAR SUEÑO
# =========================================================

func iniciar_sueno() -> void:

	if estado_actual == Estado.DURMIENDOSE:
		return

	if estado_actual == Estado.DORMIDA:
		return


	# IMPORTANTE:
	# Todavía NO está dormida.
	# Está entrando en el estado de sueño.

	estado_actual = Estado.DURMIENDOSE

	mouse_presionado = false
	arrastrando = false
	parpadeando = false
	doble_clic_detectado = false

	blink_timer.stop()
	click_timer.stop()

	mascota.flip_h = false
	mascota.stop()

	# -----------------------------------------------------
	# TRANSICIÓN:
	#
	# 01 → 02 → 03 → 04
	#
	# sleep_start NO tiene loop.
	# -----------------------------------------------------

	mascota.play("sleep_start")


	mostrar_dialogo(
		"Ya no puedo más... tengo mucho sueñito 💤",
		3.0
	)


	print(
		"Bella se está quedando dormida",
		" | Energía: ",
		energia
	)


# =========================================================
# DESPERTAR
# =========================================================

func despertar() -> void:

	if estado_actual != Estado.DORMIDA:
		return


	estado_actual = Estado.IDLE
	tiempo_estado = tiempo_descanso

	mouse_presionado = false
	arrastrando = false
	parpadeando = false
	doble_clic_detectado = false

	mascota.flip_h = false
	mascota.stop()
	mascota.play("idle")

	mostrar_dialogo(
		"¡Dormí muy rico! ✨",
		2.5
	)

	programar_siguiente_parpadeo()

	print(
		"Bella despertó",
		" | Energía: ",
		energia
	)


# ==================================s=======================
# PRUEBA MANUAL DEL SUEÑO
# =========================================================

func probar_sueno() -> void:

	energia = 10.0

	iniciar_sueno()

	print("PRUEBA DE SUEÑO ACTIVADA")
