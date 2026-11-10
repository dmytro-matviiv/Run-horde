shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint:source_color=vec4(1.,.6,.1,1.);
uniform float age=0.;
uniform float energy=1.;
uniform float opacity=1.;
uniform float style=0.;
void vertex(){
 vec3 center=MODEL_MATRIX[3].xyz;
 vec3 right=INV_VIEW_MATRIX[0].xyz*length(MODEL_MATRIX[0].xyz);
 vec3 up=INV_VIEW_MATRIX[1].xyz*length(MODEL_MATRIX[1].xyz);
 POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(center+right*VERTEX.x+up*VERTEX.y,1.);
}
void fragment(){
 vec2 p=UV*2.-1.;float r=length(p);float mask;
 if(style<.5){mask=pow(max(0.,1.-r),2.);}
 else if(style<1.5){float cross=pow(max(0.,1.-abs(p.x)),18.)*pow(max(0.,1.-abs(p.y)),.8)+pow(max(0.,1.-abs(p.y)),18.)*pow(max(0.,1.-abs(p.x)),.8);mask=clamp(cross+pow(max(0.,1.-r),4.)*.5,0.,1.);}
 else{float ring=exp(-pow((r-.72)*25.,2.));float ripple=exp(-pow((r-.47)*36.,2.));float gate=smoothstep(1.,.95,r);mask=(ring+ripple*.27)*gate;}
 vec3 c=mix(tint.rgb,vec3(1.),pow(max(0.,1.-r),8.)*.55);
 ALBEDO=c*energy*.5;EMISSION=c*energy*1.8;ALPHA=mask*opacity;
}
