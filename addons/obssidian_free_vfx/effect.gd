extends Node3D
## Free collection. Five original attacks, no paid-pack controllers or dependencies.
signal impacted(world_position:Vector3)
signal finished
@export_enum("Helios Recall","Inferno Bloom","Storm Piercer","Abyssal Tether","Tidal Crown") var skill:int=0
@export var auto_play:bool=false
@export_range(.5,1.5) var effect_size:float=1.
@export_range(.25,2.) var intensity:float=1.
@export_range(.25,2.) var playback_speed:float=1.
@export var use_custom_color:bool=false
@export var custom_color:Color=Color.WHITE
@export var fragments_enabled:bool=true
@export var source_position:=Vector3(0,1.15,2.0)
## Rune Horde: false — без спалаху, кілець і лампи на мить удару (гра без спалахів, телефон).
@export var contact_flash:bool=true
@export var target_position:=Vector3(0,1.15,-1.7)
const GEO=preload("res://addons/obssidian_free_vfx/geometry.gd")
const FILAMENT=preload("res://addons/obssidian_free_vfx/shaders/filament.gdshader")
const METAL=preload("res://addons/obssidian_free_vfx/shaders/metal.gdshader")
const FLAME=preload("res://addons/obssidian_free_vfx/shaders/flame.gdshader")
const WATER=preload("res://addons/obssidian_free_vfx/shaders/water.gdshader")
const SPRITE=preload("res://addons/obssidian_free_vfx/shaders/sprite.gdshader")
const NAMES=["HELIOS RECALL","INFERNO BLOOM","STORM PIERCER","ABYSSAL TETHER","TIDAL CROWN"]
const COLORS=[Color("#ffc866"),Color("#ff4116"),Color("#55baff"),Color("#ae57fc"),Color("#37b7d1")]
const CONTACTS=[.88,.94,.73,1.05,.91]
const LENGTHS=[2.65,3.30,2.45,3.10,3.20]
var elapsed:float=10.
var duration:float=0.
var parts:Array[Dictionary]=[]
var clusters:Array[Dictionary]=[]
var contact_sent:bool=false
var finish_sent:bool=true
var light:OmniLight3D
var moving:Node3D
var ribbons:Array[MeshInstance3D]=[]
var last_color:=Color(-1,-1,-1)
var last_energy:float=-1.
var last_custom:bool=false

func _ready()->void:
	if auto_play:play()

func color()->Color:return custom_color if use_custom_color else COLORS[skill]

func clear_effect()->void:
	for group in clusters:
		var child:Node3D=group.node
		if is_instance_valid(child):remove_child(child);child.queue_free()
	if is_instance_valid(light):remove_child(light);light.queue_free()
	parts.clear();clusters.clear();ribbons.clear();moving=null;light=null

func play()->void:
	clear_effect();skill=clampi(skill,0,4);elapsed=0.;duration=LENGTHS[skill]
	contact_sent=false;finish_sent=false;last_energy=-1.;last_color=Color(-1,-1,-1);last_custom=not use_custom_color
	match skill:
		0:build_helios()
		1:build_inferno()
		2:build_storm()
		3:build_abyss()
		4:build_tidal()
	build_contact();render_at(0.)

func material(shader:Shader,tone:Color,style:float=0.)->ShaderMaterial:
	var mat:=ShaderMaterial.new();mat.shader=shader;mat.set_shader_parameter("tint",tone)
	if shader==FILAMENT or shader==SPRITE:mat.set_shader_parameter("style",style)
	return mat

func cluster(anchor:int=1)->Node3D:
	var node:=Node3D.new();add_child(node);clusters.append({"node":node,"anchor":anchor});return node

func piece(parent:Node3D,mesh:Mesh,shader:Shader,start:float,end:float,pos:Vector3=Vector3.ZERO,extra:Dictionary={})->MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=mesh
	var mat:=material(shader,extra.get("tint",COLORS[skill]),float(extra.get("style",0.)))
	node.material_override=mat;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;node.extra_cull_margin=1.
	parent.add_child(node);node.position=pos
	var item:Dictionary={"node":node,"mat":mat,"start":start,"end":end,"home":pos,"base_scale":Vector3.ONE,"shader":shader,"tone":extra.get("tint",COLORS[skill])}
	item.merge(extra,true);parts.append(item);return node

