// Style A, "Anime Match": the set painted to sit with Eco's VRoid toon shading.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#define CONCEPT_FLAT 2.6
#define CONCEPT_CEL_SOFT 0.06
#define CONCEPT_POSTERIZE 0.0
#define CONCEPT_SATURATION 1.15
#define CONCEPT_SHADOW vec4(0.62, 0.55, 0.85, 0.55)
#include "res://tools/art/concept_surface.gdshaderinc"
