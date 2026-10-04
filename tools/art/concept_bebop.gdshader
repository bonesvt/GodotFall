// Style B, "90s Session": cel anime over gouache-painted backgrounds.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#define CONCEPT_FLAT 2.8
#define CONCEPT_CEL_SOFT 0.025
#define CONCEPT_POSTERIZE 4.0
#define CONCEPT_SATURATION 0.8
#define CONCEPT_SHADOW vec4(0.35, 0.45, 0.60, 0.5)
#define CONCEPT_LAMP_ENERGY 1.0
#define CONCEPT_LAMP_NEUTRAL 0.2
#define CONCEPT_DETAIL 0.45
#include "res://tools/art/concept_surface.gdshaderinc"