func ribbon(parent:Node3D,points:Array[Vector3],width:float,shader:Shader,start:float,end:float,extra:Dictionary={})->MeshInstance3D:
	var widths:Array[float]=[]
	for i in range(points.size()):widths.append(width*(.13+.87*pow(sin(float(i)/(points.size()-1)*PI),.45)))
	return piece(parent,GEO.ribbon(points,widths),shader,start,end,Vector3.ZERO,extra)

func ring(parent:Node3D,radius:float,thickness:float,start:float,end:float,pos:Vector3=Vector3.ZERO,extra:Dictionary={})->MeshInstance3D:
	return piece(parent,GEO.tube(GEO.arc(radius,0,TAU,56,1),thickness),FILAMENT,start,end,pos,extra)

func glow(parent:Node3D,size:float,start:float,end:float,pos:Vector3,extra:Dictionary={})->MeshInstance3D:
	var quad:=QuadMesh.new();quad.size=Vector2.ONE*size;return piece(parent,quad,SPRITE,start,end,pos,extra)

func particles(parent:Node3D,start:float,count:int,water:bool=false,inward:bool=false)->void:
	if not fragments_enabled:return
	for i in range(count):
		var a:=float(i)*2.39996;var radius:=.4+fmod(i*.71,1.5)
		var home:=Vector3(cos(a)*radius,.15+fmod(i*.17,.5),sin(a)*radius)
		var velocity:=Vector3(cos(a)*(.8+fmod(i*.13,1.)),1.3+fmod(i*.37,2.2),sin(a)*(.8+fmod(i*.13,1.)))
		var extra:Dictionary={"particle":true,"velocity":velocity,"gravity":4.,"base_scale":Vector3.ONE*(.055+fmod(i*.011,.055))}
		if inward:home*=1.7;extra.velocity=-home*1.2;extra.gravity=0.
		if water:
			extra.base_scale.y*=1.6
			piece(parent,GEO.sphere(1.),WATER,start+i*.004,start+1.25,home,extra)
		else:extra.style=1.;glow(parent,1.,start+i*.004,start+1.25,home,extra)

func build_contact()->void:
	if not contact_flash:return
	var group:=cluster(1);var hit:float=CONTACTS[skill]
	var burst:=glow(group,2.2,hit,hit+.26,Vector3.ZERO,{"style":1.,"grow":true,"tint":COLORS[skill].lerp(Color.WHITE,.45)})
	burst.rotation.y=.7
	for i in range(2):ring(group,.60+i*.24,.025,hit+i*.035,hit+.66,Vector3(0,-target_position.y+.025,0),{"grow":true,"tint":COLORS[skill].lerp(Color.WHITE,.35)})
	light=OmniLight3D.new();light.omni_range=4.;light.omni_attenuation=2.;add_child(light)

func build_helios()->void:
	moving=cluster(2)
	piece(moving,GEO.crescent(),METAL,.22,2.05)
	var edge:=GEO.arc(.89,-2.35,2.35,60)
	piece(moving,GEO.tube(edge,.015),FILAMENT,.22,2.08,Vector3.ZERO,{"tint":Color("#ffe9af")})
	for sign in [-1.,1.]:
		piece(moving,GEO.tube(GEO.arc(.73,-2.1,2.1,48),.011),FILAMENT,.22,2.05,Vector3(0,0,sign*.06),{"tint":Color("#ff9f29")})
	for i in range(9):
		var a:=lerpf(-1.65,1.65,float(i)/8.)
		var jewel:=piece(moving,GEO.needle(.095,.035),METAL,.22,2.05,Vector3(cos(a)*.74,sin(a)*.74,0),{"tint":Color("#ff9a18")})
		jewel.rotation.y=PI*.5
	var group:=cluster(0)
	for i in range(3):
		var halo:=ring(group,.35+i*.15,.014,.04,.39,Vector3.ZERO,{"grow":true})
		halo.rotation.x=PI*.5
	var trail_group:=cluster(3)
	for i in range(3):ribbons.append(ribbon(trail_group,helios_path(.25+i*.018),.08-i*.018,FILAMENT,.24,2.12,{"role":"helios_trail","lane":i,"tint":Color("#ffad39")}))
	particles(cluster(1),CONTACTS[0],28)

