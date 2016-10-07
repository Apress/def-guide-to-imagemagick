package PhotoMagick;

use strict;
use Class::Struct;

# There is one of these for each image, or each image in the META file
struct( metaitem => [
		     target  => '$',
		     rotate => '$',
		     rotatedesc => '$',
		     keywords => '$',
		     ]);

# This function reads the META file and returns the parsed meta data as a 
# hash reference.
#
# Pass in the path to the directory containing the META file.
sub readmeta{
    my($path) = @_;
    my($META, $meta, $temp);

    open META, "< $path/META" or return undef;
    while(<META>){
	if(/^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)$/){
	    my $mi = new metaitem;
	    $mi->target($2);

	    if(($3 eq "none") || ($3 eq "")){
		$mi->rotate("no");
	    }
	    else{
		$mi->rotate($3);
	    }
	    $mi->keywords($4);
	    $meta->{$1} = $mi;
	}
	else{
	    print STDERR "Poorly formatted META line: $_\n";
	}
    }
    close META;

    return $meta;
}

# This function reads the META-target file and returns the parsed meta data
# as a hash reference. The format is very simple -- the first line is the title
# and everything else is the description
#
# Pass in the path to the META-target file
sub readmetatarget{
    my($path) = @_;
    my($META, $meta);

    open META, "< $path" or return undef;
    while(<META>){
	if($meta->{'title'} eq ""){
	    $meta->{'title'} = $_;
	}
	else{
	    $meta->{'description'} = $meta->{'description'}.$_;
	}
    }
    close META;

    return $meta;
}

1;
