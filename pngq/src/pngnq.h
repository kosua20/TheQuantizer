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


#include <stdlib.h>
#include <stdio.h>


void remap_floyd(unsigned char * rgba_data, unsigned int cols, unsigned int rows, unsigned char * map, unsigned int* remap,  unsigned char * indexed_data, int quantization_method);

void remap_simple(unsigned char * rgba_data, unsigned int cols, unsigned int rows, unsigned int* remap, unsigned char * indexed_data);
