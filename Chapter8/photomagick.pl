#!/usr/bin/perl

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser); 
use File::Find;
use Image::Magick;
use Image::EXIF;

use PhotoMagick;

#######################
# Configuration options

# The directory the images are in
my($directory) = "/data/pictures";

# The HTML header for the top of the page
my($header) = "<html><head><title>photomagick</title></head><body>";

# This is the tick image used for the published column
my($tick) = "<img src=\"http://www.stillhq.com/common/tick.png\">";

# The HTML footer for the bottom of the page
my($footer) = "</body></html>";

# This is a comma separated list of the targets that uses should be allowed
# to set for an image. This must contain an entry named none
my(@targets) = split(/,/, "andrew,matthew,events,diary,none");

#######################

# This is the CGI context
my($result);

# The logic for the CGI script is as follows:
#   A user enters with no arguments to the CGI script. They get a list of
#   the image directories, the number of images within the directory, and
#   information about if the images have been published. They select a
#   directory.
#
#   If a directory is specified, then the user is asked to enter metadata
#   for each of the pictures. There are some JavaScript helpers to make this
#   more fun.
#
#   If a directory is specified and there is an action=commit, then the
#   metadata is commited and the images are moved to their destination,
#   with any conversion which might be needed.
#
#   If a directory is specified and there is an action=image, then the
#   full sized image is returned. This needs the filename for the image to
#   be provided as well. This command also supports a rotate option as well.
#
#   If a directory is specified and there is an action=thumbnail, then a
#   small sized image is returned. This needs the filename for the image to
#   be provided as well. This command also supports a rotate command as well.

$result = new CGI();

# Almost all pages have a header
if(($result->param('action') ne "image") &&
   ($result->param('action') ne "thumbnail")){
    print $result->header;
    print "$header\n\n";
    
    # All pages except the top need a return to the top link
    if($result->param('dir') ne ""){
	my($url) = $result->self_url(-full);
	$url =~ s/\?.*$//;

	print "<a href=\"".$url.
	    "\">Return to the directory list</a><br/><br/>\n";
    }
}

