// Style A, "Anime Match": the set painted to sit with Eco's VRoid toon shading.
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

#define CONCEPT_FLAT 3.6
#define CONCEPT_CEL_SOFT 0.06
#define CONCEPT_POSTERIZE 6.0
#define CONCEPT_SATURATION 0.95
#define CONCEPT_SHADOW vec4(0.62, 0.55, 0.85, 0.55)
#define CONCEPT_LAMP_ENERGY 0.7
#define CONCEPT_LAMP_NEUTRAL 0.5
#include "res://tools/art/concept_surface.gdshaderinc"
