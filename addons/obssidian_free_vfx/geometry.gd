extends RefCounted
## Geometry helpers belonging only to the free collection.

static func ribbon(points:Array[Vector3],widths:Array[float],up:Vector3=Vector3.UP)->ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left:Array[Vector3]=[];var right:Array[Vector3]=[]
	for i in range(points.size()):
		var tangent:Vector3=points[min(i+1,points.size()-1)]-points[max(i-1,0)]
		var side:=tangent.normalized().cross(up).normalized()
		if side.length_squared()<.1:side=Vector3.RIGHT
		left.append(points[i]-side*widths[i]);right.append(points[i]+side*widths[i])
	for i in range(points.size()-1):
		for sample in [[i,0],[i+1,0],[i+1,1],[i,0],[i+1,1],[i,1]]:
			var k:int=sample[0];var s:int=sample[1]
			st.set_uv(Vector2(float(k)/float(points.size()-1),float(s)))
			st.add_vertex(left[k] if s==0 else right[k])
	st.generate_normals();return st.commit()

static func tube(points:Array[Vector3],radius:float,sides:int=8)->ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var frames:Array[Basis]=[]
	for i in range(points.size()):
		var tangent:Vector3=(points[min(i+1,points.size()-1)]-points[max(i-1,0)]).normalized()
		var up:=Vector3.RIGHT if absf(tangent.dot(Vector3.UP))>.94 else Vector3.UP
		frames.append(Basis.looking_at(tangent,up))
	for i in range(points.size()-1):
		for j in range(sides):
			for sample in [[i,j],[i+1,j],[i+1,j+1],[i,j],[i+1,j+1],[i,j+1]]:
				var k:int=sample[0];var a:float=float(sample[1])*TAU/sides
				var normal:=frames[k]*(Vector3(cos(a),sin(a),0))
				st.set_normal(normal);st.set_uv(Vector2(float(k)/(points.size()-1),float(sample[1])/sides))
				st.add_vertex(points[k]+normal*radius)
	return st.commit()

static func arc(radius:float,start:float,end:float,count:int=48,plane:int=0)->Array[Vector3]:
	var points:Array[Vector3]=[]
	for i in range(count+1):
		var angle:=lerpf(start,end,float(i)/count)
		points.append(Vector3(cos(angle)*radius,sin(angle)*radius,0) if plane==0 else Vector3(cos(angle)*radius,0,sin(angle)*radius))
	return points

static func crescent()->ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings:Array[Array]=[]
	for i in range(49):
		var u:=float(i)/48.;var a:=lerpf(-2.35,2.35,u)
		var outer:=Vector2(cos(a),sin(a))*.88
		var width:=.24*pow(sin(u*PI),.6)+.003
		var inner:=Vector2(cos(a),sin(a))*(.88-width)
		rings.append([Vector3(outer.x,outer.y,0),Vector3(inner.x,inner.y,-.055),Vector3(inner.x,inner.y,.055)])
	for i in range(48):
		for side in range(3):
			var next:=(side+1)%3
			for sample in [[i,side],[i+1,side],[i+1,next],[i,side],[i+1,next],[i,next]]:
				st.set_uv(Vector2(float(sample[0])/48.,float(sample[1])/2.))
				st.add_vertex(rings[sample[0]][sample[1]])
	st.generate_normals();return st.commit()

static func needle(length:float,width:float)->ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring:Array[Vector3]=[Vector3(width,0,0),Vector3(0,width,0),Vector3(-width,0,0),Vector3(0,-width,0)]
	for i in range(4):
		for triangle in [[Vector3(0,0,-length*.8),ring[i],ring[(i+1)%4]],[Vector3(0,0,length*.2),ring[(i+1)%4],ring[i]]]:
			for j in range(3):st.set_uv(Vector2(float(j)/2.,float(i)/4.));st.add_vertex(triangle[j])
	st.generate_normals();return st.commit()

static func sphere(radius:float)->SphereMesh:
	var mesh:=SphereMesh.new();mesh.radius=radius;mesh.height=radius*2.;mesh.radial_segments=24;mesh.rings=12;return mesh