func helios_point(t:float)->Vector3:
	var outbound:=t<=CONTACTS[0]
	var u:=clampf((t-.24)/.64,0.,1.) if outbound else clampf((t-CONTACTS[0])/1.06,0.,1.)
	var progress:=smoothstep(0.,1.,u) if outbound else 1.-smoothstep(0.,1.,u)
	return source_position.lerp(target_position,progress)+Vector3(sin(u*PI)*(.78 if outbound else -.78),sin(u*PI)*.14,0)

func helios_path(t:float)->Array[Vector3]:
	var points:Array[Vector3]=[]
	for i in range(22):points.append(helios_point(maxf(.24,t-.38+float(i)/21.*.38))-source_position)
	return points

func build_inferno()->void:
	var caster:=cluster(0)
	ring(caster,.34,.035,.03,.52,Vector3.ZERO,{"grow":true});glow(caster,1.,.05,.5,Vector3.ZERO)
	moving=cluster(2);piece(moving,GEO.sphere(.17),FLAME,.28,.95,Vector3.ZERO)
	var group:=cluster(1)
	for layer in range(3):
		for i in range(7):
			var a:=float(i)*TAU/7.+layer*.24
			var points:Array[Vector3]=[]
			for j in range(28):
				var u:=float(j)/27.;var radius:=u*(1.75-layer*.30)
				var twist:=a+u*.52
				points.append(Vector3(cos(twist)*radius,sin(u*PI)*(.85+layer*.30)+layer*.12-.5,sin(twist)*radius))
			ribbon(group,points,.27-layer*.03,FLAME,.79+layer*.04,2.35+layer*.09,{"role":"petal","grow":true,"spin":Vector3(0,.18,0)})
	for i in range(9):
		var a:=float(i)*TAU/9.;var points:Array[Vector3]=[]
		for j in range(24):
			var u:=float(j)/23.;points.append(Vector3(cos(a+u)*(.22+u*.60),-.5+u*2.2,sin(a+u)*(.22+u*.60)))
		ribbon(group,points,.12,FLAME,.92+i*.025,2.8,{"grow":true})
	particles(group,.95,46);ring(group,.65,.035,.85,2.15,Vector3(0,-target_position.y+.04,0),{"grow":true})

func storm_bolt(seed:int,t:float)->Array[Vector3]:
	var points:Array[Vector3]=[]
	var phase:=floorf(t*24.)
	for i in range(15):
		var u:=float(i)/14.;var a:=seed*17.71+i*31.21+phase*.9
		var radius:=sin(u*PI)*(.18+fmod(seed*.17,.25))
		points.append(Vector3(sin(a)*radius,cos(a*1.7)*radius,-u*1.7))
	return points

func build_storm()->void:
	var group:=cluster(0)
	for i in range(3):
		var halo:=ring(group,.24+i*.14,.018,.02,.42,Vector3(0,0,-i*.12),{"grow":true,"tint":Color("#a6e7ff"),"style":1.});halo.rotation.x=PI*.5
	moving=cluster(2)
	for i in range(3):
		var needle:=piece(moving,GEO.needle(1.1 if i==1 else .72,.085 if i==1 else .045),METAL,.24,.86,Vector3((i-1)*.13,0,-.1 if i==1 else .16),{"tint":Color("#95d7eb")})
		needle.rotation.z=(i-1)*.15
	for i in range(6):ribbons.append(piece(moving,GEO.tube(storm_bolt(i,0),.016 if i%2 else .026),FILAMENT,.20,.91,Vector3(0,0,.50),{"role":"bolt","seed":i,"tint":Color("#9edfff"),"style":1.}))
	for i in range(2):
		var halo:=ring(moving,.20+i*.09,.016,.25,.87,Vector3(0,0,-.38),{"style":1.,"tint":Color("#c4f1ff")});halo.rotation.x=PI*.5
	glow(moving,.62,.25,.86,Vector3(0,0,-.73),{"style":1.,"tint":Color("#b4eaff")})
	var target:=cluster(1)
	for i in range(14):
		var a:=float(i)*TAU/14.;var points:Array[Vector3]=[]
		for j in range(12):
			var u:=float(j)/11.;points.append(Vector3(cos(a)*u*1.9,sin(u*PI)*.4-target_position.y+.05+sin(u*44.+i)*.055,sin(a)*u*1.9))
		piece(target,GEO.tube(points,.022),FILAMENT,.72+i*.012,1.39,Vector3.ZERO,{"grow":true,"tint":Color("#85d7ff"),"style":1.})
	for i in range(3):
		var hoop:=ring(target,.38+i*.18,.020,.74+i*.055,1.45,Vector3.ZERO,{"grow":true,"tint":Color("#bdeaff"),"style":1.});hoop.rotation.z=(i-1)*PI/3.
	for i in range(5):
		var a:=i*TAU/5.;var points:Array[Vector3]=[]
		for j in range(15):
			var u:=j/14.;points.append(Vector3(sin(a+u*5.)*.5*u,u*1.7-.5,cos(a+u*4.)*.5*u))
		piece(target,GEO.tube(points,.018),FILAMENT,.76+i*.03,1.55,Vector3.ZERO,{"style":1.,"grow":true,"tint":Color("#92d7ff")})
	particles(target,.73,36)

