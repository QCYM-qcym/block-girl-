# mechanism_manifest

Status: **GODOT_READY**. Five logical mechanisms, Surface/Inner pairs; 10 transparent atlases, 50 native frames. Each frame 64×96, pivot (32,48), logical footprint 1×1 / 32×16. World Switch Device: **NOT_INCLUDED**. Frame indices below are zero-based atlas columns.

## PRESSURE_PLATE_01 / surface

- Texture: pressure_plate/pressure_plate_surface.png
- Scene: pressure_plate/PressurePlate.tscn
- Frame size: 64,96; pivot: 32,48; footprint: 1,1
- Collision type: Area2D occupant trigger
- Interaction: body_entered / body_exited, set_active
- Status: GODOT_READY

| State | Animation order | FPS | Loop |
|---|---|---:|---|
|idle|0|1|loop|
|pressed|1|1|loop|
|active|2 → 3 → 2 → 2|6|loop|

## PRESSURE_PLATE_01 / inner

- Texture: pressure_plate/pressure_plate_inner.png
- Scene: pressure_plate/PressurePlateInner.tscn
- Frame size: 64,96; pivot: 32,48; footprint: 1,1
- Collision type: Area2D occupant trigger
- Interaction: body_entered / body_exited, set_active
- Status: GODOT_READY

| State | Animation order | FPS | Loop |
|---|---|---:|---|
|idle|0|1|loop|
|pressed|1|1|loop|
|active|2 → 3 → 2 → 2|6|loop|

## DOOR_01 / surface

- Texture: door/door_surface.png
- Scene: door/Door.tscn
- Frame size: 64,96; pivot: 32,48; footprint: 1,1
- Collision type: StaticBody2D piers + state-controlled central shutter
- Interaction: set_open(bool); state_changed
- Status: GODOT_READY

| State | Animation order | FPS | Loop |
|---|---|---:|---|
|closed|0|1|loop|
|opening|0 → 1 → 2 → 3 → 4 → 5|18|non-loop|
|open|5|1|loop|
|closing|5 → 4 → 3 → 2 → 1 → 0|18|non-loop|

## DOOR_01 / inner

- Texture: door/door_inner.png
- Scene: door/DoorInner.tscn
- Frame size: 64,96; pivot: 32,48; footprint: 1,1
- Collision type: StaticBody2D piers + state-controlled central shutter
- Interaction: set_open(bool); state_changed
- Status: GODOT_READY

| State | Animation order | FPS | Loop |
|---|---|---:|---|
|closed|0|1|loop|
|opening|0 → 1 → 2 → 3 → 4 → 5|18|non-loop|
|open|5|1|loop|
|closing|5 → 4 → 3 → 2 → 1 → 0|18|non-loop|

## MOVING_PLATFORM_01 / surface

- Texture: moving_platform/moving_platform_surface.png
- Scene: moving_platform/MovingPlatform.tscn
- Frame size: 64,96; pivot: 32,48; footprint: 1,1
- Collision type: AnimatableBody2D support layer 2 + Area2D rider detection
- Interaction: move_to(integer grid target, duration); arrived
- Status: GODOT_READY

| State | Animation order | FPS | Loop |
|---|---|---:|---|
|idle|0|1|loop|
|moving|1 → 2|8|loop|
|arrived|3|1|loop|

## MOVING_PLATFORM_01 / inner

- Texture: moving_platform/moving_platform_inner.png
- Scene: moving_platform/MovingPlatformInner.tscn
- Frame size: 64,96; pivot: 32,48; footprint: 1,1
- Collision type: AnimatableBody2D support layer 2 + Area2D rider detection
- Interaction: move_to(integer grid target, duration); arrived
- Status: GODOT_READY

| State | Animation order | FPS | Loop |
|---|---|---:|---|
|idle|0|1|loop|
|moving|1 → 2|8|loop|
|arrived|3|1|loop|

## ROTATOR_01 / surface

- Texture: rotator/rotator_surface.png
- Scene: rotator/RotatingPlatform.tscn
- Frame size: 64,96; pivot: 32,48; footprint: 1,1
- Collision type: Area2D + support layer 2; disabled during transition
- Interaction: rotate_to(0 or 1); orientation_changed after commit
- Status: GODOT_READY

| State | Animation order | FPS | Loop |
|---|---|---:|---|
|orientation_a|0|1|loop|
|rotating|0 → 1 → 2 → 3 → 4|15|non-loop|
|orientation_b|4|1|loop|
|rotating_back|4 → 3 → 2 → 1 → 0|15|non-loop|

## ROTATOR_01 / inner

- Texture: rotator/rotator_inner.png
- Scene: rotator/RotatingPlatformInner.tscn
- Frame size: 64,96; pivot: 32,48; footprint: 1,1
- Collision type: Area2D + support layer 2; disabled during transition
- Interaction: rotate_to(0 or 1); orientation_changed after commit
- Status: GODOT_READY

| State | Animation order | FPS | Loop |
|---|---|---:|---|
|orientation_a|0|1|loop|
|rotating|0 → 1 → 2 → 3 → 4|15|non-loop|
|orientation_b|4|1|loop|
|rotating_back|4 → 3 → 2 → 1 → 0|15|non-loop|

## EXIT_01 / surface

- Texture: exit/exit_surface.png
- Scene: exit/ExitGoal.tscn
- Frame size: 64,96; pivot: 32,48; footprint: 1,1
- Collision type: Area2D eligible goal trigger
- Interaction: set_ready; body entry -> active; complete_goal; completed signal
- Status: GODOT_READY

| State | Animation order | FPS | Loop |
|---|---|---:|---|
|locked|0|1|loop|
|ready|1 → 2 → 1 → 1|4|loop|
|active|3|1|loop|
|complete|3 → 4 → 5|10|non-loop|
|completed|5|1|loop|

## EXIT_01 / inner

- Texture: exit/exit_inner.png
- Scene: exit/ExitGoalInner.tscn
- Frame size: 64,96; pivot: 32,48; footprint: 1,1
- Collision type: Area2D eligible goal trigger
- Interaction: set_ready; body entry -> active; complete_goal; completed signal
- Status: GODOT_READY

| State | Animation order | FPS | Loop |
|---|---|---:|---|
|locked|0|1|loop|
|ready|1 → 2 → 1 → 1|4|loop|
|active|3|1|loop|
|complete|3 → 4 → 5|10|non-loop|
|completed|5|1|loop|

## Activation / collision contract

Use mechanism-specific methods; shared set_state helper is for internal visual playback only. Door opening is non-passable until open commits; closing blocks immediately. Open gate retains only two pier polygons. Rotator disables support during rotation and changes logical orientation only at endpoint. Plate Area2D occupancy is distinct from explicit active latch. Moving support and visuals have the same root transform; tests supply rider translation, with no generic attachment gameplay system. Exit only activates from ready and completion emits a signal, not a scene change. Surface and Inner implement the identical contracts.
