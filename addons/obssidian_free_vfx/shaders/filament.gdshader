shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint:source_color=vec4(1.,.65,.12,1.);
uniform float age=0.;
uniform float energy=1.;
uniform float opacity=1.;
uniform float style=0.;
float hash(vec2 p){return fract(sin(dot(p,vec2(31.7,73.3)))*15231.43);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+1.),f.x),f.y);}
void fragment(){
 float edge=abs(UV.y-.5)*2.;
 float flow=noise(vec2(UV.x*18.-age*4.,UV.y*4.));
 float mask=pow(max(0.,1.-edge),.75)*smoothstep(0.,.025,UV.x)*smoothstep(1.,.96,UV.x);
 vec3 c=mix(tint.rgb*.6,tint.rgb,flow);
 float core=pow(max(0.,1.-edge),8.);
 if(style<1.5){c=mix(c,vec3(.94,.98,1.),core*.68);}
 else{c=mix(vec3(.004,.002,.015),tint.rgb,smoothstep(.35,.9,edge)+flow*.22);mask*=.75+.25*sin(UV.x*74.-age*8.);}
 float boost=style>.5&&style<1.5?2.6:1.45;
 ALBEDO=c*energy*.60;EMISSION=c*energy*(1.2+core*1.2)*boost;ALPHA=mask*opacity;
}
