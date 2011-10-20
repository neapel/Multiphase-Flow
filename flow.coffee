# Downwards velocity added each step
GRAVITY = 0.05
# Spring length
RANGE = 20
# Adjustments
DENSITY = 2.5
PRESSURE = 1
PRESSURE_NEAR = 1
VISCOSITY = 0.1
# Maximum number of particles
LIMIT = 1500
# Draw pretty rounded lines (impacts mostly browser canvas performance, not JS)
NICE = true
# Dot radius
RADIUS = 2.5
# Velocity scale for nice rendering
VEL_SCALE = 2

# Particle colors
COLORS = [
	'#6060ff'
	'#ff6000'
	'#ff0060'
	'#00d060'
	'#d0d000'
]


# A force acting between two particles
class Neighbors
	# First part of force calculation
	constructor: (@p1, @p2) ->
		@nx = @p1.x - @p2.x
		@ny = @p1.y - @p2.y
		distance = Math.sqrt(@nx * @nx + @ny * @ny)
		if distance > 0.01
			@nx /= distance
			@ny /= distance
		@weight = 1 - distance / RANGE
		density = @weight * @weight
		@p1.density += density
		@p2.density += density
		density *= @weight * PRESSURE_NEAR
		@p1.density_near += density
		@p2.density_near += density

	# Second part of force calculation
	calculate_force: ->
		target_density = (if @p1.type == @p2.type then 2 else 1.5) * DENSITY
		pressure = (@p1.density + @p2.density - target_density) * PRESSURE
		pressure_near = (@p1.density_near + @p2.density_near) * PRESSURE_NEAR
		pressure_weight = @weight * (pressure + @weight * pressure_near)
		viscocity_weight = @weight * VISCOSITY
		fx = @nx * pressure_weight + (@p2.vx - @p1.vx) * viscocity_weight
		fy = @ny * pressure_weight + (@p2.vy - @p1.vy) * viscocity_weight
		@p1.fx += fx
		@p1.fy += fy
		@p2.fx -= fx
		@p2.fy -= fy
		null


# One particle.
class Particle
	constructor: (@x, @y, type) ->
		# Grid position
		@gx = @gy = 0
		# Velocity
		@vx = @vy = 0
		# Force
		@fx = @fy = 0
		# Environment
		@density = @density_near = 0
		# Material
		@type = type % COLORS.length
		@color = COLORS[@type]
		# Age in frames
		@age = 0


class Flow
	constructor: (@canvas, @info) ->
		# All the particles
		@particles = []
		# Re-using calculation objects
		@neighbors = []
		# Drawing context
		@context = @canvas.getContext '2d'
		@resize(@canvas.width or 465, @canvas.height or 465)
		# Event Listeners
		@canvas.addEventListener 'mousemove', (
			(e) => [@mouse.x, @mouse.y] = [e.layerX, e.layerY]
		), false
		@canvas.addEventListener 'mousedown', ( (e)=>
			e.preventDefault()
			@pressing = true
			@splash++
		), false
		up = (e) =>
			e.preventDefault()
			@pressing = false
		@canvas.addEventListener 'mouseup', up, false
		@canvas.addEventListener 'mouseout', up, false
		# Current mouse state
		@pressing = false
		# Count splashes for coloring
		@splash = 0
		# Index of oldest particle
		@last_particle = 0
		# Frame counter
		@frame = 0
		# Start the animation
		@render_frame()

	# Render one frame
	render_frame: =>
		# schedule at start for constant frame rate
		window._requestAnimationFrame(@render_frame, @canvas)
		# spawn new dots
		@pour() if @pressing
		# simulate and draw
		@calculate_forces()
		@move_particles()
		@draw_particles()
		@frame++
		null

	# Resize the canvas and grid
	resize: (w, h)->
		# Canvas size
		@canvas.width = w
		@canvas.height = h
		# Bounce border
		border = 5
		@left = @top = border
		@right = w - border
		@bottom = h - border
		# Grid and cell size
		@grid_width = Math.floor(w / RANGE)
		@grid_height = Math.floor(h / RANGE)
		@cell_width = w / @grid_width
		@cell_height = h / @grid_height
		# Default position
		@mouse = {x: w/2, y: h/3}
		null

	# Add dots to the simulation
	pour: ->
		k = 1
		for j in [-k .. k]
			for i in [-k .. k]
				f = 2
				x = @mouse.x + i * f + Math.random()
				y = @mouse.y + j * f + Math.random()
				if @particles.length >= LIMIT
					@particles[@last_particle++ % LIMIT].constructor(x, y, @splash)
				else
					@particles.push(new Particle(x, y, @splash))
		null

	# Calculate forces between all particles
	calculate_forces: ->
		# Neighborhood grid
		stride = @grid_width
		grid_index = (x, y) -> x + y * stride
		grid = {}
		# Store force calculations for later
		n_index = 0
		# Calculate each particle's density and neighbors
		for p in @particles
			for dx in [-1 .. 1]
				for dy in [-1 .. 1]
					i = grid_index(p.gx + dx, p.gy + dy)
					if grid[i] != undefined
						for q in grid[i]
							if Math.pow(p.x - q.x, 2) + Math.pow(p.y - q.y, 2) < Math.pow(RANGE, 2)
								if n_index >= @neighbors.length
									@neighbors.push( new Neighbors(p, q) )
								else
									@neighbors[n_index].constructor(p, q)
								n_index++
			# Add this particle for interaction with others
			j = grid_index(p.gx, p.gy)
			(if grid[j] == undefined then grid[j] = [] else grid[j]).push(p)
		# Truncate
		@neighbors.length = n_index
		# Calculate the forces
		for n in @neighbors
			n.calculate_force()
		null

	# Move particles according to forces
	move_particles: ->
		for p in @particles
			# Calculate new position
			p.vy += GRAVITY
			if p.density > 0
				p.vx += p.fx / (p.density * 0.9 + 0.1)
				p.vy += p.fy / (p.density * 0.9 + 0.1)
			p.x += p.vx
			p.y += p.vy
			# Reset young particle velocity to prevent spawn explosion
			if p.age++ < 10
				p.vx = p.vy = 0
			# Bounce off walls
			p.vx += (@left - p.x) * 0.5 - p.vx * 0.5 if p.x < @left
			p.vx += (@right - p.x) * 0.5 - p.vx * 0.5 if p.x > @right
			p.vy += (@top - p.y) * 0.5 - p.vy * 0.5 if p.y < @top
			p.vy += (@bottom - p.y) * 0.5 - p.vy * 0.5 if p.y > @bottom
			# Reset
			p.fx = p.fy = p.density = p.density_near = 0
			# Grid position
			p.gx = Math.min(@grid_width - 1, Math.max(0, Math.floor(p.x / @cell_width)))
			p.gy = Math.min(@grid_height - 1, Math.max(0, Math.floor(p.y / @cell_height)))

		null

	# Draw current state
	draw_particles: ->
		@canvas.width = @canvas.width
		last_type = -1
		if VEL_SCALE == 0
			# Draw particles as dots
			for p in @particles
				if p.type != last_type
					@context.fillStyle = p.color
				last_type = p.type
				@context.fillRect(p.x - RADIUS, p.y - RADIUS, 2 * RADIUS, 2 * RADIUS)
		else
			# Elongated dots
			@context.lineWidth = 2 * RADIUS
			@context.lineCap = 'round'
			for p in @particles
				if p.type != last_type
					@context.stroke()
					@context.beginPath()
					@context.strokeStyle = p.color
				last_type = p.type
				@context.moveTo(p.x, p.y)
				vx = VEL_SCALE * p.vx
				vx = 0.5 if Math.abs(vx) < 0.01
				@context.lineTo(p.x - vx, p.y - VEL_SCALE * p.vy)
			@context.stroke()
		# Statistics
		INFO_RATE = 10
		if @info and (@frame % INFO_RATE) == 0
			s = "#{@particles.length} particles"
			now = Date.now()
			if @last_frame
				r = INFO_RATE * 1000.0 / (now - @last_frame)
				s += ", #{Math.round(r)} fps"
			@info s
			@last_frame = now
		null


