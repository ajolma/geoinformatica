#include <gtk2perl.h>
#include <cairo-perl.h>
#include <ral.h>

MODULE = Gtk2::Ex::Geo::Renderer		PACKAGE = Gtk2::Ex::Geo::Renderer

GdkPixbuf_noinc *
gdk_pixbuf_new_from_data(ral_pixbuf *pb)
	CODE:
		if (ral_cairo_to_pixbuf(pb))
			RETVAL = ral_gdk_pixbuf(pb);
	OUTPUT:
		RETVAL
	POSTCALL:
		if (ral_has_msg())
			croak(ral_get_msg());

void
gobject_really_unref (sv)
	SV *sv
	CODE:
	MAGIC *mg;
	GObject *object;

	if (!sv || !SvOK (sv) || !SvROK (sv) || !(mg = mg_find (SvRV (sv), PERL_MAGIC_ext)))
		return;
	object = (GObject *) mg->mg_ptr;
	fprintf(stderr,"ref count of %p = %d\n",object,object->ref_count);
	while (object->ref_count > 1) {
		g_object_unref (object);
	}
	fprintf(stderr,"ref count of %p = %d\n",object,object->ref_count);

unsigned char *
data_of_ral_pixbuf(pb)
	ral_pixbuf *pb
    CODE:
	fprintf(stderr, "image=%i\n", pb->image);
	RETVAL = pb->image;
    OUTPUT:
	RETVAL

cairo_surface_t_noinc *
cairo_surface_from_pb(pb)
	ral_pixbuf *pb
    CODE:
	RETVAL = cairo_image_surface_create_for_data
		(pb->image, CAIRO_FORMAT_ARGB32, pb->N, pb->M, pb->image_rowstride);
    OUTPUT:
	RETVAL
