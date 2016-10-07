#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <aalib.h>
#include <tiffio.h>

int
main (int argc, char **argv)
{
  int x, y, stripMax, stripCount, textwidth, xoffset, yoffset;
  TIFF *image;
  FILE *output;
  uint16 photo, bps, spp, fillorder;
  uint32 width, height;
  tsize_t stripSize;
  unsigned long imageOffset, result, bufferSize, count;
  char *text, *buffer, tempbyte;
  aa_context *context;
  aa_renderparams *params;

  // Open the TIFF image
  if ((image = TIFFOpen (argv[1], "r")) == NULL)
    {
      fprintf (stderr, "Could not open incoming image\n");
      exit (42);
    }

  // Open the output file
  output = fopen (argv[2], "w");
  fprintf (stderr, "Writing to %s\n", argv[2]);
  if (output == NULL)
    {
      fprintf (stderr, "Could not open output file\n");
      exit (42);
    }

  // Check that it is of a type that we support
  if ((TIFFGetField (image, TIFFTAG_BITSPERSAMPLE, &bps) == 0) || (bps != 1))
    {
      fprintf (stderr,
	       "Either undefined or unsupported number of bits per sample\n");
      exit (42);
    }

  if ((TIFFGetField (image, TIFFTAG_SAMPLESPERPIXEL, &spp) == 0)
      || (spp != 1))
    {
      fprintf (stderr,
	       "Either undefined or unsupported number of samples per pixel\n");
      exit (42);
    }

  TIFFGetField (image, TIFFTAG_IMAGEWIDTH, &width);
  TIFFGetField (image, TIFFTAG_IMAGELENGTH, &height);

  // Initialize aalib, and ensure the image is blank
  context = aa_init (&mem_d, &aa_defparams, NULL);
  if (context == NULL)
    {
      fprintf (stderr, "Failed to initialize aalib\n");
      exit (1);
    }

  params = aa_getrenderparams ();

  memset (context->imagebuffer, 0,
	  (size_t) (aa_imgwidth (context) * aa_imgheight (context)));

  // Check we can fit the image
  if (context->imgwidth < width)
    {
      fprintf (stderr,
	       "Image too wide. It should be no more than %d pixels\n",
	       context->imgwidth);
      exit (1);
    }
  if (context->imgheight < height)
    {
      fprintf (stderr,
	       "Image too high. It should be no more than %d pixels\n\n",
	       context->imgheight);
      exit (1);
    }

  // Read in the possibly multile strips
  stripSize = TIFFStripSize (image);
  stripMax = TIFFNumberOfStrips (image);
  imageOffset = 0;

  bufferSize = TIFFNumberOfStrips (image) * stripSize;
  if ((buffer = (char *) malloc (bufferSize)) == NULL)
    {
      fprintf (stderr,
	       "Could not allocate enough memory for the uncompressed image\n");
      exit (42);
    }

  for (stripCount = 0; stripCount < stripMax; stripCount++)
    {
      if ((result = TIFFReadEncodedStrip (image, stripCount,
					  buffer + imageOffset,
					  stripSize)) == -1)
	{
	  fprintf (stderr, "Read error on input strip number %d\n",
		   stripCount);
	  exit (42);
	}

      imageOffset += result;
    }

  // Deal with photometric interpretations
  if (TIFFGetField (image, TIFFTAG_PHOTOMETRIC, &photo) == 0)
    {
      fprintf (stderr, "Image has an undefined photometric interpretation\n");
      exit (42);
    }

  if (photo != PHOTOMETRIC_MINISBLACK)
    {
      // Flip bits
      fprintf (stderr, "Fixing the photometric interpretation\n");

      for (count = 0; count < bufferSize; count++)
	buffer[count] = ~buffer[count];
    }

  // Determine how to center the image
  xoffset = (context->imgwidth - width) / 2;
  yoffset = (context->imgheight - height) / 2;

  // Copy the image across
  if (width % 8 != 0)
    width += (8 - width % 8);
  for (y = 0; y < height; y++)
    {
      for (x = 0; x < width / 8; x++)
	{
	  if (((unsigned char) buffer[y * (width / 8) + x]) & 0x01)
	    aa_putpixel (context, x * 8 + 7 + xoffset, y + yoffset, 255);
	  if (((unsigned char) buffer[y * (width / 8) + x]) & 0x02)
	    aa_putpixel (context, x * 8 + 6 + xoffset, y + yoffset, 255);
	  if (((unsigned char) buffer[y * (width / 8) + x]) & 0x04)
	    aa_putpixel (context, x * 8 + 5 + xoffset, y + yoffset, 255);
	  if (((unsigned char) buffer[y * (width / 8) + x]) & 0x08)
	    aa_putpixel (context, x * 8 + 4 + xoffset, y + yoffset, 255);

	  if (((unsigned char) buffer[y * (width / 8) + x]) & 0x10)
	    aa_putpixel (context, x * 8 + 3 + xoffset, y + yoffset, 255);
	  if (((unsigned char) buffer[y * (width / 8) + x]) & 0x20)
	    aa_putpixel (context, x * 8 + 2 + xoffset, y + yoffset, 255);
	  if (((unsigned char) buffer[y * (width / 8) + x]) & 0x40)
	    aa_putpixel (context, x * 8 + 1 + xoffset, y + yoffset, 255);
	  if (((unsigned char) buffer[y * (width / 8) + x]) & 0x80)
	    aa_putpixel (context, x * 8 + 0 + xoffset, y + yoffset, 255);
	}
    }

  aa_flush (context);
  aa_render (context, params, 0, 0,
	     aa_imgwidth (context), aa_imgheight (context));

  text = strdup (aa_text (context));
  textwidth = aa_scrwidth (context);

  for (x = 0; x < strlen (text); x++)
    {
      fprintf (output, "%c", text[x]);
      if ((x + 1) % textwidth == 0)
	fprintf (output, "\n");
    }
  fprintf (output, "\n");

  TIFFClose (image);
  fclose (output);
  aa_close (context);
  return 0;
}
