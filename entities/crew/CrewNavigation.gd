class_name CrewNavigation
extends Object

# Shared movement directions
const DIRECTIONS = {
	UP = Vector2(0, -1),
	UP_RIGHT = Vector2(1, -1),
	RIGHT = Vector2(1, 0),
	DOWN_RIGHT = Vector2(1, 1),
	DOWN = Vector2(0, 1),
	DOWN_LEFT = Vector2(-1, 1),
	LEFT = Vector2(-1, 0),
	UP_LEFT = Vector2(-1, -1)
}

# --- Targeting and path setup -------------------------------------------------

static func set_movement_target(crew, movement_target: Vector2) -> void:
	crew._original_target = movement_target
	crew._final_destination = movement_target
	crew._wall_collision_count = 0
	crew._wall_collision_timer = 0.0
	crew._alternative_waypoints.clear()
	crew._current_waypoint_index = 0
	if crew.crew_movement:
		crew.crew_movement.set_movement_target(movement_target)
	else:
		crew.navigation_agent.target_position = movement_target


static func find_alternative_route(crew, blocked_target: Vector2) -> Vector2:
	var directions: Array[Vector2] = [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)
	]
	var distance: float = crew.global_position.distance_to(blocked_target)
	var step_size: float = 200.0
	var max_steps = 3
	for direction in directions:
		for i in range(1, min(max_steps, int(distance / step_size) + 1)):
			var test_target: Vector2 = crew.global_position + direction * (step_size * i)
			if check_path_for_static_obstacles(crew, test_target):
				return test_target
	return Vector2.ZERO


static func validate_current_path(crew) -> void:
	if crew._is_on_assignment():
		return
	if crew.navigation_agent.is_navigation_finished():
		return
	var current_path = crew.navigation_agent.get_current_navigation_path()
	if current_path.size() < 2:
		return
	var next_target = crew.navigation_agent.get_next_path_position()
	if not check_path_for_static_obstacles(crew, next_target):
		var alternative: Vector2 = _find_smart_alternative_route(crew, crew._final_destination)
		if alternative != Vector2.ZERO:
			crew._alternative_waypoints.clear()
			crew._alternative_waypoints.append(alternative)
			crew._alternative_waypoints.append(crew._final_destination)
			crew._current_waypoint_index = 0
			crew.navigation_agent.target_position = alternative
		else:
			var around_obstacle: Vector2 = find_route_around_obstacle(crew, crew.global_position, next_target)
			if around_obstacle != Vector2.ZERO:
				crew.navigation_agent.target_position = around_obstacle


static func find_route_around_obstacle(crew, start: Vector2, blocked_end: Vector2) -> Vector2:
	var direction_to_target = (blocked_end - start).normalized()
	var perpendicular = Vector2(-direction_to_target.y, direction_to_target.x)
	for side in [-1, 1]:
		var around_point = start + perpendicular * side * 400.0
		if check_path_for_static_obstacles(crew, around_point):
			return around_point
	return Vector2.ZERO


static func set_rounded_direction(crew) -> void:
	var next_point: Vector2 = crew.navigation_agent.get_next_path_position()
	if next_point == Vector2.ZERO:
		next_point = crew.global_position
	var to_next = (next_point - crew.global_position)
	if to_next == Vector2.ZERO:
		crew.current_move_direction = Vector2.ZERO
		return
	var move_quantized = snap_to_eight_directions(to_next)
	crew.current_move_direction = move_quantized
	var next_pos = crew.navigation_agent.get_next_path_position()
	if crew.current_animation_direction == Vector2.ZERO:
		crew.current_animation_direction = move_quantized
		crew.current_path_waypoint = next_pos
		return
	if crew.current_path_waypoint.distance_to(next_pos) <= 0.1:
		return
	crew.current_animation_direction = move_quantized
	crew.current_path_waypoint = next_pos


static func snap_to_eight_directions(vec: Vector2) -> Vector2:
	if vec == Vector2.ZERO:
		return Vector2.ZERO
	var normalized_vec = vec.normalized()
	var best_direction = DIRECTIONS.RIGHT
	var best_dot_product = -INF
	var directions: Array[Vector2] = [
		DIRECTIONS.RIGHT, DIRECTIONS.UP_RIGHT, DIRECTIONS.UP, DIRECTIONS.UP_LEFT,
		DIRECTIONS.LEFT, DIRECTIONS.DOWN_LEFT, DIRECTIONS.DOWN, DIRECTIONS.DOWN_RIGHT
	]
	for direction in directions:
		var dot_product = normalized_vec.dot(direction.normalized())
		if dot_product > best_dot_product:
			best_dot_product = dot_product
			best_direction = direction
	return best_direction


