// Style B, "90s Session": cel anime over gouache-painted backgrounds.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#define CONCEPT_FLAT 2.0
#define CONCEPT_CEL_SOFT 0.025
#define CONCEPT_POSTERIZE 0.0
#define CONCEPT_SATURATION 0.8
#define CONCEPT_SHADOW vec4(0.30, 0.36, 0.55, 0.42)
#include "res://tools/art/concept_surface.gdshaderinc"