if($result->param('action') eq "commit"){
    # We're commiting the changes to the metadata file and rearranging
    # images
    my($filename, $target);
    my($dir) = $result->param('dir');
    my($inputpath) = "$directory/$dir";
    my($META);

    print "Processing images...\n";
    open META, "> $inputpath/META" or 
	die "Couldn't open the META file for output";

    # Write out the meta file for the images
    print "<ul>\n";
    foreach $filename (split(/,/, $result->param('images'))){
	print META "$filename\t".
	    $result->param("$filename-target")."\t".
	    $result->param("$filename-rotate")."\t".
	    $result->param("$filename-keywords")."\n";
	print "<li>$filename</td>\n";
    }
    close META;

    foreach $target (@targets){
	if($result->param("$target-title") ne ""){
	    open META, "> $inputpath/META-$target" or 
		die "Couldn't open the META-$target file for output";
	    print META $result->param("$target-title")."\n";
	    print META $result->param("$target-description")."\n";
	    close META;
	}
    }
    
    print "</ul><br/><br/>\n";
    print "You now need to run the pmpublish command to generate the HTML\n";
    print "$footer";
}
elsif(($result->param('action') eq "image") &&
      ($result->param('dir') ne "") &&
      ($result->param('filename') ne "")){
    # This will convert the output image to JPEG if needed
    my($dir, $filename, $rc);

    $dir = $result->param('dir');
    $filename = $result->param('filename');

    my($image);
    $image = new Image::Magick;
    print "Content-Type: ".$image->MagickToMime('jpg')."\n\n";

    $rc = $image->Read("$directory/$dir/$filename");
    die "$rc" if $rc;

    if($result->param('rotate') ne ""){
	$rc = $image->Rotate($result->param('rotate'));
	die "$rc" if $rc;
    }

    binmode STDOUT;
    $rc = $image->Write('jpg:-');    
    die "$rc" if $rc;
}
elsif(($result->param('action') eq "thumbnail") &&
      ($result->param('dir') ne "") &&
      ($result->param('filename') ne "")){
    # This assumes that the image being returned is a JPEG file
    my($dir, $filename, $rc);

    $dir = $result->param('dir');
    $filename = $result->param('filename');

    # Produce a thumbnail of the image on the fly
    my($image);
    $image = new Image::Magick;
    print "Content-Type: ".$image->MagickToMime('jpg')."\n\n";

    $rc = $image->Read("$directory/$dir/$filename");
    die "$rc" if $rc;

    $rc = $image->Thumbnail(geometry=>$result->param('xsize').'x'.
		      $result->param('ysize'));
    die "$rc" if $rc;

    if($result->param('rotate') ne ""){
	$rc = $image->Rotate($result->param('rotate'));
	die "$rc" if $rc;
    }

    binmode STDOUT;
    $rc = $image->Write('jpg:-');
    die "$rc" if $rc;
}
elsif($result->param('dir') ne ""){
    # The user has specified a directory
    my($rowalt, $meta, $filename, $temp);
    $rowalt = 1;

    javascript();
    print "<table width=\"100%\">\n";
    print $result->start_form(-name=>'metadata');
    print $result->hidden('action', 'commit');
    print $result->hidden('dir', $result->param('dir'));

    $temp = "$directory/".$result->param('dir');
    $meta = combine($temp, PhotoMagick::readmeta($temp), getimages($temp));

    $temp = "";
    foreach $filename(sort(keys(%$meta))){
	$temp = "$temp$filename,";
    }
    print $result->hidden('images', $temp);
		      
    foreach $filename(sort(keys(%$meta))){
	print STDERR "Processing $filename\n";

	print "<tr";
	if($rowalt == 1){ print " bgcolor=\"CCCCCC\""; $rowalt = 0; }
	else{ $rowalt = 1; }
	print ">";

	# Name anchor for linking, image and link to full size image
	print "<td valign=\"top\"><a name=\"$filename\">";
	print "<div align=\"center\">";
	print "<a href=\"".$result->self_url.
	    ";action=image".
	    ";filename=$filename";
	if($meta->{$filename}->rotate eq "right"){
	    print ";rotate=90";
	}
	elsif($meta->{$filename}->rotate eq "left"){
	    print ";rotate=-90";
	}
	print "\">";

	print "<img src=\"".$result->self_url.
	    ";action=thumbnail".
	    ";filename=$filename";
	if($meta->{$filename}->rotate eq "right"){
	    print ";rotate=90";
	}
	elsif($meta->{$filename}->rotate eq "left"){
	    print ";rotate=-90";
	}
	print "\">";
	print "</a></div></td>\n";

	# The option to enter simple metadata for the image
	print "<td valign=\"top\">Target:<br/><ul>";
	print $result->radio_group(-name=>"$filename-target",
				   -values=>[@targets],
				   -default=>$meta->{$filename}->target,
				   -linebreak=>'true');
	print "</ul>";
	$result->autoEscape(0);
	print $result->button(-name=>"$filename-filldown",
			      -value=>'Fill this target down',
			      -onClick=>"flowdown('$filename-target', 'radio');");
	$result->autoEscape(1);
	print "</td>\n";

	print "<td valign=\"top\">Rotation:<br/><ul>";
	print $result->radio_group(-name=>"$filename-rotate",
				   -values=>['left', 'no', 'right'],
				   -default=>$meta->{$filename}->rotate,
				   -linebreak=>'true');
	print "</ul>";
	print "<i>".$meta->{$filename}->rotatedesc."</i>";
	print "</td>";

	print "<td valign=\"top\">";
	$temp = $meta->{$filename}->keywords;
	$temp =~ s/_/ /g;
	print "<div align=\"center\">";
	print $result->textarea(-name=>"$filename-keywords",
				-rows=>5, -cols=>"80",
				-default=>$temp);
	print "<br/>";
	$result->autoEscape(0);
	print $result->button(-name=>"$filename-filldown",
			      -value=>'Fill this description down',
			      -onClick=>"flowdown('$filename-keywords', 'textarea');");
	$result->autoEscape(1);

	print "</td></tr>\n";
    }

    print "</table>\n";
    print $result->hidden(-name=>"js-end");

    # Ask for a description of each target
    my($target);
    foreach $target (sort(@targets)){
	print STDERR "Checking for existing target meta data: $directory/".
	    $result->param('dir')."/META-$target\n";
	my($targetdescription) = PhotoMagick::readmetatarget("$directory/".
							     $result->param('dir').
							     "/META-$target");

	print STDERR $targetdescription->{'title'}."\n";

	print "<br/><br/>\n";
	print "Enter a description of the images published in $target:<br/>\n";
	print "<ul>Title: ";
	print $result->textfield(-name=>"$target-title",
				 -size=>"80",
				 -value=>$targetdescription->{'title'});
	print "<br/>";
	print $result->textarea(-name=>"$target-description",
				-rows=>"8", 
				-cols=>"100",
				-default=>$targetdescription->{'description'});
	print "</ul>";
    }

    print "<br/><br/><div align=\"center\">";
    print $result->submit('submit', ' Commit changes ');
    print "</div>";
    print $result->end_form;
    print "$footer";
    print "\n\n";
}
else{
    # Output a list of the directories
    my($dir, $rowalt);
    $rowalt = 1;

    print $result->start_form(-name=>'dirselect');
    print "Specify a thumbnail size, or use the default:\n";
    print "<ul>";
    print "<table>\n";
    print "<tr><td>Horizontal size:</td><td>".
	$result->textfield(-name=>'xsize', -size=>5, -value=>'128')."</td></tr>";
    print "<tr><td>Vertical size:</td><td>".
	$result->textfield(-name=>'ysize', -size=>5, -value=>'96')."</td></tr>";
    print "</table>\n";
    print "<i>These sizes are for unrotated images, and will be flipped for rotated images\n";
    print "</ul><br/><br/>\n";

    print "<table width=\"100%\">\n";
    print "<tr><td>Directory</td>";
    print "<td width=\"10%\">Number of images</td>";
    print "<td width=\"10%\">Published</td></tr>\n";

    foreach $dir (sort(getdirectories($directory))){
	# We only want the part of the directory after the path, as
	# using the rest on the URL would be an information leak
	$dir =~ s/$directory\///;

	print "<tr";
	if($rowalt == 1){ print " bgcolor=\"CCCCCC\""; $rowalt = 0; }
	else{ $rowalt = 1; }
	print ">";

	# The edit button
	print "<td>".$result->submit('dir', $dir);

	# Number of images
	print "<td>".getimages("$directory/$dir")."</td>";

	# Published?
	print "<td>";
	if(ispublished("$directory/$dir")){ print "$tick"; }
	else{ print "&nbsp;"; }
	print "</td>";

	print "</tr>\n";
    }
    print "</table>";
    print $result->end_form;
    print "$footer";
    print "\n\n";
}	