static func randomise_target_position(crew) -> void:
	const MIN_DISTANCE = 200.0
	var attempts = 0
	const MAX_ATTEMPTS = 10
	while attempts < MAX_ATTEMPTS:
		crew.target = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
		if crew.position.distance_to(crew.target) >= MIN_DISTANCE:
			set_movement_target(crew, crew.target)
			if crew.navigation_agent.is_target_reachable():
				return
		attempts += 1
	crew.target = Vector2(randf_range(2500.0, 6500.0), randf_range(1500.0, 3000.0))
	set_movement_target(crew, crew.target)


# --- Walking processing ------------------------------------------------------

static func process_walking_state(crew, _delta: float) -> void:
	crew._update_depth_sorting()
	if crew.assignment == &"work" and not crew._is_flow_following:
		crew._transition_to_work()
		return
	if crew._wall_collision_timer > 0:
		crew._wall_collision_timer -= _delta
		crew.velocity = Vector2.ZERO
		crew.current_move_direction = Vector2.ZERO
		crew.current_animation_direction = Vector2.ZERO
		return
	if crew.crew_vigour.should_rest() or crew.crew_vigour.is_resting:
		crew.crew_vigour.process_resting(_delta, crew.current_animation_direction, crew.current_move_direction)
		crew.velocity = Vector2.ZERO
		crew.current_move_direction = Vector2.ZERO
		crew.current_animation_direction = crew.crew_vigour.get_resting_direction()
		return
	if not crew._is_flow_following:
		var reached_leg := false
		if crew._is_on_assignment() and crew.assignment_path.size() > 0:
			var leg_goal: Vector2 = crew.assignment_path[crew.assignment_path.size() - 1]
			reached_leg = crew.global_position.distance_to(leg_goal) <= crew.ASSIGNMENT_WAYPOINT_EPS
		else:
			reached_leg = crew.navigation_agent.is_navigation_finished()
		if reached_leg:
			if not crew.pending_waypoints.is_empty():
				var next_target: Vector2 = crew.pending_waypoints.pop_front()
				set_movement_target(crew, next_target)
				await crew.get_tree().physics_frame
				_snapshot_agent_path(crew)
				return
			if not crew._alternative_waypoints.is_empty() and crew._current_waypoint_index < crew._alternative_waypoints.size():
				var next_waypoint: Vector2 = crew._alternative_waypoints[crew._current_waypoint_index]
				crew._current_waypoint_index += 1
				crew.navigation_agent.target_position = next_waypoint
				return
			if crew.assignment == &"" and crew.walk_segments_remaining > 1:
				crew.walk_segments_remaining -= 1
				randomise_target_position(crew)
				return
			else:
				if crew._saved_path_max_distance >= 0.0:
					crew.navigation_agent.path_max_distance = crew._saved_path_max_distance
					crew._saved_path_max_distance = -1.0
					crew.navigation_agent.avoidance_enabled = crew._saved_avoidance_enabled
					crew.navigation_agent.path_postprocessing = crew._saved_postprocessing
				if crew.furniture_workplace != null and crew._assignment_target_tile != Vector2i.ZERO:
					var goal_world: Vector2 = crew._nav_grid.tile_center_world(crew._assignment_target_tile)
					if crew.global_position.distance_to(goal_world) <= 32.0:
						crew._transition_to_work()
						return
					crew.navigation_agent.target_position = goal_world
					crew.state_manager.send_event(&"walk")
					return
				if crew.furniture_workplace == null:
					crew.state_manager.send_event(&"to_assignment")
				return
	if crew._is_flow_following and crew._flow_step_target != Vector2i.ZERO:
		if crew._oscillation_cooldown > 0.0:
			crew._oscillation_cooldown -= _delta
			crew.velocity = Vector2.ZERO
			crew.current_move_direction = Vector2.ZERO
			return
		if crew._assignment_target_tile != Vector2i.ZERO and crew._flow_wander_goal == crew._assignment_target_tile:
			var current_tile: Vector2i = crew._nav_grid.world_to_tile(crew.global_position)
			if current_tile == crew._assignment_target_tile:
				crew.velocity = Vector2.ZERO
				crew.current_move_direction = Vector2.ZERO
				crew._transition_to_work()
				return
			var target_world: Vector2 = crew._nav_grid.tile_center_world(crew._assignment_target_tile)
			if crew.global_position.distance_to(target_world) <= 48.0:
				crew.global_position = target_world
				crew.velocity = Vector2.ZERO
				crew.current_move_direction = Vector2.ZERO
				crew._transition_to_work()
				return
		var target_world: Vector2 = crew._nav_grid.tile_center_world(crew._flow_step_target)
		var to_target: Vector2 = target_world - crew.global_position
		var dist_to_next: float = to_target.length()
		if dist_to_next > 4.0:
			crew.current_move_direction = snap_to_eight_directions(to_target)
			crew.current_animation_direction = crew.current_move_direction
			var current_tile: Vector2i = crew._nav_grid.world_to_tile(crew.global_position)
			if crew._last_tile != current_tile:
				crew._last_tile = current_tile
				crew._oscillation_count = 0
				crew._tile_history.append(current_tile)
				if crew._tile_history.size() > crew.TILE_HISTORY_SIZE:
					crew._tile_history.pop_front()
				if crew._tile_history.size() >= crew.TILE_HISTORY_SIZE:
					var is_oscillating := false
					if (crew._tile_history[0] == crew._tile_history[2] and 
						crew._tile_history[1] == crew._tile_history[3] and 
						crew._tile_history[0] != crew._tile_history[1]):
						is_oscillating = true
					if is_oscillating:
						var tile_a: Vector2i = crew._tile_history[0]
						var tile_b: Vector2i = crew._tile_history[1]
						var dir_between: Vector2i = tile_b - tile_a
						var perpendicular := Vector2i(-dir_between.y, dir_between.x)
						var avoid_tile := Vector2i.ZERO
						if _is_viable_transition(crew, current_tile, current_tile + perpendicular):
							avoid_tile = current_tile + perpendicular
						elif _is_viable_transition(crew, current_tile, current_tile - perpendicular):
							avoid_tile = current_tile - perpendicular
						if avoid_tile != Vector2i.ZERO:
							print("[AssignFlow][oscillation] Breaking corner oscillation at ", current_tile, " - forcing recalculation")
							var curr_tile_center: Vector2 = crew._nav_grid.tile_center_world(current_tile)
							crew.global_position = curr_tile_center
							crew.velocity = Vector2.ZERO
							crew.current_move_direction = Vector2.ZERO
							crew._flow_step_target = Vector2i.ZERO
							crew._tile_history.clear()
							crew._oscillation_count = 0
							if is_instance_valid(crew._flow_timer):
								crew._flow_timer.stop()
								on_flow_timer_timeout(crew)
							return
						print("[AssignFlow][oscillation] Detected between ", tile_a, " and ", tile_b, " - pausing (no avoidance path found)")
						var curr_tile_center: Vector2 = crew._nav_grid.tile_center_world(current_tile)
						crew.global_position = curr_tile_center
						crew.velocity = Vector2.ZERO
						crew.current_move_direction = Vector2.ZERO
						crew._tile_history.clear()
						crew._oscillation_count = 0
						crew._oscillation_cooldown = crew.OSCILLATION_COOLDOWN_DURATION
						if is_instance_valid(crew._flow_timer):
							crew._flow_timer.stop()
							crew._flow_timer.start()
						return
		else:
			crew.current_move_direction = Vector2.ZERO
			if is_instance_valid(crew._flow_timer):
				on_flow_timer_timeout(crew)
	else:
		set_rounded_direction(crew)
	if not crew._is_flow_following:
		crew._path_validation_accum += _delta
		if crew._path_validation_accum >= crew.PATH_VALIDATION_INTERVAL:
			validate_current_path(crew)
			crew._path_validation_accum = 0.0
	update_avoidance(crew, _delta)
	if crew._avoidance_offset != Vector2.ZERO:
		crew.current_move_direction += crew._avoidance_offset.normalized() * 0.3
	var fatigue_scale = crew.crew_vigour.get_fatigue_scale()
	var current_speed_scale: float = crew.speed_multiplier * fatigue_scale
	var desired_velocity: Vector2 = crew.current_move_direction.normalized() * (crew.speed * current_speed_scale)
	if desired_velocity.length() > 0.1:
		var proposed_facing := snap_to_eight_directions(desired_velocity)
		if crew.current_animation_direction == Vector2.ZERO or proposed_facing.dot(crew.current_animation_direction) < 0.995:
			crew.current_animation_direction = proposed_facing
	if crew._is_flow_following and crew._flow_step_target != Vector2i.ZERO:
		var target_pos: Vector2 = crew._nav_grid.tile_center_world(crew._flow_step_target)
		var distance_to_target: float = crew.global_position.distance_to(target_pos)
		if distance_to_target < 64.0:
			var slowdown_factor: float = clamp(distance_to_target / 64.0, 0.3, 1.0)
			var max_speed: float = (distance_to_target / crew.get_physics_process_delta_time()) * slowdown_factor
			if desired_velocity.length() > max_speed:
				desired_velocity = desired_velocity.normalized() * max_speed
	crew.velocity = desired_velocity
	var collision = crew.move_and_collide(crew.velocity)
	if collision:
		_handle_wall_collision(crew, collision)
		if crew.crew_speech:
			crew.crew_speech.say_collision_phrase(collision.get_collider())
	if crew._is_on_assignment() and not crew._is_flow_following:
		var np: Vector2 = crew.navigation_agent.get_next_path_position()
		var current_tile: Vector2i = crew._nav_grid.world_to_tile(crew.global_position)
		if current_tile == crew._last_tile:
			crew._oscillation_count += 1
		else:
			crew._oscillation_count = 0
			crew._last_tile = current_tile
		if crew._oscillation_count >= 6:
			var step := _choose_side_step(crew, current_tile, crew._nav_grid.world_to_tile(np))
			if step != Vector2i.ZERO:
				var w: Vector2 = crew._nav_grid.tile_center_world(step)
				crew.navigation_agent.target_position = w
				crew._oscillation_count = 0


