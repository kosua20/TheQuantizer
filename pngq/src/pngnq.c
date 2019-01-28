
/* pngnq.c - quantize the colors in an alphamap down to 256 using
 **  the Neuquant algorithm.
 **
 ** Based on Greg Roelf's pngquant which was itself based on Jef Poskanzer's ppmquant.
 ** Uses Anthony Dekker's Neuquant algorithm extended to handle the alpha channel.
 ** Rewritten by Kornel Lesiński (2009)
 
 **
 ** Copyright (C) 1989, 1991 by Jef Poskanzer.
 ** Copyright (C) 1997, 2000, 2002 by Greg Roelofs; based on an idea by
 **                                Stefan Schneider.
 ** Copyright (C) 2004-2009 by Stuart Coyle
 ** Copyright (C) Kornel Lesiński (2009)
 
 ** Permission to use, copy, modify, and distribute this software and its
 ** documentation for any purpose and without fee is hereby granted, provided
 ** that the above copyright notice appear in all copies and that both that
 ** copyright notice and this permission notice appear in supporting
 ** documentation.  This software is provided "as is" without express or
 ** implied warranty.
 */

/* NeuQuant Neural-Net Quantization Algorithm
 * ------------------------------------------
 *
 * Copyright (c) 1994 Anthony Dekker
 *
 * NEUQUANT Neural-Net quantization algorithm by Anthony Dekker, 1994.
 * See "Kohonen neural networks for optimal colour quantization"
 * in "Network: Computation in Neural Systems" Vol. 5 (1994) pp 351-367.
 * for a discussion of the algorithm.
 * See also  http://members.ozemail.com.au/~dekker/NEUQUANT.HTML
 *
 * Any party obtaining a copy of these files from the author, directly or
 * indirectly, is granted, free of charge, a full and unrestricted irrevocable,
 * world-wide, paid up, royalty-free, nonexclusive right and license to deal
 * in this software and documentation files (the "Software"), including without
 * limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons who receive
 * copies from any such party to do so, with the only requirement being
 * that this copyright notice remain intact.
 *
 */


#define PNGNQ_VERSION VERSION //"0.9 ($Date: 2009-01-25 22:39:19 +0000 (Sun, 25 Jan 2009) $)"

#define FNMAX 1024
#define PNGNQ_USAGE "\
Usage:  pngnq [-fhvV][-d dir][-e ext.][-g gamma][-n colours][-Q dither][-s speed][input files]\n\
Options:\n\
-n Number of colours the quantized image is to contain. Range: 16 to 256. Defaults to 256.\n\
-d Directory to put quantized images into.\n\
-e Specify the new extension for quantized files. Default -nq8.png\n\
-f Force ovewriting of files.\n\
-g Image gamma. 1.0 = linear, 2.2 = monitor gamma. Defaults to 1.8.\n\
-h Print this help.\n\n\
-Q Quantization: n = no dithering (default), f = floyd-steinberg\n\
-s Speed/quality: 1 = slow, best quality, 3 = good quality, 10 = fast, lower quality.\n\
-v Verbose mode. Prints status messages.\n\
-V Print version number and library versions.\n\
input files: The png files to be processed. Defaults to standard input if not specified.\n\n\
\
Quantizes a 32-bit RGBA PNG image to an 8 bit RGBA palette PNG\n\
using the neuquant algorithm. The output file name is the input file name\n\
extended with \"-nq8.png\"\n"

#include "config.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h> /* isprint() and features.h */


#include "neuquant32.h"
#include "errors.h"

typedef unsigned char uch;
typedef unsigned long ulg;

typedef struct {
	uch r, g, b, a;
} pixel;

/* Image information struct */
//static mainprog_info rwpng_info;


//static int pngnq(char* filename, char* newext, char* dir,
//		 int sample_factor, int n_colors, int verbose,
//		 int using_stdin, int force, int use_floyd, double force_gamma);



