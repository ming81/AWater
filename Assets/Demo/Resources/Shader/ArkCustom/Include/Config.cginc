#ifndef _MINIPBR_CONFIG_
#define _MINIPBR_CONFIG_

#include "UnityCG.cginc"

// Quality Keyword : CARAVA_KEYWORD_QUALITY_HIGHEST, CARAVA_KEYWORD_QUALITY_MEDIUM, CARAVA_KEYWORD_QUALITY_LOWEST

// Shading Model Keyword : 


// Input
// Optional Defines : USE_NORMAL_MAP, USE_MSA_MAP
#if defined(CARAVA_KEYWORD_QUALITY_HIGHEST) || defined(CARAVA_KEYWORD_QUALITY_MEDIUM)
	#define USE_NORMAL_MAP
#endif

// GI
// Optional Defines : USE_REFLECTION
#if defined(CARAVA_KEYWORD_QUALITY_HIGHEST)
	#define USE_REFLECTION
#endif


// Shading
// Diffuse Optional Defines : USE_CARTOON_LAMBERT

// Specular BRDF Optional Defines : USE_GGX_STANDARD, USE_GGX_OPTIMIZED, USE_BLINN_PHONG
#if defined(CARAVA_KEYWORD_QUALITY_HIGHEST)
	#define USE_GGX_STANDARD
#elif defined(CARAVA_KEYWORD_QUALITY_MEDIUM)
	#define USE_GGX_OPTIMIZED
#endif


#endif 