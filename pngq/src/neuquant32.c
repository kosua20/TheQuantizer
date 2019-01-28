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
 *
 * Modified to process 32bit RGBA images.
 * Stuart Coyle 2004-2006
 *
 * Rewritten by Kornel Lesiński (2009)
 */


#include "neuquant32.h"
#include <math.h>
#include <stdlib.h>

/* 
    Network Definitions
*/
   
#define maxnetpos   (MAXNETSIZE-1)
#define ncycles     100                 /* no. of learning cycles */
#define ABS(a) ((a)>=0?(a):-(a))

/* defs for freq and bias */
#define gammashift  10                  /* gamma = 1024 */
#define gamma       ((double)(1<<gammashift))
#define betashift   10
#define beta        (1.0/(1<<betashift))/* beta = 1/1024 */
#define betagamma   ((double)(1<<(gammashift-betashift)))

/* defs for decreasing radius factor */
#define initradius  (initrad*1.0)       /* and decreases by a           */
#define radiusdec   30                  /* factor of 1/30 each cycle    */ 

/* defs for decreasing alpha factor */
#define alphabiasshift  10              /* alpha starts at 1.0 */
#define initalpha   ((double)(1<<alphabiasshift))
double alphadec;                        /* biased by 10 bits */

/* radbias and alpharadbias used for radpower calculation */
#define radbiasshift    8
#define radbias         (1<<radbiasshift)
#define alpharadbshift  (alphabiasshift+radbiasshift)
#define alpharadbias    ((double)(1<<alpharadbshift))




/* 
    Initialise network in range (0,0,0,0) to (255,255,255,255) and set parameters
*/
network_data* initnet(unsigned char *thepic,unsigned int len,unsigned int colours, double gamma_c)
{
    unsigned int i;
    network_data * networkdata = malloc(sizeof(network_data));
    networkdata->gamma_correction = gamma_c;
    
    /* Clear out network from previous runs */
    /* thanks to Chen Bin for this fix */
    memset((void*)(networkdata->network),0,sizeof(double)*4*MAXNETSIZE);

    networkdata->thepicture = thepic;
    networkdata->lengthcount = len;
    networkdata->netsize = colours;
    
    for(i=0;i<256;i++)
    {
        double temp;
        temp = pow(i/255.0, 1.0/networkdata->gamma_correction) * 255.0;
        temp = round(temp);
        networkdata->biasvalues[i] = temp;
    }
    
    for (i=0; i<networkdata->netsize; i++) {
        networkdata->network[i].b = networkdata->network[i].g = networkdata->network[i].r = biasvalue(networkdata, i*256/networkdata->netsize);
              
        /*  Sets alpha values at 0 for dark pixels. */
        if (i < 16) networkdata->network[i].al = (i*16); else networkdata->network[i].al = 255;
        
        networkdata->freq[i] = 1.0/networkdata->netsize;  /* 1/netsize */
        networkdata->bias[i] = 0;
    }
	
	return networkdata;
}

static unsigned int unbiasvalue(network_data * networkdata, double temp)
{
    if (temp < 0) return 0;
    
    temp = pow(temp/255.0, networkdata->gamma_correction) * 255.0;
    temp = floor((temp / 255.0 * 256.0));

    if (temp > 255) return 255;
    return temp;
}

static inline unsigned int round_biased(double temp)
{    
    if (temp < 0) return 0;
    temp = floor((temp / 255.0 * 256.0));
    
    if (temp > 255) return 255;    
    return temp;
}


inline static double biasvalue(network_data * networkdata, unsigned int temp)
{    
    return networkdata->biasvalues[temp];
}

/* Output colormap to unsigned char ptr in RGBA format */
void getcolormap(network_data * networkdata, unsigned char *map)
{
    unsigned int j;
    for(j=0; j<networkdata->netsize; j++)
    {
        *map++ = unbiasvalue(networkdata, networkdata->network[j].r);
        *map++ = unbiasvalue(networkdata, networkdata->network[j].g);
        *map++ = unbiasvalue(networkdata, networkdata->network[j].b);
        *map++ = round_biased(networkdata->network[j].al);
    }
}