/*
 int sample_factor = 0;
 
 int force = 0;
 int c;
 
 
 int n_colours = colorCount, 2, 256;
 int use_floyd = shouludDIther;
 
 double force_gamma = 0;
 
 pngnq(input_file_name, output_file_extension, output_directory,
 sample_factor0, colorCount, verbose0, using_stdin0,force0,use_floyd,force_gamma0);
 */




 void remap_floyd(network_data * networkdata, unsigned char * rgba_data, unsigned int cols, unsigned int rows, unsigned char * map, unsigned int* remap,  unsigned char * indexed_data, int quantization_method)
{
	// uch *outrow = NULL; /* Output image pixels */
	
	int i,row;
#define CLAMP(a) ((a)>=0 ? ((a)<=255 ? (a) : 255)  : 0)
	
	/* Do each image row */
	for ( row = 0; (ulg)row < rows; ++row ) {
		int offset, nextoffset;
		
		
		int rederr=0;
		int blueerr=0;
		int greenerr=0;
		int alphaerr=0;
		
		offset = row*cols*4;
		nextoffset = offset; if (row+1<rows) nextoffset += cols*4;
		int increment = 4;
		
		for( i=0;i<cols;i++, offset+=increment, nextoffset+=increment)
		{
			int idx;
			unsigned int floyderr = rederr*rederr + greenerr*greenerr + blueerr*blueerr + alphaerr*alphaerr;
			
			idx = inxsearch(networkdata, CLAMP(rgba_data[offset+3] - alphaerr),
							CLAMP(rgba_data[offset+2] - blueerr),
							CLAMP(rgba_data[offset+1] - greenerr),
							CLAMP(rgba_data[offset]   - rederr  ));
			
			indexed_data[row*cols + (increment > 0 ? i : cols-i-1)] = remap[idx];
			
			int alpha = (map[idx*4+3] > rgba_data[offset+3]) ? map[idx*4+3] : rgba_data[offset+3];
			int colorimp = 255 - ((255-alpha) * (255-alpha) / 255);
			
			int thisrederr=(map[idx*4+0] -   rgba_data[offset]) * colorimp   / 255;
			int thisblueerr=(map[idx*4+1] - rgba_data[offset+1]) * colorimp  / 255;
			int thisgreenerr=(map[idx*4+2] -  rgba_data[offset+2]) * colorimp  / 255;
			int thisalphaerr=map[idx*4+3] - rgba_data[offset+3];
			
			rederr += thisrederr;
			greenerr += thisblueerr;
			blueerr +=  thisgreenerr;
			alphaerr += thisalphaerr;
			
			unsigned int thiserr = (thisrederr*thisrederr + thisblueerr*thisblueerr + thisgreenerr*thisgreenerr + thisalphaerr*thisalphaerr)*2;
			floyderr = rederr*rederr + greenerr*greenerr + blueerr*blueerr + alphaerr*alphaerr;
			
			int L = 10;
			while (rederr*rederr > L*L || greenerr*greenerr > L*L || blueerr*blueerr > L*L || alphaerr*alphaerr > L*L ||
				   floyderr > thiserr || floyderr > L*L*2)
			{
				rederr /=2;greenerr /=2;blueerr /=2;alphaerr /=2;
				floyderr = rederr*rederr + greenerr*greenerr + blueerr*blueerr + alphaerr*alphaerr;
			}
			
			if (i>0)
			{
				rgba_data[nextoffset-increment+3]=CLAMP(rgba_data[nextoffset-increment+3] - alphaerr*3/16);
				rgba_data[nextoffset-increment+2]=CLAMP(rgba_data[nextoffset-increment+2] - blueerr*3/16 );
				rgba_data[nextoffset-increment+1]=CLAMP(rgba_data[nextoffset-increment+1] - greenerr*3/16);
				rgba_data[nextoffset-increment]  =CLAMP(rgba_data[nextoffset-increment]   - rederr*3/16  );
			}
			if (i+1<cols)
			{
				rgba_data[nextoffset+increment+3]=CLAMP(rgba_data[nextoffset+increment+3] - alphaerr/16);
				rgba_data[nextoffset+increment+2]=CLAMP(rgba_data[nextoffset+increment+2] - blueerr/16 );
				rgba_data[nextoffset+increment+1]=CLAMP(rgba_data[nextoffset+increment+1] - greenerr/16);
				rgba_data[nextoffset+increment]  =CLAMP(rgba_data[nextoffset+increment]   - rederr/16  );
			}
			rgba_data[nextoffset+3]=CLAMP(rgba_data[nextoffset+3] - alphaerr*5/16);
			rgba_data[nextoffset+2]=CLAMP(rgba_data[nextoffset+2] - blueerr*5/16 );
			rgba_data[nextoffset+1]=CLAMP(rgba_data[nextoffset+1] - greenerr*5/16);
			rgba_data[nextoffset]  =CLAMP(rgba_data[nextoffset]   - rederr*5/16  );
		}
		
		rederr = rederr*7/16; greenerr =greenerr*7/16; blueerr =blueerr*7/16; alphaerr =alphaerr*7/16;
		
	}
	
}

 void remap_simple(network_data * networkdata, unsigned char * rgba_data, unsigned int cols, unsigned int rows, unsigned int* remap, unsigned char * indexed_data)
{
	unsigned int i,row;
	unsigned int offset;
	/* Do each image row */
	for ( row = 0; (ulg)row < rows; ++row )
	{
		/* Assign the new colors */
		offset = row*cols*4;
		for( i=0;i<cols;i++){
			indexed_data[row*cols+i] = remap[inxsearch(networkdata, rgba_data[i*4+offset+3],
													   rgba_data[i*4+offset+2],
													   rgba_data[i*4+offset+1],
													   rgba_data[i*4+offset])];
		}
		
	}
	
	
}

