function Flow(){
	
	var canvas;
	var context;

	var width;
	var height;

	var mouseDown;
	var mouse = {x: null, y: null};
	var interval;
	
	var GRAVITY = 0.05;
	var RANGE = 16;
	var RANGE2 = RANGE * RANGE;
	var DENSITY = 2.5;
	var PRESSURE = 1;
	var PRESSURE_NEAR = 1;
	var VISCOSITY = 0.1;
	var NUM_GRIDS = 29; // Width/range
	var INV_GRID_SIZE = 1 / (465 / NUM_GRIDS);
	
	var particles; //Vector.<Particle>
	
	var numParticles;
	var neighbors; //Vector.<Neighbor>
	
	var numNeighbors;
	
	var count;
	var press;
	var grids; //Vector.<Vector.<Grid>>;
	
	this.initialize = function(){
		canvas  = document.getElementById("canvas");
		context = canvas.getContext('2d');
			
		width = 465;//window.innerWidth
		height = 465;//window.innerHeight
		
		canvas.width = width;
		canvas.height = height;
		
		particles = new Array();
		numParticles = 0;
		
		neighbors = new Array();
		numNeighbors = 0;
		
		grids = new Array();
		
		var i, j;
		
		for (i = 0; i < NUM_GRIDS; i++)
		{
			grids[i] = new Array(NUM_GRIDS);
			
			for (j = 0; j < NUM_GRIDS; j++)
			{
				grids[i][j] = new Grid();
			}	
		}
		
		count = 0;
				
		canvas.addEventListener('mousemove', MouseMove, false);
		canvas.addEventListener('mousedown', MouseDown, false);
		canvas.addEventListener('mouseup', MouseUp, false);
		canvas.addEventListener('mouseout', MouseOut, false);
		
		//Set interval - Bad! - I know!
		var interval = setInterval(Update, 20);
		
	}
	
	var Update = function(){
		
		ClearFrame();
		
		if (mouseDown){
			pour();
		}
		
		move();
		
	}
	
	var pour = function(){
		
		var i;
		for (i = -4; i <= 4; i++){
			
			particles[numParticles++] = new Particle(mouse.x + i * 10, mouse.y,
				Math.floor(count / 10 % 5)); 
				
			//Particles y velocity = 5.
			particles[numParticles - 1].vy = 5;
			
			//Limit these!
			if (numParticles >= 1500){
				particles.shift();
				numParticles--;
				
			}
		}
		
	}
	
	var move = function(){
		
		count++;
		
		updateGrids();
		findNeighbors();
		calcForce();
		
		var i, p;
		
		for (i = 0; i < numParticles; i++){
			p = particles[i];
			moveParticle(p);
			
			context.fillStyle = p.color;  
 			context.fillRect(p.x - 1, p.y - 1, 3, 3);  
			
		}			
	}
	
	var updateGrids = function(){
		
		var p;
		var i, j;
		
		for (i = 0; i < NUM_GRIDS; i++){
			
			for (j = 0; j < NUM_GRIDS; j++){
				
				//Is this meant to clear the grid?
				grids[i][j].particles.length = 0;
				grids[i][j].numParticles = 0;
			}	
		}
		
		for (i = 0; i < numParticles; i++){
			
			p = particles[i];
			
			//Zero all of the things!
			p.fx = 0;
			p.fy = 0;
			p.density = 0;
			p.densityNear = 0;
			
			p.gx = Math.floor(p.x * INV_GRID_SIZE);
			p.gy = Math.floor(p.y * INV_GRID_SIZE);
			
			if(p.gx < 0){
				
				p.gx = 0;
			}
			
			if (p.gy < 0){
				
				p.gy = 0;
			}
			
			if (p.gx > NUM_GRIDS - 1){
				p.gx = NUM_GRIDS - 1;	
			}
			
			if (p.gy > NUM_GRIDS - 1){
				p.gy = NUM_GRIDS - 1;
			}
		}
	}
	
	var findNeighbors = function(){
		
		var i;
		var p;
		numNeighbors = 0;
		
		for(i = 0; i < numParticles; i++){
			
			p = particles[i];
			
			var xMin = p.gx != 0;
			var xMax = p.gx != (NUM_GRIDS - 1);
			
			var yMin = p.gy != 0;
			var yMax = p.gy != (NUM_GRIDS - 1); 
			
			findNeighborsInGrid(p, grids[p.gx][p.gy]);
			
			if(xMin){
				findNeighborsInGrid(p, grids[p.gx - 1][p.gy]);
			}
			
            if(xMax){
            	findNeighborsInGrid(p, grids[p.gx + 1][p.gy]);
            }
            
            if(yMin){
            	findNeighborsInGrid(p, grids[p.gx][p.gy - 1]);
            }
            
            if(yMax){
            	findNeighborsInGrid(p, grids[p.gx][p.gy + 1]);
            }
            
            if(xMin && yMin){
            	findNeighborsInGrid(p, grids[p.gx - 1][p.gy - 1]);
            }
            
            if(xMin && yMax){
            	findNeighborsInGrid(p, grids[p.gx - 1][p.gy + 1]);
            }
            
            if(xMax && yMin){
            	findNeighborsInGrid(p, grids[p.gx + 1][p.gy - 1]);
            }
            
            if(xMax && yMax){
            	findNeighborsInGrid(p, grids[p.gx + 1][p.gy + 1]);
            }
            
            grids[p.gx][p.gy].add(p);
		}
	}
	
	
	var findNeighborsInGrid = function(pi, g){
		
		var j;
		
		var pj, distance;
		
		for (j = 0; j < g.numParticles; j++){
			
			pj = g.particles[j];
			
			distance = (pi.x - pj.x) * (pi.x - pj.x) +
			 		   (pi.y - pj.y) * (pi.y - pj.y);

			if (distance < RANGE2){
				
				if(neighbors.length == numNeighbors){
					
					neighbors[numNeighbors] = new Neighbor();
				} 
				
				neighbors[numNeighbors++].setParticle(pi, pj);
					
			}	
		}
	}
	
	var calcForce = function(){
		
		var i;
		
		for (i = 0; i < numNeighbors; i++){
			
			neighbors[i].calcForce();
		}	
	}
	
	
	
	var moveParticle = function(p){
		
		p.vy += GRAVITY;
		
		if (p.density > 0){
			
			p.vx += p.fx / (p.density * 0.9 + 0.1);
			p.vy += p.fy / (p.density * 0.9 + 0.1);	
		}
		
		p.x += p.vx;
		p.y += p.vy;
		
		if (p.x < 5){
			p.vx += (5 - p.x) * 0.5 - p.vx * 0.5;
		}
		
		if (p.x > 460){		
            p.vx += (460 - p.x) * 0.5 - p.vx * 0.5;
        }
        
        if(p.y < 5){
            p.vy += (5 - p.y) * 0.5 - p.vy * 0.5;
        }
        
        if(p.y > 460){
            p.vy += (460 - p.y) * 0.5 - p.vy * 0.5;
		}
		
	}
	
		
	var MouseMove = function(e) {
        mouse.x = e.layerX;
        mouse.y = e.layerY;
	}
	
	//Clear the screen, 
	var MouseDown = function(e) {
		e.preventDefault();
		mouseDown = true;
		
		// setTimeout(Update, 20);
		// setTimeout(Update, 40);
		// setTimeout(Update, 60);
		// setTimeout(Update, 80);
		// setTimeout(Update, 100);
	}
	
		//Clear the screen, 
	var MouseUp = function(e) {
		e.preventDefault();
		mouseDown = false;
	}
	
	var MouseOut = function(e) {
		e.preventDefault();
		mouseDown = false;

		// setTimeout(move, 20);
		// setTimeout(move, 40);
		// setTimeout(move, 60);
		// setTimeout(move, 80);
		// setTimeout(move, 100);
		ClearFrame();
	}
	
	var ClearFrame = function(){
		canvas.width = canvas.width
	}
}

