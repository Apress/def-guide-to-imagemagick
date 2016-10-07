<?
  ########################################################################################
  # Utility functions
  ########################################################################################

  # This function reads in an image and returns it, including error handling. 
  function readimage($filename)
  {
    $barhandle = imagick_readimage($filename);
    if(imagick_iserror($barhandle))
    {
      $reason      = imagick_failedreason($barhandle);
      $description = imagick_faileddescription($barhandle);

      print "handle failed!<BR>\nReason: $reason<BR>\nDescription: $description<BR>\n";
      exit ;
    }

    $img = imagick_getimagefromlist($barhandle);
    imagick_destroyhandle($barhandle);
    return $img;
  }

  ########################################################################################
  # Read in the image for the background to the graph
  $handle = imagick_readimage(getcwd() . "/graph.png");
  if(imagick_iserror($handle))
  {
    $reason      = imagick_failedreason($handle);
    $description = imagick_faileddescription($handle);

    print "handle failed!<BR>\nReason: $reason<BR>\nDescription: $description<BR>\n";
    exit ;
  }

  ########################################################################################
  # Read in the images we use to draw the bars. There are three of them -- a red bar,
  # a blue bar, and a green bar
  $redbar = readimage(getcwd() . "/redbar.png");
  $greenbar = readimage(getcwd() . "/greenbar.png");
  $bluebar = readimage(getcwd() . "/bluebar.png");

  ########################################################################################
  # Now fetch the data from the database (this is a simulated fetch only).
  # Let's assume that there are three sets of data we want to show -- houses which match
  # this description, houses in this suburb, and houses in this region...
  $match[0] = 0;                 # $0 - $49
  $match[1] = 0;                 # $50 - $99
  $match[2] = 0;                 # $100 - $149
  $match[3] = 0;                 # $150 - $199
  $match[4] = 0;                 # $200 - $249
  $match[5] = 17;                # $250 - $299
  $match[6] = 5;                 # $300 - $349
  $match[7] = 7;                 # $350 - $399
  $match[8] = 4;                 # $400 - $449
  $match[9] = 1;                 # $450 - $499
  $match[10] = 0;                # $500 - $549
  $match[11] = 0;                # $550 - $599
  $match[12] = 0;                # $600 - $649
  $match[13] = 0;                # $650 - $699
  $match[14] = 0;                # $700 - $749
  $match[15] = 0;                # $750 - $799
  $match[16] = 0;                # $800 - $849
  $match[17] = 0;                # $850 - $899

  $region[0] = 0;                # $0 - $49
  $region[1] = 0;                # $50 - $99
  $region[2] = 5;                # $100 - $149
  $region[3] = 8;                # $150 - $199
  $region[4] = 9;                # $200 - $249
  $region[5] = 27;               # $250 - $299
  $region[6] = 19;               # $300 - $349
  $region[7] = 15;               # $350 - $399
  $region[8] = 8;                # $400 - $449
  $region[9] = 2;                # $450 - $499
  $region[10] = 1;               # $500 - $549
  $region[11] = 1;               # $550 - $599
  $region[12] = 3;               # $600 - $649
  $region[13] = 1;               # $650 - $699
  $region[14] = 0;               # $700 - $749
  $region[15] = 0;               # $750 - $799
  $region[16] = 0;               # $800 - $849
  $region[17] = 0;               # $850 - $899

  $city[0] = 1;                # $0 - $49
  $city[1] = 1;                # $50 - $99
  $city[2] = 10;               # $100 - $149
  $city[3] = 16;               # $150 - $199
  $city[4] = 17;               # $200 - $249
  $city[5] = 30;               # $250 - $299
  $city[6] = 25;               # $300 - $349
  $city[7] = 17;               # $350 - $399
  $city[8] = 12;               # $400 - $449
  $city[9] = 8;                # $450 - $499
  $city[10] = 6;               # $500 - $549
  $city[11] = 5;               # $550 - $599
  $city[12] = 5;               # $600 - $649
  $city[13] = 3;               # $650 - $699
  $city[14] = 2;               # $700 - $749
  $city[15] = 2;               # $750 - $799
  $city[16] = 1;               # $800 - $849
  $city[17] = 1;               # $850 - $899

  $max = 18;
  
  ########################################################################################
  # The graphing for the moment assumes that the maximum value to be graphed is small
  # enough that we should give each increase of one in the input value an extra five
  # rows in the graph
  for($i = 0; $i < $max; $i++)
  {
    for($j = 0; $j < $city[$i] * 5; $j++)
    {
      imagick_composite($handle, IMAGICK_COMPOSITE_OP_OVER, $greenbar, 42 + 10 + ($i * 20), 259 - $j);
    }
  }

  for($i = 0; $i < $max; $i++)
  {
    for($j = 0; $j < $region[$i] * 5; $j++)
    {
      imagick_composite($handle, IMAGICK_COMPOSITE_OP_OVER, $redbar, 42 + 5 + ($i * 20), 259 - $j);
    }
  }

  for($i = 0; $i < $max; $i++)
  {
    for($j = 0; $j < $match[$i] * 5; $j++)
    {
      imagick_composite($handle, IMAGICK_COMPOSITE_OP_OVER, $bluebar, 42 + ($i * 20), 259 - $j);
    }
  }

  ########################################################################################
  # This dumps the image to a variable, so that we can output it to the browser, and then
  # outputs it to the browser
  if(!$dump = imagick_image2blob($handle))
  {
    $reason      = imagick_failedreason($handle);
    $description = imagick_faileddescription($handle);

    print "imagick_writeimage() failed<BR>\nReason: $reason<BR>\nDescription: $description<BR>\n";
    exit ;
  }

  # Output the finished graph to the browser
  header("Content-Type: image/jpeg");
  print $dump;
?>
