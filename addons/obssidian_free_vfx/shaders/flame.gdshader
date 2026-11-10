shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint:source_color=vec4(1.,.16,.015,1.);
uniform float age=0.;
uniform float energy=1.;
uniform float opacity=1.;
uniform bool custom_color=false;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.7,315.9)))*43854.7);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+1.),f.x),f.y);}
float fbm(vec2 p){return noise(p)*.53+noise(p*2.07)*.27+noise(p*4.19)*.14+noise(p*8.23)*.06;}
void vertex(){VERTEX+=NORMAL*(sin(UV.x*27.-age*8.+UV.y*9.)*.052+sin(UV.x*69.+age*14.)*.025);}
void fragment(){
 vec2 flow=vec2(UV.x*10.-age*3.5,UV.y*4.+sin(UV.x*11.-age*6.)*.35);
 float n=fbm(flow+vec2(fbm(flow*.65)*2.,0.));
 float edge=abs(UV.y-.5)*2.;
 float heat=clamp(1.-edge*.75-n*.65,0.,1.);
 float mask=smoothstep(.10,.31,1.-edge+(n-.5)*.85);
 mask*=smoothstep(.20,.43,n)*smoothstep(0.,.04,UV.x)*smoothstep(1.,.91,UV.x);
 vec3 middle=custom_color?mix(tint.rgb,vec3(1.),.30):vec3(1.,.27,.008);
 vec3 hot=custom_color?mix(tint.rgb,vec3(1.),.75):vec3(1.,.91,.42);
 vec3 c=mix(tint.rgb*.48,middle,smoothstep(.1,.5,heat));c=mix(c,hot,smoothstep(.69,.97,heat));
 ALBEDO=c*energy*.40;EMISSION=c*energy*(1.5+heat*1.6);ALPHA=mask*opacity;
}
