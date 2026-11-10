shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint:source_color=vec4(1.,.68,.18,1.);
uniform float age=0.;
uniform float energy=1.;
uniform float opacity=1.;
void fragment(){
 float groove=smoothstep(.94,.99,sin(UV.x*150.+UV.y*28.));
 float edge=pow(abs(UV.y-.5)*2.,5.);
 ALBEDO=mix(tint.rgb*.38,tint.rgb*.85,edge);
 METALLIC=.82;ROUGHNESS=.26;SPECULAR=.8;
 EMISSION=tint.rgb*(groove*.35+edge*.26)*energy;
 ALPHA=opacity;
}