static func _snapshot_agent_path(crew) -> void:
	crew.assignment_path.clear()
	crew.assignment_path_idx = 0
	var path: Array[Vector2] = crew.navigation_agent.get_current_navigation_path()
	for p in path:
		crew.assignment_path.append(p)
	while crew.assignment_path.size() > 1 and crew.assignment_path_idx < crew.assignment_path.size() - 1:
		if crew.global_position.distance_to(crew.assignment_path[crew.assignment_path_idx]) <= crew.ASSIGNMENT_WAYPOINT_EPS:
			crew.assignment_path_idx += 1
		else:
			break


# --- Flow / assignment -------------------------------------------------------

static func assign_to_furniture_via_flow(crew, furniture) -> void:
	if furniture == null:
		return
	crew.furniture_workplace = furniture
	crew._reset_unreachable_attempts()
	var flow_targets: FlowTargets = crew.FlowTargetsScript.new()
	var candidates: Array[Vector2i] = flow_targets.furniture_access_tiles(furniture)
	var reserved: Vector2i = furniture.reserve_access_tile_for_crew(crew, candidates)
	crew._assignment_target_tile = reserved if reserved != Vector2i.ZERO else Vector2i.ZERO
	if crew._assignment_target_tile != Vector2i.ZERO:
		crew._flow_wander_goal = crew._assignment_target_tile
		var r: Room = furniture.get_parent() if (furniture.get_parent() is Room) else null
		var rid: int = r.data.id if (r and r.data) else -1
		if crew.ASSIGN_DEBUG:
			print("[AssignFlow] crew=", crew.get_instance_id(), " reserved=", crew._assignment_target_tile, " furniture=", furniture.name, " room_id=", rid)
		if crew.debug_assignment_flow:
			crew._setup_assignment_debug_canvas()
	crew._is_flow_following = true
	crew._flow_furniture = furniture
	crew._flow_step_target = Vector2i.ZERO
	crew._last_tile = Vector2i.ZERO
	crew._flow_wander_goal = crew._assignment_target_tile
	crew._tile_history.clear()
	crew._oscillation_count = 0
	crew._oscillation_cooldown = 0.0
	crew._cached_room_id_for_tile.clear()
	crew._cached_seeds_key = ""
	crew.navigation_agent.avoidance_enabled = true
	crew.navigation_agent.path_postprocessing = 1
	_ensure_flow_timer(crew)
	on_flow_timer_timeout(crew)
	crew._flow_timer.start()
	crew.state_manager.send_event(&"walk")


