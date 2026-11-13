extends Node3D

# Pigeon Run - first playable prototype for Godot 4.
# Temporary procedural pigeon; replace its visual children with the user's
# original pigeon model when that image/model asset is added to the project.

const LANES := [-2.2, 0.0, 2.2]
const PLAYER_Z := 4.0
const WORLD_SPEED := 13.0

var player: CharacterBody3D
var lane := 1
var vertical_speed := 0.0
var gravity := 22.0
var jump_strength := 9.0
var score := 0
var seeds := 0
var spawn_clock := 0.0
var touch_start := Vector2.ZERO
var hud: Label
var score_label: Label
var spawned: Array[Node3D] = []

func _ready() -> void:
    _build_world()
    _build_player()
    _build_camera()
    _build_hud()
    randomize()

func _build_world() -> void:
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = Sky.new()
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72, 0.78, 0.72)
    env.ambient_light_energy = 0.8
    world_env.environment = env
    add_child(world_env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -28, 0)
    sun.light_energy = 1.15
    add_child(sun)

    var ground_body := StaticBody3D.new()
    ground_body.position = Vector3(0, -0.35, -45)
    var ground_shape := CollisionShape3D.new()
    var ground_box := BoxShape3D.new()
    ground_box.size = Vector3(8.5, 0.6, 115)
    ground_shape.shape = ground_box
    ground_body.add_child(ground_shape)
    add_child(ground_body)
    _add_box(self, Vector3(0, -0.35, -45), Vector3(8.5, 0.6, 115), Color(0.28, 0.34, 0.22))
    for x in [-1.1, 1.1]:
        _add_box(self, Vector3(x, 0.01, -45), Vector3(0.045, 0.025, 115), Color(0.78, 0.72, 0.52))
    for i in range(34):
        var z := -float(i) * 4.2
        for side in [-1.0, 1.0]:
            var x := side * randf_range(5.0, 8.5)
            _make_tree(Vector3(x, 0, z + randf_range(-1.0, 1.0)))

func _make_tree(pos: Vector3) -> void:
    var tree := Node3D.new()
    tree.position = pos
    add_child(tree)
    var trunk := _mesh_instance(CylinderMesh.new(), Vector3(0, 1.3, 0), Vector3(0.38, 1.3, 0.38), Color(0.28, 0.18, 0.11))
    tree.add_child(trunk)
    var crown := _mesh_instance(SphereMesh.new(), Vector3(0, 3.0, 0), Vector3(1.55, 2.0, 1.45), Color(0.13, 0.31 + randf() * 0.12, 0.16))
    tree.add_child(crown)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.position = Vector3(0, 0.75, PLAYER_Z)
    add_child(player)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.42
    capsule.height = 1.35
    collision.shape = capsule
    player.add_child(collision)

    # Simple white bird placeholder made from primitive meshes.
    var body := _mesh_instance(SphereMesh.new(), Vector3(0, 0.1, 0), Vector3(0.72, 0.52, 0.95), Color(0.96, 0.96, 0.91))
    player.add_child(body)
    var head := _mesh_instance(SphereMesh.new(), Vector3(0, 0.55, -0.28), Vector3(0.47, 0.47, 0.47), Color(1, 1, 0.97))
    player.add_child(head)
    var beak := _mesh_instance(ConeMesh.new(), Vector3(0, 0.53, -0.72), Vector3(0.22, 0.22, 0.22), Color(0.95, 0.58, 0.12))
    beak.rotation_degrees.x = 90
    player.add_child(beak)
    for side in [-1.0, 1.0]:
        var wing := _mesh_instance(SphereMesh.new(), Vector3(side * 0.43, 0.18, 0.03), Vector3(0.22, 0.12, 0.58), Color(0.88, 0.89, 0.86))
        wing.name = "Wing"
        player.add_child(wing)