func tether_points(t:float,lane:int=0)->Array[Vector3]:
	var points:Array[Vector3]=[]
	var extension:=smoothstep(.28,.83,t)
	for i in range(45):
		var u:=float(i)/44.;var p:=source_position.lerp(target_position,u*extension)-source_position
		var radius:=sin(u*PI)*(.16+.18*float(lane))
		p+=Vector3(sin(u*TAU*1.8-t*4.+lane)*radius,sin(u*TAU-t*3.+lane)*radius,0)
		points.append(p)
	return points

func build_abyss()->void:
	var source:=cluster(0)
	for i in range(2):
		var halo:=ring(source,.42+i*.13,.024,.04,1.9,Vector3.ZERO,{"grow":true,"style":2.});halo.rotation.x=PI*.5;halo.rotation.z=i*.5
	for i in range(8):
		var a:=float(i)*TAU/8.;var node:=piece(source,GEO.needle(.20,.07),METAL,.04,1.85,Vector3(cos(a)*.61,sin(a)*.61,0),{"tint":Color("#30203f")});node.rotation.z=a
	var tether:=cluster(3)
	for i in range(3):ribbons.append(ribbon(tether,tether_points(.4,i),.08 if i==0 else .035,FILAMENT,.28,1.80,{"role":"tether","lane":i,"style":2.}))
	var target:=cluster(1)
	for i in range(3):
		var points:Array[Vector3]=[]
		for j in range(70):
			var u:=float(j)/69.;var a:=u*TAU*1.7+i*TAU/3.;points.append(Vector3(cos(a)*.58,-.8+u*1.65,sin(a)*.58))
		ribbon(target,points,.075,FILAMENT,.76+i*.06,2.15,{"style":2.,"grow":true,"spin":Vector3(0,-.45,0)})
	for i in range(18):
		var a:=float(i)*2.39996
		var node:=piece(target,GEO.needle(.27,.08),METAL,.80,1.95,Vector3(cos(a)*1.25,sin(a*1.8)*.7,sin(a)*1.25),{"inward":true,"tint":Color("#422458"),"spin":Vector3(1.3,.4,.7)})
		node.rotation=Vector3(a,a*.2,a*.7)
	particles(target,.79,32,false,true)

func build_tidal()->void:
	var group:=cluster(1)
	for i in range(3):ring(group,.33+i*.21,.028,.05,.94,Vector3(0,-target_position.y+.03,0),{"grow":true,"tint":Color("#9feaf4")})
	for i in range(14):
		var a:=float(i)*TAU/14.;var points:Array[Vector3]=[]
		for j in range(32):
			var u:=float(j)/31.;var r:=.25+u*1.55;var theta:=a+u*.35
			points.append(Vector3(cos(theta)*r,-target_position.y+sin(u*PI)*1.6+u*.18,sin(theta)*r))
		ribbon(group,points,.21,WATER,.65+i*.008,2.4,{"grow":true,"spin":Vector3(0,.12,0)})
	for i in range(2):
		var node:=piece(group,GEO.tube(GEO.arc(.9+i*.40,0,TAU,84,1),.10-i*.018,12),WATER,.76+i*.04,2.0,Vector3(0,-target_position.y+.20+i*.13,0),{"grow":true})
		if i==0:node.rotation.x=.12
	for i in range(5):
		var a:=float(i)*TAU/5.;var points:Array[Vector3]=[]
		for j in range(30):
			var u:=float(j)/29.;var theta:=a+u*2.2;points.append(Vector3(cos(theta)*(.25+u*.42),-target_position.y+u*1.6,sin(theta)*(.25+u*.42)))
		ribbon(group,points,.065,WATER,.76,2.25,{"grow":true})
	particles(group,.91,54,true)
	for i in range(9):
		var a:=i*TAU/9.;glow(group,.8,.94+i*.02,2.20,Vector3(cos(a)*1.12,-.65,sin(a)*1.12),{"tint":Color("#80acb3"),"opacity":.075,"rise":.25,"grow":true})
	for i in range(3):ring(group,.5+i*.3,.014,.92+i*.08,2.45,Vector3(0,-target_position.y+.02,0),{"grow":true,"tint":Color("#b8f1f2")})

