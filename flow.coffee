GRAVITY = 0.05
RANGE = 20
DENSITY = 2.5
PRESSURE = 1
PRESSURE_NEAR = 1
VISCOSITY = 0.1
LIMIT = 1500


class Neighbors
	constructor: (@p1, @p2) ->
		@nx = @p1.x - @p2.x
		@ny = @p1.y - @p2.y
		@distance = Math.sqrt(@nx * @nx + @ny * @ny)
		@weight = 1 - @distance / RANGE
		density = @weight * @weight
		@p1.density += density
		@p2.density += density
		density *= @weight * PRESSURE_NEAR
		@p1.densityNear += density
		@p2.densityNear += density
		
		@nx /= @distance
		@ny /= @distance
	
	calcForce: ->
		if @p1.type != @p2.type
			p = (@p1.density + @p2.density - DENSITY * 1.5) * PRESSURE
		else
			p = (@p1.density + @p2.density - DENSITY * 2) * PRESSURE
		pn = (@p1.densityNear + @p2.densityNear) * PRESSURE_NEAR
		pressureWeight = @weight * (p + @weight * pn)
		viscocityWeight = @weight * VISCOSITY
		
		fx = @nx * pressureWeight
		fy = @ny * pressureWeight
		
		fx += (@p2.vx - @p1.vx) * viscocityWeight
		fy += (@p2.vy - @p1.vy) * viscocityWeight
		
		@p1.fx += fx
		@p1.fy += fy
		
		@p2.fx -= fx
		@p2.fy -= fy
		null


COLORS = [
	'#6060ff'
	'#ff6000'
	'#ff0060'
	'#00d060'
	'#d0d000'
]


class Particle
	constructor: (@x, @y, type) ->
		@gx = @gy = 0
		@vx = 0
		@vy = 4 + Math.random() * 4
		@fx = @fy = 0
		@density = @densityNear = 0
		@gravity = GRAVITY
		@type = type % COLORS.length
		@color = COLORS[@type]



class Flow
	constructor: (@canvas) ->
		@particles = []
		@neighbors = [] # re-use objects

		@context = @canvas.getContext '2d'
		@resize(@canvas.width or 465, @canvas.height or 465)

		@canvas.addEventListener 'mousemove', ( (e)=>
			@mouse.x = e.layerX
			@mouse.y = e.layerY
		), false
		@canvas.addEventListener 'mousedown', ( (e)=>
			e.preventDefault()
			@mouseDown = true
			@splash++
		), false
		@canvas.addEventListener 'mouseup', ( (e)=>
			e.preventDefault()
			@mouseDown = false
		), false
		@canvas.addEventListener 'mouseout', ( (e)=>
			e.preventDefault()
			@mouseDown = false
		), false

		@interval = setInterval( =>
			@pour() if @mouseDown
			@move()
		, 20)

		@mouseDown = false
		@mouse = {x: 50, y: 50}
		@splash = 0
		@last_particle = 0



	resize: (w, h)->
		# Canvas size
		@canvas.width = w
		@canvas.height = h

		# Bounce border
		border = 5
		@left = @top = border
		@right = w - border
		@bottom = h - border

		# Grid size
		@grid_width = Math.floor(w / RANGE)
		@grid_height = Math.floor(h / RANGE)

		# Grid cell size
		@cell_width = w / @grid_width
		@cell_height = h / @grid_height
		


	pour: ->
		for i in [-4 .. 4]
			x = @mouse.x + i * RANGE * 0.8
			y = @mouse.y
			if @particles.length >= LIMIT
				@particles[@last_particle++ % LIMIT].constructor(x, y, @splash)
			else
				@particles.push(new Particle(x, y, @splash))
		null


	move: ->
		@calculate_forces()
		@move_particles()
		@draw_particles()
		null


	calculate_forces: ->
		# Neighborhood grids
		stride = @grid_width
		grid_index = (x, y) -> x + y * stride
		grids = {}

		# Store force calculations for later
		n_index = 0

		# Calculate each particle's density and neighbors
		for p in @particles
			for dx in [-1 .. 1]
				for dy in [-1 .. 1]
					i = grid_index(p.gx + dx, p.gy + dy)
					if grids[i] != undefined
						for q in grids[i]
							if Math.pow(p.x - q.x, 2) + Math.pow(p.y - q.y, 2) < Math.pow(RANGE, 2)
								if n_index >= @neighbors.length
									@neighbors.push( new Neighbors(p, q) )
								else
									@neighbors[n_index].constructor(p, q)
								n_index++

			# Add this particle for interaction with others
			j = grid_index(p.gx, p.gy)
			if grids[j] == undefined
				grids[j] = [p]
			else
				grids[j].push(p)

		@neighbors.length = n_index

		# Calculate the forces
		for n in @neighbors
			n.calcForce()

		null


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
			p.fx = p.fy = p.density = p.densityNear = 0

			# Grid position
			p.gx = Math.min(@grid_width - 1, Math.max(0, Math.floor(p.x / @cell_width)))
			p.gy = Math.min(@grid_height - 1, Math.max(0, Math.floor(p.y / @cell_height)))
		null


	draw_particles: ->
		@canvas.width = @canvas.width
		last_type = -1
		r = RANGE / 8.0

		if false
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
				@context.lineTo(p.x - f * p.vx, p.y - f * p.vy)
				count++
			@context.stroke()

		# Info
		if false
			@context.fillStyle = 'black'
			s = "#{@particles.length} particles, #{@neighbors.length} collisions"
			@context.fillText(s, 10, 40)




window.onload = ->
	f = new Flow(document.getElementById 'canvas')
	resize = ->
		w = Math.min(400, window.innerWidth)
		f.resize(w, window.innerHeight)
	window.addEventListener 'resize', resize, false
	resize()