/* Insertion sort of network and building of netindex[0..255] (to do after unbias)
   ------------------------------------------------------------------------------- */



void inxbuild(network_data * networkdata)
{
    unsigned int i,j,smallpos,smallval;
    unsigned int previouscol,startpos;

    for(i=0; i< networkdata->netsize; i++)
    {
        networkdata->colormap[i].r =  biasvalue(networkdata,unbiasvalue(networkdata, networkdata->network[i].r));
        networkdata->colormap[i].g =  biasvalue(networkdata, unbiasvalue(networkdata, networkdata->network[i].g));
        networkdata->colormap[i].b =  biasvalue(networkdata, unbiasvalue(networkdata, networkdata->network[i].b));
        networkdata->colormap[i].al = round_biased(networkdata->network[i].al);
    }
        
    previouscol = 0;
    startpos = 0;
    for (i=0; i<networkdata->netsize; i++) {
        smallpos = i;
        smallval = (networkdata->colormap[i].g);         /* index on g */
        /* find smallest in i..netsize-1 */
        for (j=i+1; j<networkdata->netsize; j++) {
            if ((networkdata->colormap[j].g) < smallval) {       /* index on g */
                smallpos = j;
                smallval = (networkdata->colormap[j].g); /* index on g */
            }
        }
        /* swap colormap[i] (i) and colormap[smallpos] (smallpos) entries */
        if (i != smallpos) {
            nq_pixel temp = networkdata->network[smallpos];   networkdata->network[smallpos] = networkdata->network[i];   networkdata->network[i] = temp;
            nq_colormap tempc = networkdata->colormap[smallpos];   networkdata->colormap[smallpos] = networkdata->colormap[i];   networkdata->colormap[i] = tempc;
        }
        /* smallval entry is now in position i */
        if (smallval != previouscol) {
            networkdata->netindex[previouscol] = (startpos+i)>>1;
            for (j=previouscol+1; j<smallval; j++) networkdata->netindex[j] = i;
            previouscol = smallval;
            startpos = i;
        }
    }
    networkdata->netindex[previouscol] = (startpos+maxnetpos)>>1;
    for (j=previouscol+1; j<256; j++) networkdata->netindex[j] = maxnetpos; /* really 256 */
}

        
inline static double colorimportance(double al)
{
    double transparency = 1.0 - al/255.0;
    return (1.0 - transparency * transparency);
}

/* Search for ABGR values 0..255 (after net is unbiased) and return colour index
   ---------------------------------------------------------------------------- */

unsigned int slowinxsearch(network_data * networkdata,  int al, int b, int g, int r)
{
    unsigned int i,best=0;
    double a,bestd=1<<30,dist;
    
    r=biasvalue(networkdata, r);
    g=biasvalue(networkdata, g);
    b=biasvalue(networkdata, b);
   
    double colimp = colorimportance(al);
    
    for(i=0; i < networkdata->netsize; i++)
    {
        a = networkdata->colormap[i].r - r;
        dist = a*a * colimp;

        a = networkdata->colormap[i].g - g;
        dist += a*a * colimp;
        
        a = networkdata->colormap[i].b - b;
        dist += a*a * colimp;
        
        a = networkdata->colormap[i].al - al;
        dist += a*a;
        
        if (dist<bestd) {bestd=dist; best=i;}        
    }
    return best;
}