func _process(delta:float)->void:
	if finish_sent:return
	var previous:=elapsed;elapsed+=maxf(0.,delta)*playback_speed
	render_at(elapsed)
	if not contact_sent and previous<=CONTACTS[skill] and elapsed>=CONTACTS[skill]:
		contact_sent=true;impacted.emit(to_global(target_position))
	if elapsed>=duration:finish_sent=true;finished.emit()

func render_at(t:float)->void:
	var tone:=color();var controls_changed:=not tone.is_equal_approx(last_color) or not is_equal_approx(intensity,last_energy) or use_custom_color!=last_custom
	for group in clusters:
		var node:Node3D=group.node;node.scale=Vector3.ONE*(effect_size if group.anchor!=3 else 1.)
		node.position=source_position if group.anchor in [0,2,3] else target_position
	for item in parts:
		var node:MeshInstance3D=item.node;var age:float=t-item.start;var life:float=item.end-item.start
		var mat:ShaderMaterial=item.mat
		if controls_changed:
			mat.set_shader_parameter("tint",tone if use_custom_color else item.tone);mat.set_shader_parameter("energy",intensity)
			if item.shader==FLAME:mat.set_shader_parameter("custom_color",use_custom_color)
		node.visible=age>=0. and age<life
		if not node.visible:continue
		var fade:float=smoothstep(0.,minf(.12,life*.25),age)*(1.-smoothstep(life*.62,life,age))
		var grow:float=smoothstep(0.,.30,age) if item.get("grow",false) else 1.
		node.scale=item.base_scale*maxf(.001,grow)
		node.position=item.home
		if item.get("grow",false) and item.shader==SPRITE:node.scale*=1.+age*2.5
		if item.get("grow",false) and item.shader==FILAMENT and not item.has("role"):node.scale*=1.+age*.6
		if item.has("spin"):node.rotation=item.spin*age
		if item.get("particle",false):
			node.position=item.home+item.velocity*age-Vector3.UP*item.gravity*age*age*.5
			node.scale*=1.-smoothstep(life*.55,life,age)
		if item.get("inward",false):node.position=item.home*(1.-smoothstep(.1,1.05,age))
		if item.has("rise"):node.position.y+=age*item.rise
		mat.set_shader_parameter("age",t);mat.set_shader_parameter("opacity",fade*float(item.get("opacity",1.)))
		if item.get("role","")=="helios_trail":
			var points:=helios_path(t-item.lane*.025);var widths:Array[float]=[]
			for j in range(points.size()):widths.append((.07-item.lane*.017)*effect_size*sin(float(j)/21.*PI))
			# Trail follows the fixed world trajectory; do not multiply its length.
			node.mesh=GEO.ribbon(points,widths);node.scale=Vector3.ONE
		if item.get("role","")=="bolt":node.mesh=GEO.tube(storm_bolt(item.seed,t),.013+(item.seed%2)*.009)
		if item.get("role","")=="tether":
			var points:=tether_points(t,item.lane);var widths:Array[float]=[]
			for j in range(points.size()):widths.append((.075 if item.lane==0 else .028)*effect_size*sin(float(j)/44.*PI))
			node.mesh=GEO.ribbon(points,widths);node.scale=Vector3.ONE
	if moving:
		if skill==0:moving.position=helios_point(t);moving.rotation=Vector3(.25,t*8.,t*5.)
		elif skill==1:moving.position=source_position.lerp(target_position,smoothstep(.28,.94,t))
		elif skill==2:moving.position=source_position.lerp(target_position,smoothstep(.24,.73,t))
	if light:
		light.position=target_position;light.light_color=tone
		light.light_energy=maxf(0.,1.-absf(t-CONTACTS[skill])*8.)*intensity*.5
	last_color=tone;last_energy=intensity;last_custom=use_custom_color
