GRAVITY = 0.05
RANGE = 16
RANGE2 = RANGE * RANGE
DENSITY = 2.5
PRESSURE = 1
PRESSURE_NEAR = 1
VISCOSITY = 0.1
NUM_GRIDS = 29 # Width/range
INV_GRID_SIZE = 1 / (465 / NUM_GRIDS)

class Neighbors
	setParticle: (p1, p2) ->
		@p1 = p1
		@p2 = p2
		@nx = p1.x - p2.x
		@ny = p1.y - p2.y
		@distance = Math.sqrt(@nx * @nx + @ny * @ny)
		@weight = 1 - @distance / RANGE
		density = @weight * @weight
		p1.density += density
		p2.density += density
		density *= @weight * PRESSURE_NEAR
		p1.densityNear += density
		p2.densityNear += density
		
		@nx /= @distance
		@ny /= @distance
		null
	
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
	constructor: (@x, @y, @type) ->
		@gx = @gy = 0
		@vx = @vy = 0
		@fx = @fy = 0
		@density = @densityNear = 0
		@gravity = GRAVITY
		@color = COLORS[@type]


class Grid
	constructor: ->
		@particles = []
	
	add: (particle) ->
		@particles.push(particle)
		null




class Flow
	constructor: ->
		@canvas = document.getElementById 'canvas'
		@context = @canvas.getContext '2d'
		@canvas.width = @width = 465
		@canvas.height = @height = 465
		@particles = []
		@neighbors = []
		@grids = for i in [0 .. NUM_GRIDS - 1]
			for j in [0 .. NUM_GRIDS - 1]
				new Grid()
		@count = 0

		@canvas.addEventListener 'mousemove', ( (e)=>
			@mouse.x = e.layerX
			@mouse.y = e.layerY), false
		@canvas.addEventListener 'mousedown', ( (e)=>
			e.preventDefault()
			@mouseDown = true
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
			@canvas.width = @canvas.width
			if @mouseDown
				@pour()
			@move()
		, 20)

		@mouseDown = false
		@press = false
		@mouse = {x: null, y: null}

	pour: ->
		for i in [-4 .. 4]
			p = new Particle(@mouse.x + i * 10, @mouse.y, Math.floor(@count / 10 % 5))
			p.vy = 5
			@particles.push p
			if @particles.length >= 1500
				@particles.shift()
		null

	move: ->
		@count++
		@updateGrids()
		@findNeighbors()
		@calcForce()
		for p in @particles
			@moveParticle(p)
			@context.fillStyle = p.color
			@context.fillRect(p.x - 1, p.y - 1, 3, 3)
		null

	updateGrids: ->
		for h in @grids
			for g in h
				g.particles.length = 0

		for p in @particles	
			# Zero all of the things!
			p.fx = 0
			p.fy = 0
			p.density = 0
			p.densityNear = 0
			
			p.gx = Math.floor(p.x * INV_GRID_SIZE)
			p.gy = Math.floor(p.y * INV_GRID_SIZE)
			p.gx = 0 if p.gx < 0
			p.gy = 0 if p.gy < 0
			p.gx = NUM_GRIDS - 1 if p.gx > NUM_GRIDS - 1
			p.gy = NUM_GRIDS - 1 if p.gy > NUM_GRIDS - 1
		null
	
	findNeighbors: ->
		@neighbors.length = 0
		for p in @particles
			xMin = p.gx != 0
			xMax = p.gx != (NUM_GRIDS - 1)
			yMin = p.gy != 0
			yMax = p.gy != (NUM_GRIDS - 1)
			@findNeighborsInGrid(p, @grids[p.gx][p.gy])
			@findNeighborsInGrid(p, @grids[p.gx - 1][p.gy]) if xMin
			@findNeighborsInGrid(p, @grids[p.gx + 1][p.gy]) if xMax
			@findNeighborsInGrid(p, @grids[p.gx][p.gy - 1]) if yMin
			@findNeighborsInGrid(p, @grids[p.gx][p.gy + 1]) if yMax
			@findNeighborsInGrid(p, @grids[p.gx - 1][p.gy - 1]) if xMin and yMin
			@findNeighborsInGrid(p, @grids[p.gx - 1][p.gy + 1]) if xMin and yMax
			@findNeighborsInGrid(p, @grids[p.gx + 1][p.gy - 1]) if xMax and yMin
			@findNeighborsInGrid(p, @grids[p.gx + 1][p.gy + 1]) if xMax and yMax
			@grids[p.gx][p.gy].add(p)
		null
	
	findNeighborsInGrid: (pi, g) ->
		for pj in g.particles
			distance = (pi.x - pj.x) * (pi.x - pj.x) + (pi.y - pj.y) * (pi.y - pj.y)
			if distance < RANGE2
				n = new Neighbors()
				n.setParticle(pi, pj)
				@neighbors.push n
		null

	calcForce: ->
		for n in @neighbors
			n.calcForce()
		null

	moveParticle: (p) ->
		p.vy += GRAVITY
		if p.density > 0
			p.vx += p.fx / (p.density * 0.9 + 0.1)
			p.vy += p.fy / (p.density * 0.9 + 0.1)
		p.x += p.vx
		p.y += p.vy
		if p.x < 5
			p.vx += (5 - p.x) * 0.5 - p.vx * 0.5
		if p.x > 460
			p.vx += (460 - p.x) * 0.5 - p.vx * 0.5
		if p.y < 5
			p.vy += (5 - p.y) * 0.5 - p.vy * 0.5
		if p.y > 460
			p.vy += (460 - p.y) * 0.5 - p.vy * 0.5
		null



window.onload = ->
	f = new Flow()
