#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

typedef struct {
  int length;  /* How many entries in this vector */
  long *indices;  /* Indices of vector entries */
  float *values;  /* Values of vector entries */
} sparse_vec;

#define debug 0


MODULE = AI::Categorizer::FeatureVector::FastDot         PACKAGE = AI::Categorizer::FeatureVector::FastDot

PROTOTYPES: DISABLE

SV *
_make_array(indices_r, values_r)
    SV *indices_r
    SV *values_r
  CODE:
    {
      AV *indices, *values;
      SV *output;
      sparse_vec *vec;
      I32 i;
      
      if (debug) warn("starting\n");
      if (!SvROK(indices_r) || (SvTYPE(SvRV(indices_r)) != SVt_PVAV)) {
	croak("first parameter to _make_array() was not an array reference");
      }
      if (!SvROK(values_r)  || (SvTYPE(SvRV(values_r))  != SVt_PVAV)) {
	croak("second parameter to _make_array() was not an array reference");
      }
      
      if (debug) warn("Checked input\n");
      indices = (AV*) SvRV(indices_r);
      values = (AV*) SvRV(values_r);
      New(0, vec, 1, sparse_vec);
      
      if (debug) warn("Created struct\n");
      vec->length = av_len(indices) + 1;
      if (av_len(values) + 1 != vec->length) {
	croak("array lengths don't match");
      }
      New(0, vec->indices, vec->length, long);
      New(0, vec->values,  vec->length, float);
      
      for (i=0; i<vec->length; i++) {
	vec->indices[i] = SvIV(*av_fetch(indices, i, 0));
	vec->values[i]  = (float) SvNV(*av_fetch(values,  i, 0));
      }
      
      /* Wrap in an SV */
      if (debug) warn("wrapping in SV\n");
      output = newSViv((IV)vec);
      if (debug) warn("wrapped in SV\n");
      RETVAL = output;
    }
  OUTPUT:
    RETVAL


double
_dot(v1_r, v2_r)
    SV *v1_r
    SV *v2_r
  CODE:
    {
      float sum = 0;
      int i1 = 0, i2 = 0;
      sparse_vec *v1 = (sparse_vec *)SvIV(v1_r);
      sparse_vec *v2 = (sparse_vec *)SvIV(v2_r);

      while (i1 < v1->length && i2 < v2->length) {
	if (debug) warn("Beginning dot-loop\n");

	if (v1->indices[i1] == v2->indices[i2]) {
	  /* Indices here are equal, so add to sum */
	  sum += v1->values[i1] * v2->values[i2];
	  i1++;
	  i2++;
	} else if (v1->indices[i1] > v2->indices[i2]) {
	  i2++;
	} else {
	  i1++;
	}
      }
      
      RETVAL = (double) sum;
    }
  OUTPUT:
    RETVAL