unsigned int inxsearch( network_data * networkdata, int al, int b, int g, int r)
{
    unsigned int i; int j; double dist,a,bestd;
    unsigned int best;
        
    bestd = 1<<30;      /* biggest possible dist */
    best = 0;
 
    if (al)
    {       
        r=biasvalue(networkdata,r);
        g=biasvalue(networkdata, g);
        b=biasvalue(networkdata, b);
    }
    else
    {
        r=g=b=0;
    }

    i = networkdata->netindex[(g)];  /* index on g */
    j = i-1;        /* start at netindex[g] and work outwards */


    double colimp = colorimportance(al);

    while ((i<networkdata->netsize) || (j>=0)) {
        if (i<networkdata->netsize) {
            a = networkdata->colormap[i].g - g;      /* inx key */
            dist = a*a * colimp;
            if (dist > bestd) break;    /* stop iter */
            else {
                a = networkdata->colormap[i].r - r;
                dist += a*a * colimp;
                if (dist<bestd) {
                    a = networkdata->colormap[i].b - b;
                    dist += a*a * colimp;
                    if(dist<bestd) {
                        a = networkdata->colormap[i].al - al;
                        dist += a*a;
                        if (dist<bestd) {bestd=dist; best=i;}
                    }
                }
                i++;
            }
        }
        if (j>=0) {
            a = networkdata->colormap[j].g - g; /* inx key - reverse dif */
            dist = a*a * colimp;
            if (dist > bestd) break; /* stop iter */
            else {
                a = networkdata->colormap[j].b - b;
                dist += a*a * colimp;
                if (dist<bestd) {
                    a = networkdata->colormap[j].r - r;
                    dist += a*a * colimp;
                    if(dist<bestd) {
                        a = networkdata->colormap[j].al - al;
                        dist += a*a;
                        if (dist<bestd) {bestd=dist; best=j;}
                    }
                }
                j--;
            }
        }
    }
    return(best);
}




/* Search for biased ABGR values
   ---------------------------- */

int contest(network_data * networkdata, double al,double b,double g,double r)
{
    /* finds closest neuron (min dist) and updates freq */
    /* finds best neuron (min dist-bias) and returns position */
    /* for frequently chosen neurons, freq[i] is high and bias[i] is negative */
    /* bias[i] = gamma*((1/netsize)-freq[i]) */

    unsigned int i; double dist,a,betafreq;
    unsigned int bestpos,bestbiaspos;double bestd,bestbiasd;
    
    bestd = 1<<30;
    bestbiasd = bestd;
    bestpos = 0;
    bestbiaspos = bestpos;
    
    /* Using colorimportance(al) here was causing problems with images that were close to monocolor.
       See bug reports: 3149791, 2938728, 2896731 and 2938710
    */ 
    double colimp = 1.0; //colorimportance(al); 
    
    for (i=0; i<networkdata->netsize; i++)
    {
        double bestbiasd_biased = bestbiasd + networkdata->bias[i];
        
        a = networkdata->network[i].b - b;
        dist = ABS(a) * colimp;
        a = networkdata->network[i].r - r;
        dist += ABS(a) * colimp;
        
        if (dist < bestd || dist < bestbiasd_biased)
        {                 
            a = networkdata->network[i].g - g;
            dist += ABS(a) * colimp;
            a = networkdata->network[i].al - al;
            dist += ABS(a);
            
            if (dist<bestd) {bestd=dist; bestpos=i;}
            if (dist<bestbiasd_biased) {bestbiasd=dist - networkdata->bias[i]; bestbiaspos=i;}
        }
        betafreq = networkdata->freq[i] / (1<< betashift);
        networkdata->freq[i] -= betafreq;
        networkdata->bias[i] += betafreq * (1<<gammashift);
    }
    networkdata->freq[bestpos] += beta;
    networkdata->bias[bestpos] -= betagamma;
    return(bestbiaspos);
}


/* Move neuron i towards biased (a,b,g,r) by factor alpha
   ---------------------------------------------------- */

static void altersingle(network_data * networkdata, double alpha,unsigned int i,double al,double b,double g,double r)
{    
    double colorimp = 1.0;//0.5;// + 0.7*colorimportance(al);
    
    alpha /= initalpha;
    
    /* alter hit neuron */
    networkdata->network[i].al -= alpha*(networkdata->network[i].al - al);
    networkdata->network[i].b -= colorimp*alpha*(networkdata->network[i].b - b);
    networkdata->network[i].g -= colorimp*alpha*(networkdata->network[i].g - g);
    networkdata->network[i].r -= colorimp*alpha*(networkdata->network[i].r - r);
}


/* Move adjacent neurons by precomputed alpha*(1-((i-j)^2/[r]^2)) in radpower[|i-j|]
   --------------------------------------------------------------------------------- */