//
//static int pngnq(unsigned char * rgba_data, unsigned int width, unsigned int height,
//				 int n_colours, int use_dithering)
//{
//	
//	
//	int bot_idx, top_idx; /* for remapping of indices */
//	unsigned int remap[MAXNETSIZE];
//	unsigned char map[MAXNETSIZE][4];
//	int x;
//	unsigned char * indexed_data = NULL; /* Pointer to output */
//	ulg cols, rows;
//	int newcolors = n_colours;
//	
//	double quantization_gamma = 1.8;
//	
//	cols = width;
//	rows = height;
//	int sample_factor = 1 + (unsigned int)(rows*cols / (512*512));
//	if (sample_factor > 10){ sample_factor = 10;}
//	
//	
//	/* Start neuquant */
//	initnet(rgba_data, (unsigned int)(rows*cols)*4, newcolors, quantization_gamma);
//	learn(sample_factor, 0);
//	inxbuild();
//	getcolormap((unsigned char*)map);
//	
//	/* Remap indexes so all tRNS chunks are together */
//	for (top_idx = newcolors-1, bot_idx = x = 0;  x < newcolors;  ++x) {
//		if (map[x][3] == 255) /* maxval */
//			remap[x] = top_idx--;
//		else
//			remap[x] = bot_idx++;
//	}
//	
//	/* sanity check:  top and bottom indices should have just crossed paths */
//	if (bot_idx != top_idx + 1) {
//		return 18;
//	}
//	
//	
//	/* Allocate memory*/
//	indexed_data = (unsigned char *)malloc(cols*rows);
//	
//	if (use_dithering > 0)
//	{
//		remap_floyd(rgba_data, cols, rows,map,remap, indexed_data, 1);
//	}
//	else
//	{
//		remap_simple(rgba_data, cols,rows,remap,indexed_data);
//	}
//	
//	// Write everything.
//	// TODO: rewrite same with lodepng
//	//	rwpng_info.sample_depth = 8;
//	//	rwpng_info.num_palette = newcolors;
//	//	rwpng_info.num_trans = bot_idx;
//	//
//	//	/* Remap and make palette entries */
//	//	for (x = 0; x < newcolors; ++x) {
//	//		rwpng_info.palette[remap[x]].red  = map[x][0];
//	//		rwpng_info.palette[remap[x]].green = map[x][1];
//	//		rwpng_info.palette[remap[x]].blue = map[x][2];
//	//		rwpng_info.trans[remap[x]] = map[x][3];
//	//	}
//	
//	return 0;
//}
//