static func _ensure_flow_timer(crew) -> void:
	if is_instance_valid(crew._flow_timer):
		return
	var flow_timer_node := Timer.new()
	flow_timer_node.name = "FlowFollowTimer"
	flow_timer_node.one_shot = true
	flow_timer_node.autostart = false
	flow_timer_node.wait_time = 0.15
	crew.add_child(flow_timer_node)
	flow_timer_node.timeout.connect(func(): on_flow_timer_timeout(crew))
	crew._flow_timer = flow_timer_node
	crew._cached_field = null
	crew._cached_field_goal = Vector2i.ZERO
	crew._cached_field_room_id = -1
	crew._cached_field_version = -1
	crew._cached_nav_version = -1
	crew._cached_furn_version = -1
	crew._cached_seeds_key = ""


static func on_flow_timer_timeout(crew) -> void:
	if crew.assignment == &"work" or crew.state == crew.STATE.WORK:
		_stop_flow_follow(crew)
		return
	if crew._assignment_target_tile != Vector2i.ZERO:
		crew._flow_wander_goal = crew._assignment_target_tile
		crew._is_flow_following = true
	elif crew._flow_wander_goal == Vector2i.ZERO:
		if Global and Global.wander_beacons:
			var beacon_tile: Vector2i = Global.wander_beacons.pick_beacon_for_crew()
			if beacon_tile != Vector2i.ZERO:
				crew._flow_wander_goal = Global.wander_beacons.jitter(beacon_tile, 2)
		if crew._flow_wander_goal == Vector2i.ZERO:
			crew._flow_wander_goal = crew._nav_grid.random_walkable_tile()
	var curr_tile: Vector2i = crew._nav_grid.world_to_tile(crew.global_position)
	if crew._is_flow_following and crew._flow_step_target != Vector2i.ZERO:
		var target_world: Vector2 = crew._nav_grid.tile_center_world(crew._flow_step_target)
		if crew.global_position.distance_to(target_world) > 8.0:
			crew._flow_timer.start()
			return
		curr_tile = crew._flow_step_target
	var field: FlowFieldService.FlowField = null
	if crew._assignment_target_tile != Vector2i.ZERO:
		var furniture_room: Room = crew._get_furniture_room()
		var seeds: Array[Vector2i] = []
		var furniture_room_id: int = crew._get_furniture_room_id()
		var crew_room_id: int = crew._cached_room_id_for_tile.get(curr_tile, -999)
		if crew_room_id == -999:
			crew_room_id = Room.find_tile_room_id(curr_tile)
			crew._cached_room_id_for_tile[curr_tile] = crew_room_id
		var is_on_door_tile: bool = false
		if furniture_room:
			is_on_door_tile = furniture_room.data.door_tiles.has(curr_tile)
			if crew_room_id != furniture_room_id and not is_on_door_tile:
				seeds = crew._flow_targets.door_tiles(furniture_room)
				if seeds.is_empty():
					if crew.ASSIGN_DEBUG:
						print("[AssignFlow][error] no door seeds for room ", furniture_room_id, " crew=", crew.get_instance_id(), " curr=", curr_tile)
					if crew._mark_unreachable_attempt():
						return
					crew._flow_timer.start()
					return
				field = _get_or_build_flow_field(crew, seeds, null)
			else:
				seeds = [crew._assignment_target_tile]
				field = _get_or_build_flow_field(crew, seeds, furniture_room)
			if crew.ASSIGN_DEBUG:
				print("[AssignFlow][seed] crew=", crew.get_instance_id(), " curr_room=", crew_room_id, " furniture_room=", furniture_room_id, " on_door=", is_on_door_tile, " seeds=", seeds.size())
		else:
			seeds = [crew._assignment_target_tile]
			field = _get_or_build_flow_field(crew, seeds, null)
			if crew.ASSIGN_DEBUG:
				print("[AssignFlow][seed] crew=", crew.get_instance_id(), " no room context; seed furniture tile ", crew._assignment_target_tile)
		crew._debug_flow_field = field
	else:
		field = _get_or_build_flow_field(crew, [crew._flow_wander_goal], null)
	if field == null:
		if crew.ASSIGN_DEBUG:
			print("[AssignFlow][error] no field for crew=", crew.get_instance_id(), " goal=", crew._flow_wander_goal)
		if crew._assignment_target_tile != Vector2i.ZERO:
			if crew._mark_unreachable_attempt():
				return
		crew._flow_timer.start()
		return
	var next_tile: Vector2i = crew._flow_service.get_next_tile(field, curr_tile)
	if crew.ASSIGN_DEBUG and crew._assignment_target_tile != Vector2i.ZERO:
		var dir_vec: Vector2i = Vector2i.ZERO
		var distance_val: int = -1
		if field != null:
			dir_vec = field.direction.get(curr_tile, Vector2i.ZERO)
			distance_val = field.distance.get(curr_tile, -1)
		print("[AssignFlow][step] crew=", crew.get_instance_id(), " curr=", curr_tile, " next=", next_tile, " dir=", dir_vec, " dist=", distance_val, " goal=", crew._assignment_target_tile)
	if field != null:
		var curr_dist: int = field.distance.get(curr_tile, INF)
		if curr_dist == INF and crew._assignment_target_tile != Vector2i.ZERO:
			if crew._mark_unreachable_attempt():
				return
			return
		var best_tile := next_tile
		var best_dist := curr_dist
		var candidates: Array[Vector2i] = [
			curr_tile + Vector2i(0, -1),
			curr_tile + Vector2i(1, 0),
			curr_tile + Vector2i(0, 1),
			curr_tile + Vector2i(-1, 0)
		]
		for cand: Vector2i in candidates:
			if not field.distance.has(cand):
				continue
			if not crew._nav_grid.is_walkable(cand):
				continue
			if not crew._nav_grid.can_traverse(curr_tile, cand):
				continue
			var d: int = field.distance[cand]
			if d < best_dist:
				best_dist = d
				best_tile = cand
		if best_tile != next_tile and crew.ASSIGN_DEBUG and crew._assignment_target_tile != Vector2i.ZERO:
			print("[AssignFlow][adjust] crew=", crew.get_instance_id(), " curr=", curr_tile, " flow_next=", next_tile, " adjusted_next=", best_tile, " curr_dist=", curr_dist, " best_dist=", best_dist)
		next_tile = best_tile
	if crew._assignment_target_tile != Vector2i.ZERO and crew._flow_wander_goal == crew._assignment_target_tile:
		if curr_tile == crew._assignment_target_tile:
			var target_world: Vector2 = crew._nav_grid.tile_center_world(crew._assignment_target_tile)
			if crew.global_position.distance_to(target_world) <= 4.0:
				if crew.ASSIGN_DEBUG:
					print("[AssignFlow][arrive] crew=", crew.get_instance_id(), " tile=", curr_tile, " dist_to_center=", crew.global_position.distance_to(target_world))
				crew.global_position = target_world
				crew._transition_to_work()
				return
			next_tile = crew._assignment_target_tile
		elif next_tile == curr_tile or next_tile == Vector2i.ZERO:
			var nudged := _find_viable_neighbor_toward_goal(crew, curr_tile, crew._assignment_target_tile)
			if nudged != Vector2i.ZERO:
				next_tile = nudged
			else:
				if crew.ASSIGN_DEBUG:
					print("[AssignFlow][stall] crew=", crew.get_instance_id(), " curr=", curr_tile, " goal=", crew._assignment_target_tile, " at_door=", crew._nav_grid.is_door_tile(curr_tile))
				if crew._mark_unreachable_attempt():
					return
				crew._flow_timer.start()
				return
	if crew._assignment_target_tile == Vector2i.ZERO and (next_tile == curr_tile or next_tile == Vector2i.ZERO):
		if Global and Global.wander_beacons and crew._flow_wander_goal != Vector2i.ZERO:
			Global.wander_beacons.release_beacon(crew._flow_wander_goal)
		crew._flow_wander_goal = Vector2i.ZERO
		crew._flow_timer.start()
		return
	if next_tile == Vector2i.ZERO:
		if crew._assignment_target_tile != Vector2i.ZERO:
			if crew._mark_unreachable_attempt():
				return
		crew._flow_timer.start()
		return
	var next_world: Vector2 = crew._nav_grid.tile_center_world(next_tile)
	if next_tile != crew._flow_step_target or crew.navigation_agent.target_position != next_world:
		crew._flow_step_target = next_tile
		crew.navigation_agent.target_position = next_world
	crew._reset_unreachable_attempts()
	crew.state_manager.send_event(&"walk")
	crew._flow_timer.start()


