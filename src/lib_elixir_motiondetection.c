#include <setjmp.h>
#include <stdio.h>
#include <strings.h>
#include <unistd.h>
#include <erl_nif.h>
#include <jpeglib.h>
#include <jerror.h>

#define MAXBUFLEN 1024
#define UNUSED(x) (void)(x)
#define error(msg) enif_make_tuple2(env,enif_make_atom(env,"error"),enif_make_string(env,msg,ERL_NIF_LATIN1))

struct error_mgr {
	struct jpeg_error_mgr pub;
	jmp_buf setjmp_buffer;
};

typedef struct error_mgr * error_ptr;

void error_exit (j_common_ptr cinfo) {
	error_ptr err = (error_ptr) cinfo->err;
	(*cinfo->err->output_message) (cinfo);
	longjmp(err->setjmp_buffer, 1);
}

static ERL_NIF_TERM _test(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
	UNUSED(argc);

	char result[MAXBUFLEN];
	char path[MAXBUFLEN];

	enif_get_string(env, argv[0], path, 1024, ERL_NIF_LATIN1);
	return enif_make_string(env, result, ERL_NIF_LATIN1);
}

static ERL_NIF_TERM _load(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]){
	UNUSED(argc);

	ErlNifBinary in,out;
	struct jpeg_decompress_struct cinfo;
	struct error_mgr jerr;
	unsigned int width, height;

	enif_inspect_binary(env,argv[0],&in);

	cinfo.err = jpeg_std_error(&jerr.pub);
	jerr.pub.error_exit = error_exit;
	if (setjmp(jerr.setjmp_buffer)) {
		jpeg_destroy_decompress(&cinfo);
		return -1;
	}

	jpeg_create_decompress(&cinfo);

	jpeg_mem_src(&cinfo, in.data, in.size);
	jpeg_read_header (&cinfo, TRUE);

	width = cinfo.image_width;
	height = cinfo.image_height;

	enif_alloc_binary(width*height*3,&out);

	cinfo.do_block_smoothing = TRUE;
	cinfo.do_fancy_upsampling = TRUE;
	cinfo.out_color_space = JCS_RGB;

	jpeg_start_decompress(&cinfo);

	JSAMPROW rowp[1];
	unsigned long location = 0;

	rowp[0] = (unsigned char*) malloc(cinfo.output_width*cinfo.num_components);

	unsigned int i = 0;
	while (cinfo.output_scanline < cinfo.output_height){
		jpeg_read_scanlines(&cinfo, rowp, 1);
		for( i=0; i<cinfo.image_width*cinfo.num_components;i++)
			out.data[location++] = rowp[0][i];
	}

	free(rowp[0]);

	jpeg_finish_decompress (&cinfo);
	jpeg_destroy_decompress (&cinfo);

	return	enif_make_tuple2(env,
				enif_make_atom(env,"ok"),
				enif_make_tuple3(env,
					enif_make_int(env,width),
					enif_make_int(env,height),
					enif_make_binary(env, &out)
				)
			);
}

static ERL_NIF_TERM _compare(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]){
	UNUSED(argc);

	ErlNifBinary b1,b2;
	int pos,minpos,step,min;

	enif_inspect_binary(env,argv[0],&b1);
	enif_inspect_binary(env,argv[1],&b2);
	enif_get_int(env,argv[2],&pos);
	enif_get_int(env,argv[3],&minpos);
	enif_get_int(env,argv[4],&step);
	enif_get_int(env,argv[5],&min);

	double result = 0.0;
	int startpos = pos;

	while(pos>minpos){
		int R = abs(b1.data[pos-2]-b2.data[pos-2]);
		int G = abs(b1.data[pos-1]-b2.data[pos-1]);
		int B = abs(b1.data[pos]-b2.data[pos]);
		int M = R+G+B;

		if(M >= min)
			result += 1;

		pos = pos-3*step;
	}

	return enif_make_double(env,result/((startpos-minpos)/step));
}

static int load(ErlNifEnv* env, void** priv, ERL_NIF_TERM load_info) {
	UNUSED(env);
	UNUSED(priv);
	UNUSED(load_info);
	return 0;
}

static void unload(ErlNifEnv* env, void* priv) {
	UNUSED(env);
	UNUSED(priv);
	return;
}

static int upgrade(ErlNifEnv* env, void** priv, void** old_priv, ERL_NIF_TERM load_info) {
	UNUSED(env);
	UNUSED(priv);
	UNUSED(old_priv);
	UNUSED(load_info);
	return 0;
}

static ErlNifFunc nif_funcs[] = {
	{"_test", 1, _test},
	{"_load", 1, _load},
	{"_compare", 6, _compare},
};

ERL_NIF_INIT(Elixir.EvercamMedia.MotionDetection.Lib,nif_funcs, &load, NULL, &upgrade, &unload);