static void alterneigh(network_data * networkdata, unsigned int rad,unsigned int i,double al,double b,double g,double r)
{
    unsigned int j,hi;
    int k,lo;
    double *q,a;

    lo = i-rad;   if (lo<0) lo=0;
    hi = i+rad;   if (hi>networkdata->netsize) hi=networkdata->netsize;

    j = i+1;
    k = i-1;
    q = networkdata->radpower;
    while ((j<hi) || (k>lo)) {
        a = (*(++q)) / alpharadbias;
		if (j<hi) {
            networkdata->network[j].al -= a*(networkdata->network[j].al - al);
            networkdata->network[j].b  -= a*(networkdata->network[j].b  - b) ;
            networkdata->network[j].g  -= a*(networkdata->network[j].g  - g) ;
            networkdata->network[j].r  -= a*(networkdata->network[j].r  - r) ;
            j++;
        }
        if (k>lo) {
            networkdata->network[k].al -= a*(networkdata->network[k].al - al);
            networkdata->network[k].b  -= a*(networkdata->network[k].b  - b) ;
            networkdata->network[k].g  -= a*(networkdata->network[k].g  - g) ;
            networkdata->network[k].r  -= a*(networkdata->network[k].r  - r) ;
            k--;
        }
    }
}


/* Main Learning Loop
   ------------------ */
/* sampling factor 1..30 */
void learn(network_data * networkdata, unsigned int samplefac, unsigned int verbose) /* Stu: N.B. added parameter so that main() could control verbosity. */
{
    unsigned int i,j,al,b,g,r;
    unsigned int rad,step,delta,samplepixels;
    double radius,alpha;
    unsigned char *p;
    unsigned char *lim;
    
    alphadec = 30 + ((samplefac-1)/3);
    p = networkdata->thepicture;
    lim = networkdata->thepicture + networkdata->lengthcount;
    samplepixels = networkdata->lengthcount/(4*samplefac);
    delta = samplepixels/ncycles;  /* here's a problem with small images: samplepixels < ncycles => delta = 0 */
    if(delta==0) delta = 1;        /* kludge to fix */
    alpha = initalpha;
    radius = initradius;
    
    rad = radius;
    if (rad <= 1) rad = 0;
    for (i=0; i<rad; i++) 
        networkdata->radpower[i] = floor( alpha*(((rad*rad - i*i)*radbias)/(rad*rad)) );
    
    if(verbose) fprintf(stderr,"beginning 1D learning: initial radius=%d\n", rad);

    if ((networkdata->lengthcount%prime1) != 0) step = 4*prime1;
    else {
        if ((networkdata->lengthcount%prime2) !=0) step = 4*prime2;
        else {
            if ((networkdata->lengthcount%prime3) !=0) step = 4*prime3;
            else step = 4*prime4;
        }
    }
    
    i = 0;
    while (i < samplepixels) 
    {
        if (p[3])
        {            
            al =p[3];
            b = biasvalue(networkdata, p[2]);
            g = biasvalue(networkdata, p[1]);
            r = biasvalue(networkdata, p[0]);
        }
        else
        {
            al=r=g=b=0;
        }
        j = contest(networkdata, al,b,g,r);

        altersingle(networkdata, alpha,j,al,b,g,r);
        if (rad) alterneigh(networkdata, rad,j,al,b,g,r);   /* alter neighbours */

        p += step;
        while (p >= lim) p -= networkdata->lengthcount;
    
        i++;
        if (i%delta == 0) {                    /* FPE here if delta=0*/ 
            alpha -= alpha / (double)alphadec;
            radius -= radius / (double)radiusdec;
            rad = radius;
            if (rad <= 1) rad = 0;
            for (j=0; j<rad; j++) 
               networkdata-> radpower[j] = floor( alpha*(((rad*rad - j*j)*radbias)/(rad*rad)) );
        }
    }
    if(verbose) fprintf(stderr,"finished 1D learning: final alpha=%f !\n",((float)alpha)/initalpha);
}