static func _stop_flow_follow(crew) -> void:
	crew._is_flow_following = false
	crew._flow_furniture = null
	crew._flow_wander_goal = Vector2i.ZERO
	crew._flow_step_target = Vector2i.ZERO
	crew._tile_history.clear()
	crew._oscillation_count = 0
	crew._oscillation_cooldown = 0.0
	crew._reset_unreachable_attempts()
	crew._teardown_assignment_debug_canvas()
	if is_instance_valid(crew._flow_timer):
		crew._flow_timer.stop()


static func _start_flow_wander(crew) -> void:
	_ensure_flow_timer(crew)
	crew._is_flow_following = false
	crew._flow_furniture = null
	crew._flow_step_target = Vector2i.ZERO
	crew._last_tile = Vector2i.ZERO
	if crew._flow_wander_goal == Vector2i.ZERO:
		crew._flow_wander_goal = crew._nav_grid.random_walkable_tile()
	on_flow_timer_timeout(crew)
	crew._flow_timer.start()


static func _choose_side_step(crew, from_tile: Vector2i, to_tile: Vector2i) -> Vector2i:
	var dir := to_tile - from_tile
	var left := Vector2i(-dir.y, dir.x)
	var right := Vector2i(dir.y, -dir.x)
	var cand1 := from_tile + left.sign()
	var cand2 := from_tile + right.sign()
	if _is_viable_transition(crew, from_tile, cand1):
		return cand1
	if _is_viable_transition(crew, from_tile, cand2):
		return cand2
	return Vector2i.ZERO


