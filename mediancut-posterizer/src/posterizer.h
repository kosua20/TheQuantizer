/**
 Median Cut Posterizer
 © 2011-2012 Kornel Lesiński.

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 See the GNU General Public License for more details:
 <http://www.gnu.org/copyleft/gpl.html>
*/


#include <stdbool.h>

void posterizer(unsigned char * rgbaData, unsigned int w, unsigned int h, unsigned int maxLevels, float gamma, bool dither);

void blurizer(unsigned char * rgbaData, unsigned int w, unsigned int h, unsigned int maxLevels, float gamma);