# UI integration
html = (name, args, children, events) ->
	e = document.createElement name
	e.setAttribute k, v for k, v of args or {}
	e.appendChild c for c in children or []
	e.addEventListener k ,v, false for k, v of events or {}
	e
text = (value) -> document.createTextNode value
$ = (n) -> document.getElementById(n)

create_options = (parent)->
	parent.style.display = 'none'
	parent.parentNode.appendChild p = html 'p', {id: 'help'}, [
		text 'Click in the white area to spill dots. Try changing the window height or '
		html 'a', {href: '#'}, [text('play with the options')],
			click: (e) =>
				e.preventDefault()
				p.parentNode.removeChild p
				parent.style.display = 'block'
		text '.'
	]
	parent.appendChild pane = html 'p', {id: 'options'}
	option = (name, min, max, variable, notify) ->
		range = 1000
		pane.appendChild html 'label', {}, [
			text name
			html 'input', {type: 'range', min: 0, max: range,
			value: (window[variable] - min) / (max - min) * range}, [], 
				change: (e)->
					value = window[variable] = min + (max - min) * e.target.value / range
					notify(value) if notify
		]
		option


MAX_WIDTH = 400
window.onload = ->
	# Used for smooth CPU preserving animation
	window._requestAnimationFrame = window.requestAnimationFrame or
		window.webkitRequestAnimationFrame or
		window.mozRequestAnimationFrame or
		window.oRequestAnimationFrame or
		window.msRequestAnimationFrame or
		(cb, e) -> window.setTimeout(cb, 20)
	# Initialize and start
	$('more').appendChild html 'p', {}, [stats = text('')]
	f = new Flow($('canvas'), (t)->stats.data = t)
	resize = ->
		w = Math.min(MAX_WIDTH, window.innerWidth)
		f.resize(w, window.innerHeight)
	resize()
	# Resize canvas with window
	window.addEventListener 'resize', resize, false
	# Options pane
	create_options($ 'more')\
		('Gravity', 0, 1, 'GRAVITY')\
		('Density', 0, 5, 'DENSITY')\
		('Type Sep.', 0, 1, 'PRESSURE')\
		('Inner Sep.', 0.1, 1, 'PRESSURE_NEAR')\
		('Dot Limit', 10, 10000, 'LIMIT', ->
			LIMIT = Math.floor(LIMIT)
			if f.particles.length > LIMIT then f.particles.length = LIMIT
		)('Max Width', 50, 2000, 'MAX_WIDTH', resize)\
		('Radius', 1, 10, 'RADIUS')\
		('Vel. Scale', 0, 10, 'VEL_SCALE')
	null