static func _is_viable_transition(crew, from_tile: Vector2i, to_tile: Vector2i) -> bool:
	if not crew._nav_grid.is_walkable(to_tile):
		return false
	if not crew._nav_grid.can_traverse(from_tile, to_tile):
		return false
	return true


static func _find_viable_neighbor_toward_goal(crew, curr_tile: Vector2i, goal_tile: Vector2i) -> Vector2i:
	var dirs: Array[Vector2i] = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)]
	var best_tile := Vector2i.ZERO
	var best_dist := INF
	for dir: Vector2i in dirs:
		var neighbor: Vector2i = curr_tile + dir
		if not crew._nav_grid.is_walkable(neighbor):
			continue
		if not crew._nav_grid.can_traverse(curr_tile, neighbor):
			continue
		var neighbor_world: Vector2 = crew._nav_grid.tile_center_world(neighbor)
		var goal_world: Vector2 = crew._nav_grid.tile_center_world(goal_tile)
		var curr_world: Vector2 = crew._nav_grid.tile_center_world(curr_tile)
		var dist_to_goal := neighbor_world.distance_to(goal_world)
		var curr_dist_to_goal := curr_world.distance_to(goal_world)
		if dist_to_goal < curr_dist_to_goal or best_tile == Vector2i.ZERO:
			if dist_to_goal < best_dist:
				best_dist = dist_to_goal
				best_tile = neighbor
	return best_tile