function Neighbor(){
	
	this.p1;
	this.p2;
	
	this.distance;
	
	this.nx;
	this.ny;

	this.weight;
	
	//Constants - should be taken from flow class;
	this.RANGE = 16;
	this.PRESSURE = 1;
	this.PRESSURE_NEAR = 1;
	this.DENSITY = 2.5;
	this.VISCOSITY = 0.1;
	
	this.setParticle = function(p1, p2){
			
		this.p1 = p1;
		this.p2 = p2;
		
		this.nx = p1.x - p2.x;
		this.ny = p1.y - p2.y;
		
		this.distance = Math.sqrt(this.nx * this.nx + this.ny * this.ny);
		
		this.weight = 1 - this.distance / this.RANGE;
		
		var density = this.weight * this.weight;
		
		p1.density += density;
		p2.density += density;
		
		density *= this.weight * this.PRESSURE_NEAR;
		
		p1.densityNear += density;
		p2.densityNear += density;
		
		//Interted distance
		var invDistance = 1 / this.distance;
		
		this.nx *= invDistance;
		this.ny *= invDistance;
		
	}
	
	this.calcForce = function(){
		
		var p;
		
		var p1 = this.p1;
		var p2 = this.p2;
		
		if(this.p1.type != this.p2.type){
			
			p = (p1.density + p2.density - this.DENSITY * 1.5) * this.PRESSURE;
			
		} else {
			
			 p = (p1.density + p2.density - this.DENSITY * 2) * this.PRESSURE;
			
		}
		
		var pn = (p1.densityNear + p2.densityNear) * this.PRESSURE_NEAR;
		
		var pressureWeight = this.weight * (p + this.weight * pn);
		var viscocityWeight = this.weight * this.VISCOSITY;
		
		var fx = this.nx * pressureWeight;
		var fy = this.ny * pressureWeight;
		
		fx += (p2.vx - p1.vx) * viscocityWeight;
		fy += (p2.vy - p1.vy) * viscocityWeight;
		
		p1.fx += fx;
		p1.fy += fy;
		
		p2.fx -= fx;
		p2.fy -= fy;
	}
}



function Particle(x, y, type){
	
	this.x = x;
	this.y = y;
	
	this.gx;
	this.gy;
	this.vx = 0;
	this.vy = 0;
	this.fx = 0;
	this.fy = 0;
	
	this.density;
	this.densityNear;
	
	this.color;
	this.type = type;
	this.gravity = 0.05; //Should get the main class gravity.
	
	switch(type){
		
		case 0:
			this.color = "#6060ff";
			break;
		case 1:
			this.color = "#ff6000";
			break;
		case 2:
            this.color = "#ff0060";
            break;
        case 3:
            this.color = "#00d060";
            break;
        case 4:
            this.color = "#d0d000";
            break;
	}
		
}

//Grids for quicker grouping
function Grid(){
	
	this.particles = new Array();
	this.numParticles = 0;
	
	this.add = function(particle){
		
		this.particles[this.numParticles++] = particle;
	}
}