func _build_camera() -> void:
    var camera := Camera3D.new()
    camera.position = Vector3(0, 5.2, 11.5)
    camera.rotation_degrees = Vector3(-17, 0, 0)
    camera.current = true
    add_child(camera)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    hud = Label.new()
    hud.position = Vector2(24, 28)
    hud.add_theme_font_size_override("font_size", 30)
    hud.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(hud)
    score_label = Label.new()
    score_label.position = Vector2(24, 75)
    score_label.add_theme_font_size_override("font_size", 22)
    score_label.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(score_label)
    _update_hud()

func _process(delta: float) -> void:
    spawn_clock += delta
    if spawn_clock > 1.05:
        spawn_clock = 0.0
        _spawn_object()
    for item in spawned.duplicate():
        item.position.z += WORLD_SPEED * delta
        if item.position.z > 11:
            spawned.erase(item)
            item.queue_free()
            continue
        if item.has_meta("seed") and item.position.distance_to(player.position) < 1.0:
            seeds += 1
            score += 10
            spawned.erase(item)
            item.queue_free()
            _update_hud()
        elif item.has_meta("obstacle") and item.position.distance_to(player.position) < 0.85:
            _game_over()

    score += int(delta * 5.0)
    _update_hud()

func _physics_process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    if not player.is_on_floor():
        vertical_speed -= gravity * delta
    else:
        vertical_speed = 0.0
    player.velocity.y = vertical_speed
    player.move_and_slide()
    var target_x: float = LANES[lane]
    player.position.x = move_toward(player.position.x, target_x, 12.0 * delta)

func _spawn_object() -> void:
    var lane_index := randi_range(0, 2)
    var z := -48.0
    if randf() < 0.67:
        var seed_mesh := _mesh_instance(SphereMesh.new(), Vector3.ZERO, Vector3(0.24, 0.24, 0.24), Color(0.92, 0.72, 0.12))
        var item := Node3D.new()
        item.position = Vector3(LANES[lane_index], 0.85, z)
        item.add_child(seed_mesh)
        item.set_meta("seed", true)
        add_child(item)
        spawned.append(item)
    else:
        var obstacle := Node3D.new()
        obstacle.position = Vector3(LANES[lane_index], 0.65, z)
        var block := _mesh_instance(BoxMesh.new(), Vector3.ZERO, Vector3(1.25, 1.3, 0.85), Color(0.48, 0.43, 0.37))
        obstacle.add_child(block)
        obstacle.set_meta("obstacle", true)
        add_child(obstacle)
        spawned.append(obstacle)

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_LEFT or event.keycode == KEY_A:
            _change_lane(-1)
        elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
            _change_lane(1)
        elif event.keycode == KEY_SPACE or event.keycode == KEY_UP:
            _jump()
    elif event is InputEventScreenTouch:
        if event.pressed:
            touch_start = event.position
        else:
            var swipe := event.position - touch_start
            if swipe.length() > 45:
                if abs(swipe.x) > abs(swipe.y):
                    _change_lane(1 if swipe.x > 0 else -1)
                elif swipe.y < 0:
                    _jump()

func _change_lane(direction: int) -> void:
    lane = clampi(lane + direction, 0, 2)

func _jump() -> void:
    if player.is_on_floor():
        vertical_speed = jump_strength

func _game_over() -> void:
    # Prototype feedback; restart the run after a short pause is a later task.
    hud.text = "برخورد! برای شروع دوباره بازی را اجرا کن"
    set_process(false)
    set_physics_process(false)

func _update_hud() -> void:
    if is_instance_valid(hud):
        hud.text = "PIGEON RUN"
        score_label.text = "امتیاز: %d    ارزن: %d" % [score, seeds]

func _mesh_instance(mesh: Mesh, pos: Vector3, scale_value: Vector3, color: Color) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.position = pos
    instance.scale = scale_value
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    instance.material_override = material
    return instance

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
    var box := _mesh_instance(BoxMesh.new(), pos, size, color)
    parent.add_child(box)