static func _get_or_build_flow_field(crew, seeds: Array[Vector2i], room: Room) -> FlowFieldService.FlowField:
	if seeds.is_empty():
		return null
	var goal := seeds[0]
	var room_id := room.data.id if (room and room.data) else -1
	var seeds_key := str(goal.x) + ":" + str(goal.y) + ":" + str(room_id)
	if crew._cached_field != null and crew._cached_seeds_key == seeds_key and crew._cached_field_room_id == room_id and crew._cached_field_goal == goal:
		return crew._cached_field
	var field: FlowFieldService.FlowField = crew._flow_service.get_field_for_seeds(seeds, room)
	crew._cached_field = field
	crew._cached_field_goal = goal
	crew._cached_field_room_id = room_id
	crew._cached_field_version = field.version if field != null else -1
	crew._cached_seeds_key = seeds_key
	return field


# --- Collision / avoidance ---------------------------------------------------

static func check_path_for_static_obstacles(crew, target_pos: Vector2) -> bool:
	var space_state = crew.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(crew.global_position, target_pos)
	query.collision_mask = crew.COLLISION_LAYERS.OBSTACLES
	query.exclude = [crew]
	var result = space_state.intersect_ray(query)
	return result.is_empty()


static func _is_segment_clear(crew, from_pos: Vector2, to_pos: Vector2) -> bool:
	var space_state = crew.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	query.collision_mask = crew.COLLISION_LAYERS.OBSTACLES
	query.exclude = [crew]
	var result = space_state.intersect_ray(query)
	return result.is_empty()


static func _agent_has_active_path(crew) -> bool:
	var next_pos: Vector2 = crew.navigation_agent.get_next_path_position()
	if next_pos != Vector2.ZERO:
		return true
	var path: Array[Vector2] = crew.navigation_agent.get_current_navigation_path()
	return path.size() >= 2


static func check_for_crew_collisions(crew) -> Vector2:
	var space_state = crew.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(crew.global_position, crew.global_position + crew.current_move_direction * 64.0)
	query.collision_mask = crew.COLLISION_LAYERS.CREW
	query.exclude = [crew]
	var result = space_state.intersect_ray(query)
	if not result.is_empty():
		if result.collider.has_method("get") and result.collider.get("collision_layer") != null:
			var collider_layer = result.collider.get("collision_layer")
			if collider_layer & crew.COLLISION_LAYERS.CREW:
				var perpendicular = Vector2(-crew.current_move_direction.y, crew.current_move_direction.x)
				if randf() < 0.5:
					perpendicular = -perpendicular
				return perpendicular * crew.AVOIDANCE_DISTANCE
	return Vector2.ZERO


static func update_avoidance(crew, _delta: float) -> void:
	if crew._avoidance_timer > 0:
		crew._avoidance_timer -= _delta
		if crew._avoidance_timer <= 0:
			crew._avoidance_offset = Vector2.ZERO
	else:
		crew._avoidance_check_accum += _delta
		if crew._avoidance_check_accum >= crew.AVOIDANCE_CHECK_INTERVAL:
			var new_offset = check_for_crew_collisions(crew)
			if new_offset != Vector2.ZERO:
				crew._avoidance_offset = new_offset
				crew._avoidance_timer = crew.AVOIDANCE_DURATION
			crew._avoidance_check_accum = 0.0


static func _handle_wall_collision(crew, collision: KinematicCollision2D) -> void:
	if crew._is_on_assignment():
		crew._flow_step_target = Vector2i.ZERO
		on_flow_timer_timeout(crew)
		return
	var collider = collision.get_collider()
	var is_wall_collision = false
	if collider is TileMap:
		is_wall_collision = true
	elif collider and collider.has_method("get") and collider.get("collision_layer") != null:
		var collider_layer = collider.get("collision_layer")
		if collider_layer & crew.COLLISION_LAYERS.OBSTACLES:
			is_wall_collision = true
	if is_wall_collision:
		if crew._wall_collision_timer <= 0:
			crew._wall_collision_count += 1
			if crew._wall_collision_count <= crew.MAX_WALL_COLLISIONS:
				crew._wall_collision_timer = crew.WALL_COLLISION_PAUSE
			else:
				_attempt_repath_around_obstacle(crew)


static func _attempt_repath_around_obstacle(crew) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var time_since_last: float = now - crew._last_pathfinding_time
	if time_since_last < crew.PATHFINDING_COOLDOWN:
		return
	crew._last_pathfinding_time = now
	var alternative_target = _find_smart_alternative_route(crew, crew._final_destination)
	if alternative_target != Vector2.ZERO:
		crew._alternative_waypoints.clear()
		crew._alternative_waypoints.append(alternative_target)
		crew._alternative_waypoints.append(crew._final_destination)
		crew._current_waypoint_index = 0
		crew.navigation_agent.target_position = alternative_target
		crew._wall_collision_count = 0
	else:
		var closest_reachable = _find_closest_reachable_point(crew, crew._final_destination)
		if closest_reachable != Vector2.ZERO:
			crew._alternative_waypoints.clear()
			crew._alternative_waypoints.append(closest_reachable)
			crew._alternative_waypoints.append(crew._final_destination)
			crew._current_waypoint_index = 0
			crew.navigation_agent.target_position = closest_reachable
			crew._wall_collision_count = 0
		else:
			crew.navigation_agent.target_position = crew.global_position


