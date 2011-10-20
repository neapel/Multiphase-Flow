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
		@vx = 0
		@vy = 4 + Math.random() * 4
		# Force
		@fx = @fy = 0
		# Environment
		@density = @density_near = 0
		# Material
		@type = type % COLORS.length
		@color = COLORS[@type]


class Flow
	constructor: (@canvas) ->
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
		@mouse = {x: 50, y: 50}
		# Count splashes for coloring
		@splash = 0
		# Index of oldest particle
		@last_particle = 0
		# Start the animation
		@render_frame()

	# Render one frame
	render_frame: =>
		window._requestAnimationFrame(@render_frame, @canvas)
		@pour() if @pressing
		@calculate_forces()
		@move_particles()
		@draw_particles()
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
		null

	# Add dots to the simulation
	pour: ->
		for i in [-3 .. 3]
			x = @mouse.x + i * RANGE / DENSITY
			y = @mouse.y
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
		NICE = true
		if NICE
			@canvas.width = @canvas.width
		else
			@context.save()
			@context.fillStyle = 'white'
			@context.globalAlpha = 0.65
			@context.fillRect(0, 0, @canvas.width, @canvas.height)
			@context.restore()
		last_type = -1
		r = RANGE / 8.0
		if not NICE
			# Draw particles as dots
			for p in @particles
				if p.type != last_type
					@context.fillStyle = p.color
				last_type = p.type
				@context.fillRect(p.x - r, p.y - r, 2 * r, 2 * r)
		else
			# Elongated dots
			f = 2
			@context.lineWidth = 2 * r
			@context.lineCap = 'round'
			count = 0
			for p in @particles
				if p.type != last_type
					@context.stroke()
					@context.beginPath()
					@context.strokeStyle = p.color
					count = 0
				last_type = p.type
				@context.moveTo(p.x, p.y)
				vx = f * p.vx
				vx = 0.5 if Math.abs(vx) < 0.01
				@context.lineTo(p.x - vx, p.y - f * p.vy)
				count++
			@context.stroke()
		# Info
		if false
			@context.fillStyle = 'black'
			s = "#{@particles.length} particles, #{@neighbors.length} collisions"
			@context.fillText(s, 10, 40)


# UI integration
html = (name, args, children, events) ->
	e = document.createElement name
	e.setAttribute k, v for k, v of args or {}
	e.appendChild c for c in children or []
	e.addEventListener k ,v, false for k, v of events or {}
	e
text = (value) -> document.createTextNode value

create_options = (parent)->
	parent.appendChild pane = html 'p', {id: 'options', style: 'display: none'}
	parent.appendChild p = html 'p', {id: 'help'}, [
		text 'Click in the white area to spill dots. Try changing the window height or '
		html 'a', {href: '#'}, [text('play with the options')],
			click: (e) =>
				e.preventDefault()
				parent.removeChild p
				pane.style.display = 'block'
		text '.'
	]
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
	f = new Flow(document.getElementById 'canvas')
	resize = ->
		w = Math.min(MAX_WIDTH, window.innerWidth)
		f.resize(w, window.innerHeight)
	resize()
	# Resize canvas with window
	window.addEventListener 'resize', resize, false
	# Options pane
	create_options(document.getElementById 'info')\
		('Gravity', 0, 1, 'GRAVITY')\
		('Density', 0, 5, 'DENSITY')\
		('Type Sep.', 0, 1, 'PRESSURE')\
		('Inner Sep.', 0.1, 1, 'PRESSURE_NEAR')\
		('Dot Limit', 10, 10000, 'LIMIT', ->
			LIMIT = Math.floor(LIMIT)
			if f.particles.length > LIMIT then f.particles.length = LIMIT
		)('Max Width', 50, 2000, 'MAX_WIDTH', resize)
