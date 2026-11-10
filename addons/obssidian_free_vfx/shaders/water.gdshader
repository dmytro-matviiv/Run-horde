shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform vec4 tint:source_color=vec4(.03,.52,.73,1.);
uniform float age=0.;
uniform float energy=1.;
uniform float opacity=1.;
float hash(vec2 p){return fract(sin(dot(p,vec2(25.9,71.7)))*17385.3);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+1.),f.x),f.y);}
void vertex(){VERTEX+=NORMAL*(sin(UV.x*58.-age*9.+UV.y*7.)*.025+sin(UV.x*103.+age*11.)*.014);}
void fragment(){
 float n=noise(vec2(UV.x*30.-age*2.4,UV.y*9.+age*.3));
 float crest=pow(abs(UV.y-.5)*2.,4.);
 float foam=smoothstep(.65,.91,n*.66+crest*.6);
 vec3 ripple=vec3(sin(UV.x*99.-age*13.)*.13,(n-.5)*.20,cos(UV.y*44.+age*9.)*.12);
 NORMAL=normalize(NORMAL+ripple);
 float fresnel=pow(1.-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.,1.),2.4);
 vec3 body=mix(tint.rgb*.15,tint.rgb*.65,fresnel*.8+n*.2);
 ALBEDO=mix(body,vec3(.82,.95,.98),foam*.8);
 METALLIC=.04;ROUGHNESS=mix(.045,.28,foam);SPECULAR=.95;
 EMISSION=(tint.rgb*fresnel*.24+vec3(.13,.18,.19)*foam)*energy;
 ALPHA=opacity*(.83+foam*.15);
}
