#define CHECK(test) { if (!(test)) { goto fail; } }

#define CHECKM(test, msg) { if (!(test)) { message = msg; goto fail; } }

#define OOM "Out of memory!"

enum pdl_datatypes { PDL_B, PDL_S, PDL_US, PDL_L, PDL_LL, PDL_F, PDL_D };

RAL_INTEGER int_from_pdl(void *x, int datatype, int i) {
    switch (datatype) {
    case PDL_L: 
    {	
	int *xx = (int *) x;
	return (RAL_INTEGER)xx[i];
    }break;
    case PDL_F:
    {   	
	float *xx = (float *) x;
	return (RAL_INTEGER)xx[i];	
    }break;    
    case PDL_S:
    {   	
	short *xx = (short *) x;
	return (RAL_INTEGER)xx[i];	
    }break;    
    case PDL_US:
    {   	
	unsigned short *xx = (unsigned short *) x;
	return (RAL_INTEGER)xx[i];	
    }break;
    case PDL_D:
    {   	
	double *xx = (double *) x;
	return (RAL_INTEGER)xx[i];	
    }break;
    case PDL_B:
    {   	
	unsigned char *xx = (unsigned char *) x;
	return (RAL_INTEGER)xx[i];	
    }break;    
    case PDL_LL:
    {   	
	long long *xx = (long long *) x;
	return (RAL_INTEGER)xx[i];	
    }break;    
    default:
	croak ("Not a known data type code=%d", datatype);
    }
}


RAL_REAL real_from_pdl(void *x, int datatype, int i) {
    switch (datatype) {
    case PDL_L:
    {	
	int *xx = (int *) x;
	return (RAL_REAL)xx[i];
    }break;
    case PDL_F:
    {   	
	float *xx = (float *) x;
	return (RAL_REAL)xx[i];	
    }break;    
    case PDL_S:
    {   	
	short *xx = (short *) x;
	return (RAL_REAL)xx[i];	
    }break;    
    case PDL_US:
    {   	
	unsigned short *xx = (unsigned short *) x;
	return (RAL_REAL)xx[i];	
    }break;
    case PDL_D:
    {   	
	double *xx = (double *) x;
	return (RAL_REAL)xx[i];	
    }break;
    case PDL_B:
    {   	
	unsigned char *xx = (unsigned char *) x;
	return (RAL_REAL)xx[i];	
    }break;    
    case PDL_LL:
    {   	
	long long *xx = (long long *) x;
	return (RAL_REAL)xx[i];	
    }break;    
    default:
	croak ("Not a known data type code=%d", datatype);
    }
}
 

IV SV2Handle(SV *sv)
{
    if (SvGMAGICAL(sv))
	mg_get(sv);
    if (!sv_isobject(sv))
	croak("parameter is not an object");
    SV *tsv = (SV*)SvRV(sv);
    if ((SvTYPE(tsv) != SVt_PVHV))
	croak("parameter is not a hashref");
    if (!SvMAGICAL(tsv))
	croak("parameter does not have magic");
    MAGIC *mg = mg_find(tsv,'P');
    if (!mg)
	croak("parameter does not have right kind of magic");
    sv = mg->mg_obj;
    if (!sv_isobject(sv))
	croak("parameter does not have really right kind of magic");
    return SvIV((SV*)SvRV(sv));
}

IV SV2Object(SV *sv, char *stash)
{
    if (!sv_isobject(sv)) {
	croak("parameter is not an object");
	return 0;
    }
    sv = (SV*)SvRV(sv);
    if (strcmp(stash,HvNAME((HV*)SvSTASH(sv)))!=0) {
	croak("parameter is not a %s",stash);
	return 0;
    }
    return SvIV(sv);
}

GDALColorEntry fetch_color(AV *a, int i)
{
    GDALColorEntry color;
    SV **s = av_fetch(a, i++, 0);
    color.c1 = s ? SvUV(*s) : 0;
    s = av_fetch(a, i++, 0);
    color.c2 = s ? SvUV(*s) : 0;
    s = av_fetch(a, i++, 0);
    color.c3 = s ? SvUV(*s) : 0;
    s = av_fetch(a, i++, 0);
    color.c4 = s ? SvUV(*s) : 0;
    return color;
}

#define RAL_FETCH(from, key, to, as)			\
    {SV **s = hv_fetch(from, key, strlen(key), 0);	\
	if (s) {					\
	    (to) = as(*s);				\
	}}

#define RAL_STORE(to, key, from, with)		\
    hv_store(to, key, strlen(key), with(from), 0);