static func _find_circuitous_route(crew, destination: Vector2) -> Vector2:
	var directions: Array[Vector2] = [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)
	]
	var current_pos: Vector2 = crew.global_position
	var distance_to_dest: float = current_pos.distance_to(destination)
	var step_size: float = 200.0
	var max_steps = 5
	for direction in directions:
		for i in range(1, max_steps + 1):
			var test_target: Vector2 = current_pos + direction * (step_size * i)
			if check_path_for_static_obstacles(crew, test_target):
				if _can_reach_destination_from(crew, test_target, destination):
					return test_target
	return Vector2.ZERO


static func _can_reach_destination_from(crew, start: Vector2, destination: Vector2) -> bool:
	var space_state = crew.get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start, destination)
	query.collision_mask = crew.COLLISION_LAYERS.OBSTACLES
	query.exclude = [crew]
	var result = space_state.intersect_ray(query)
	return result.is_empty()


static func _find_smart_alternative_route(crew, destination: Vector2) -> Vector2:
	var current_pos = crew.global_position
	var room_based_route: Vector2 = _try_room_based_pathfinding(crew, current_pos, destination)
	if room_based_route != Vector2.ZERO:
		return room_based_route
	return _find_multi_step_route_with_avoidance(crew, current_pos, destination)


static func _try_room_based_pathfinding(crew, start: Vector2, destination: Vector2) -> Vector2:
	var dest_room = _get_room_containing_point(crew, destination)
	if dest_room == null:
		return Vector2.ZERO
	var start_room = _get_room_containing_point(crew, start)
	if start_room == null:
		return Vector2.ZERO
	if start_room == dest_room:
		if check_path_for_static_obstacles(crew, destination):
			return destination
		return Vector2.ZERO
	var entrance_route = _find_route_via_room_entrances(crew, start_room, dest_room, start, destination)
	if entrance_route != Vector2.ZERO:
		return entrance_route
	return Vector2.ZERO


static func _get_room_containing_point(crew, point: Vector2) -> Room:
	var space_state = crew.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = crew.COLLISION_LAYERS.OBSTACLES
	var result = space_state.intersect_point(query)
	for hit in result:
		if hit.collider is Room:
			return hit.collider as Room
	return null


static func _find_route_via_room_entrances(crew, start_room: Room, dest_room: Room, start: Vector2, destination: Vector2) -> Vector2:
	var entrances: Array[Vector2] = _get_room_entrances(crew, dest_room)
	if entrances.is_empty():
		return Vector2.ZERO
	var best_entrance: Vector2 = Vector2.ZERO
	var best_distance: float = INF
	for entrance in entrances:
		if check_path_for_static_obstacles(crew, entrance):
			var distance: float = start.distance_to(entrance)
			if distance < best_distance:
				best_distance = distance
				best_entrance = entrance
	return best_entrance


static func _get_room_entrances(crew, room: Room) -> Array[Vector2]:
	return []


static func _find_multi_step_route_with_avoidance(crew, start: Vector2, destination: Vector2) -> Vector2:
	var directions: Array[Vector2] = [
		Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1),
		Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)
	]
	var step_size = 200.0
	var max_steps = 6
	for direction in directions:
		for i in range(1, max_steps + 1):
			var test_target = start + direction * (step_size * i)
			if check_path_for_static_obstacles(crew, test_target):
				if _can_reach_destination_from(crew, test_target, destination):
					if check_path_for_static_obstacles(crew, test_target):
						return test_target
	return Vector2.ZERO


static func _find_closest_reachable_point(crew, destination: Vector2) -> Vector2:
	var current_pos = crew.global_position
	var search_radius = 256.0
	var max_radius = 768.0
	var step_size = 128.0
	while search_radius <= max_radius:
		var angle = 0.0
		var angle_step = PI / 4.0
		while angle < 2 * PI:
			var offset = Vector2(cos(angle), sin(angle)) * search_radius
			var test_point = destination + offset
			if check_path_for_static_obstacles(crew, test_point):
				if check_path_for_static_obstacles(crew, test_point):
					return test_point
			angle += angle_step
		search_radius += step_size
	return current_pos


static func _world_center_of_footprint(crew, furniture) -> Vector2:
	var occupiedTiles: Array[Vector2i] = furniture.get_occupied_tiles()
	if occupiedTiles.is_empty():
		return furniture.global_position
	var worldSum := Vector2.ZERO
	for occTile in occupiedTiles:
		worldSum += crew._nav_grid.tile_center_world(occTile)
	return worldSum / float(occupiedTiles.size())