###################################

# This function combines the read metadata with the actual list of images.
# There are three possible cases. An image is listed in the META file which
# exists, the image doesn't exist, or the image exists but doesn't have
# an entry in the META file. This function handles all three of these cases
# and produces a hash of all of the images that need processing.
#
# Pass in the output of the readmeta function, and the getimages function,
# in that order.
sub combine{
    my($path, $meta, @images) = @_;
    my($image, $combinedmeta, $exifreader, $orient, $data);
    
    foreach $image (@images){
	if(exists($meta->{$image})){
	    $combinedmeta->{$image} = $meta->{$image};
	}
	else{
	    print STDERR "Reading EXIF information for $image\n";
	    $combinedmeta->{$image} = new metaitem;
	    
	    # Infer orientation from JPEG EXIF data. We have to unload
	    # the EXIF reader so it works next time.
	    $exifreader = new Image::EXIF("$path/$image") or 
		die "No EXIF read";
	    $data = $exifreader->get_all_info() or
		die "EXIF read failed";
	    undef($exifreader);

	    #print STDERR Dumper($data)."\n";

	    $orient = $data->{image}->{'Image Orientation'};
	    print STDERR "$orient\n";

	    if($orient eq "Right-Hand, Top"){
		$combinedmeta->{$image}->rotate("right");
	    }
	    elsif($orient eq "Left-Hand, Bottom"){
		$combinedmeta->{$image}->rotate("left");
	    }
	    else{
		# Top, Left-Hand
		$combinedmeta->{$image}->rotate("no");
	    }
	    $combinedmeta->{$image}->target("none");

	    $combinedmeta->{$image}->rotatedesc($orient);
	}
    }

    return $combinedmeta;
}

# Call this function to get back a list of the images in a given directory.
# This makes the assumption that there are no subdirectories. It would be
# easy to support that though.
#
# Pass in the path to the directory which contains the images.
sub getimages{
    my($path) = @_;
    my(@images);

    print STDERR "Finding images in $path\n";
    find(sub{
	# Modify the next line to support file formats other than JPEG
	# if needed
	if($File::Find::name =~ /\/([^\/]*\.jpg)$/i){
	    push(@images, $1);
	}
    }, $path);

    return @images;
}

# This function is similar to the above, but returns a list of the
# directories containing at least one image.
#
# Pass in the path to the parent directory
sub getdirectories{
    my($path) = @_;
    my(%directories);

    find({
	wanted=>sub{
	    # Again, this needs to be tweaked if other image formats are
	    # to be supported
	    if($File::Find::name =~ /\/([^\/]*\.jpg)$/i){
		# This is a horrible, horrible hack
		$directories{$File::Find::dir} = "yes";
	    }
	}, 
	follow=>1
	}, 
	 $path);
    
    return keys %directories;
}

# Determine if a directory has been published on the web
#
# Returns true if the directory has been published
sub ispublished{
    my($path) = @_;
   
    return( -f "$path/META" );
}

# Output the javascript for the description page
sub javascript{
    print <<EOF;
<script language="JavaScript">
<!--
function flowdown ( startid, type ){
  found = false;
  descr = "NOTSET";

  for (var i = 0; i < document.metadata.elements.length; i++) {
    if(document.metadata.elements[i].name == "js-end") {
      found = false;
    }

    if(document.metadata.elements[i].type == type) {
      if(document.metadata.elements[i].name == startid) {
        found = true;
      }

      if(found) {
        if(descr == "NOTSET") {
          if(type == "radio") {
            if(document.metadata.elements[i].checked == true) {
              descr = document.metadata.elements[i].value;
            }
          }
          else {
            descr = document.metadata.elements[i].value;
          }
        }

        if(type == "radio") {
          if(document.metadata.elements[i].value == descr) {
            document.metadata.elements[i].checked = true;
          }
        }
        else {
          document.metadata.elements[i].value = descr;
        }
      }
    }
  }
}

// -->
</script>
EOF
}