/* convert a focal area expressed as an array of arrays to a simple int array 
   the focal area is a M x M square, where M is an odd number and the center of the
   square is the cell of interest 
   d is defined by 2*d+1 = M
   the length of the returned array is M x M
   M is >= 1
*/
int *focal2mask(AV *focal, int *d, int defined_is_enough)
{
    char *message = NULL;
    int *mask = NULL;
    int i, j, m = av_len(focal)+1, M = -1, ix;
    /* get the M */
    for (i = 0; i < m; i++) {
	SV **s = av_fetch(focal, i, 0);
	CHECKM(SvROK(*s) && SvTYPE(SvRV(*s)) == SVt_PVAV, 
		   "the focal area parameter must be a reference to an array of arrays");
	M = M < 0 ? av_len((AV*)SvRV(*s))+1 : max(M, av_len((AV*)SvRV(*s))+1);
    }
    M = max(max(m, M), 1);
    *d = (M-1)/2;
    M = 2*(*d)+1;
    ix = 0;
    SV *sv;
    CHECKM(mask = (int *)calloc(M*M, sizeof(int)), OOM);
    for (i = 0; i < M; i++) {
	if (i < m) {
	    SV **s = av_fetch(focal, i, 0);
	    int n = av_len((AV*)SvRV(*s))+1;
	    for (j = 0; j < M; j++) {
		if (j < n) {
		    SV **t = av_fetch((AV*)SvRV(*s), j, 0);
		    if (t && *t && SvOK(*t)) {
			if (defined_is_enough)
			    mask[ix] = 1;
			else
			    mask[ix] = SvIV(*t) ? 1 : 0;
		    } else
			mask[ix] = 0;
		} else
		    mask[ix] = 0;
		ix++;
	    }
	} else 
	    for (j = 0; j < M; j++) {
		mask[ix] = 0;
		ix++;
	    }
    }
    return mask;
fail:
    if(mask) free(mask);
    if(message) croak(message);
    return NULL;
}

/* convert a focal area expressed as an array of arrays to a simple double array 
   the focal area is a M x M square, where M is an odd number and the center of the
   square is the cell of interest 
   d is defined by 2*d+1 = M
   the length of the returned array is M x M
   M is >= 1
*/
double *focal2maskd(AV *focal, int *d, int defined_is_enough)
{
    char *message = NULL;
    double *mask = NULL;
    int i, j, m = av_len(focal)+1, M = -1, ix;
    /* get the M */
    for (i = 0; i < m; i++) {
	SV **s = av_fetch(focal, i, 0);
	CHECKM(SvROK(*s) && SvTYPE(SvRV(*s)) == SVt_PVAV, 
		   "the focal area parameter must be a reference to an array of arrays");
	M = M < 0 ? av_len((AV*)SvRV(*s))+1 : max(M, av_len((AV*)SvRV(*s))+1);
    }
    M = max(max(m, M), 1);
    *d = (M-1)/2;
    M = 2*(*d)+1;
    ix = 0;
    SV *sv;
    CHECKM(mask = (double *)calloc(M*M, sizeof(double)), OOM);
    for (i = 0; i < M; i++) {
	if (i < m) {
	    SV **s = av_fetch(focal, i, 0);
	    int n = av_len((AV*)SvRV(*s))+1;
	    for (j = 0; j < M; j++) {
		if (j < n) {
		    SV **t = av_fetch((AV*)SvRV(*s), j, 0);
		    if (t && *t && SvOK(*t)) {
			if (defined_is_enough)
			    mask[ix] = 1;
			else
			    mask[ix] = SvNV(*t) ? 1 : 0;
		    } else
			mask[ix] = 0;
		} else
		    mask[ix] = 0;
		ix++;
	    }
	} else 
	    for (j = 0; j < M; j++) {
		mask[ix] = 0;
		ix++;
	    }
    }
    return mask;
fail:
    if(mask) free(mask);
    return NULL;
}

int fetch2visual(HV *perl_layer, ral_visual *visual)
{
    /* these are mostly from the Geo::Layer object */
    SV **s, **s2, **s3;
    int symbol_size_property_type;
    int color_property_type;
    int ok;
    s = hv_fetch(perl_layer, "ALPHA", strlen("ALPHA"), 0);
    if (s && SvIOK(*s)) 
	ral_visual_set_alpha(visual, SvIV(*s));
    else 
	croak("Did not get alpha from the layer.");

    s = hv_fetch(perl_layer, "SYMBOL_VALUE", strlen("SYMBOL_VALUE"), 0);
    if (s && SvIOK(*s)) 
	ral_visual_set_symbol(visual, SvIV(*s)); 
    else 
	croak("Did not get symbol from the layer.");

    s = hv_fetch(perl_layer, "SYMBOL_SIZE", strlen("SYMBOL_SIZE"), 0);
    if (s && SvIOK(*s)) 
	ral_visual_set_symbol_size(visual, SvIV(*s));
    else 
	croak("Did not get symbol size from the layer.");

    s = hv_fetch(perl_layer, "SYMBOL_SIZE_PROPERTY", strlen("SYMBOL_SIZE_PROPERTY"), 0);
    if (s && SvPOK(*s)) 
	ral_visual_set_symbol_size_property(visual, SvPV_nolen(*s));
    else 
	croak("Did not get symbol size property from the layer.");

    s = hv_fetch(perl_layer, "SYMBOL_SIZE_PROPERTY_TYPE", strlen("SYMBOL_SIZE_PROPERTY_TYPE"), 0);
    if (s && SvIOK(*s)) {
	symbol_size_property_type = SvIV(*s);
	ral_visual_set_symbol_size_property_type(visual, SvIV(*s));
    } else 
	croak("Did not get symbol size property type from the layer.");

    s = hv_fetch(perl_layer, "SYMBOL_SIZE_SCALE_MIN", strlen("SYMBOL_SIZE_SCALE_MIN"), 0);
    s2 = hv_fetch(perl_layer, "SYMBOL_SIZE_SCALE_MAX", strlen("SYMBOL_SIZE_SCALE_MAX"), 0);
    if (s && SvNOK(*s) && s2 && SvNOK(*s2)) 
	ral_visual_set_symbol_size_scale(visual, SvNV(*s), SvNV(*s2));
    else 
	croak("Did not get symbol size scale from the layer.");

    s = hv_fetch(perl_layer, "PALETTE_TYPE_VALUE", strlen("PALETTE_TYPE_VALUE"), 0);
    if (s && SvIOK(*s))
	ral_visual_set_palette_type(visual, SvIV(*s));
    else
	croak("Did not get palette type from the layer.");

    s = hv_fetch(perl_layer, "SINGLE_COLOR", strlen("SINGLE_COLOR"), 0);
    if (s && SvROK(*s)) {
	AV *a = (AV*)SvRV(*s);
	if (a) {
	    int i = 0;
	    s = av_fetch(a, i++, 0);
	    uint r = s ? SvUV(*s) : 0;
	    s = av_fetch(a, i++, 0);
	    uint g = s ? SvUV(*s) : 0;
	    s = av_fetch(a, i++, 0);
	    uint b = s ? SvUV(*s) : 0;
	    s = av_fetch(a, i++, 0);
	    uint alpha = s ? SvUV(*s) : 0;
	    ral_visual_set_single_color(visual, r, g, b, alpha);
	}
    } else
	croak("Did not get single color from the layer.");

    s = hv_fetch(perl_layer, "COLOR_PROPERTY", strlen("COLOR_PROPERTY"), 0);
    if (s && SvPOK(*s)) 
	ral_visual_set_color_property(visual, SvPV_nolen(*s));
    else 
	croak("Did not get color property from the layer.");

    s = hv_fetch(perl_layer, "COLOR_PROPERTY_TYPE", strlen("COLOR_PROPERTY_TYPE"), 0);
    if (s && SvIOK(*s)) {
	color_property_type = SvIV(*s);
	ral_visual_set_color_property_type(visual, SvIV(*s));
    } else 
	croak("Did not get color property type from the layer.");

    s = hv_fetch(perl_layer, "COLOR_SCALE_MIN", strlen("COLOR_SCALE_MIN"), 0);
    s2 = hv_fetch(perl_layer, "COLOR_SCALE_MAX", strlen("COLOR_SCALE_MAX"), 0);
    if (s && SvNOK(*s) && s2 && SvNOK(*s2)) 
	ral_visual_set_color_scale(visual, SvNV(*s), SvNV(*s2));
    else 
	croak("Did not get color scale from the layer.");

    s = hv_fetch(perl_layer, "HUE_MIN", strlen("HUE_MIN"), 0);
    s2 = hv_fetch(perl_layer, "HUE_MAX", strlen("HUE_MAX"), 0);
    s3 = hv_fetch(perl_layer, "INVERT", strlen("INVERT"), 0);
    if (s && SvIOK(*s) && s2 && SvIOK(*s2) && s3 && SvIOK(*s3)) 
	ral_visual_set_hue_range(visual, SvIV(*s), SvIV(*s2), SvIV(*s3));
    else 
	croak("Did not get hue range from the layer.");

    s = hv_fetch(perl_layer, "GRAYSCALE_COLOR", strlen("GRAYSCALE_COLOR"), 0);
    s2 = hv_fetch(perl_layer, "GRAYSCALE_SUBTYPE_VALUE", strlen("GRAYSCALE_SUBTYPE_VALUE"), 0);
    if (s && SvROK(*s) && s2 && SvIOK(*s2)) {
	AV *a = (AV*)SvRV(*s);
	if (a) {
	    int i = 0;
	    s = av_fetch(a, i++, 0);
	    uint r = s ? SvUV(*s) : 0;
	    s = av_fetch(a, i++, 0);
	    uint g = s ? SvUV(*s) : 0;
	    s = av_fetch(a, i++, 0);
	    uint b = s ? SvUV(*s) : 0;
	    ral_visual_set_grayscale_base_color(visual, r, g, b, SvIV(*s2));
	}
    } else
	croak("Did not get grayscale color from the layer.");

    s = hv_fetch(perl_layer, "COLOR_TABLE", strlen("COLOR_TABLE"), 0);
    if (s && SvROK(*s)) {
	AV *a = (AV*)SvRV(*s);
	int i, n = a ? av_len(a)+1 : 0;
	if (n > 0) {
	    switch (color_property_type) {
	    case OFTInteger: {
		ral_color_table *table;
		CHECK(table = ral_color_table_create(n));
		for (i = 0; i < n; i++) {
		    SV **s = av_fetch(a, i, 0);
		    AV *c;
		    if (s && SvROK(*s) && (c = (AV*)SvRV(*s))) {
			s = av_fetch(c, 0, 0);
			if (s) ral_color_table_set(table, i, SvIV(*s), fetch_color(c, 1));
		    } else {
			ral_color_table_destroy(&table);
			ral_msg("Bad color table data");
			goto fail;
		    }
		}
		ral_visual_set_color_table(table);
		break;
	    }
	    case OFTString: {
		ral_string_color_table *table;
		CHECK(table = ral_string_color_table_create(n));
		for (i = 0; i < n; i++) {
		    SV **s = av_fetch(a, i, 0);
		    AV *c;
		    if (s && SvROK(*s) && (c = (AV*)SvRV(*s))) {
			s = av_fetch(c, 0, 0);
			if (s) ral_string_color_table_set(table, i, SvPV_nolen(*s), fetch_color(c, 1));
		    } else {
			ral_string_color_table_destroy(&table);
			ral_msg("Bad color table data");
			goto fail;
		    }
		}
		ral_visual_set_string_color_table(table);
		break;
	    }
	    default:
		ral_msg("Invalid property type for color table: %s", OGR_GetFieldTypeName(color_property_type));
		goto fail;
	    }
	}
    }
    s = hv_fetch(perl_layer, "COLOR_BINS", strlen("COLOR_BINS"), 0);
    if (s && SvROK(*s)) {
	AV *a = (AV*)SvRV(*s);
	int i, n = a ? av_len(a)+1 : 0;
	if (n > 0) {
	    switch (color_property_type) {
	    case OFTInteger: {
		ral_int_color_bins *bins;
		CHECK(bins = ral_int_color_bins_create(n));
		for (i = 0; i < n; i++) {
		    SV **s = av_fetch(a, i, 0);
		    AV *c;
		    if (s && SvROK(*s) && (c = (AV*)SvRV(*s))) {
			s = av_fetch(c, 0, 0);
			ral_int_color_bins_set(i, SvIV(*s), fetch_color(c, 1));
		    } else {
			ral_int_color_bins_destroy(&bins);
			ral_msg("Bad color bins data");
			goto fail;
		    }
		}
		ral_visual_set_int_color_bins(bins);
		break;
	    }
	    case OFTReal: {
		ral_double_color_bins *bins;
		CHECK(bins = ral_double_color_bins_create(n));
		for (i = 0; i < n; i++) {
		    SV **s = av_fetch(a, i, 0);
		    AV *c;
		    if (s && SvROK(*s) && (c = (AV*)SvRV(*s))) {
			s = av_fetch(c, 0, 0);
			ral_int_color_bins_set(i, SvNV(*s), fetch_color(c, 1));
		    } else {
			ral_double_color_bins_destroy(&bins);
			ral_msg("Bad color bins data");
			goto fail;
		    }
		}
		ral_visual_set_double_color_bins(bins);
		break;
	    }
	    default:
		ral_msg("Invalid property type for color bins: %s", OGR_GetFieldTypeName(color_property_type));
		goto fail;
	    }
	}
    }
    return 1;
fail:
    return 0;
}
