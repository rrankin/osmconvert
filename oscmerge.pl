#!/usr/bin/perl
#	Copyright Roy Rankin 2011
# 	Bug reports to rrankin AT ihug.com.au
#
# This work is licensed under the Australia Creative Commons CC BY-SA 3.0 
# License. Copyright notice must not be removed.
# To view a copy of this license, visit 
#    http://creativecommons.org/licenses/by-sa/3.0/au
#
#
# oscmerge.pl reads uncompressed osmChange files or standard input of
# 	osmChange data and combinds them into single osmChange file 
# 	which is sent to standard output.
#	typical usage would be 
#		zcat *.osc.gz | oscmerge.pl | gzip > all.osc.gz
#		zcat *.osc.gz | oscmerge.pl | osmconvert --out-o5c > all.o5c
#	or
#		oscmerge.pl *.osc > all.osc
#
my $version = "0.1 2011-09-14";
my ($node, %node, %node_mode);  
my ($way, %way, %way_mode);  
my ($relation, %relation, %relation_mode);  
my (@terms) = ("create", "modify", "delete");


$_ =<>;
$_=<> if (/xml/);
die "$ARGV not osmChange file\n" if (!/osmChange/);

while(get_line())
{

  if ( /<modify/)
  {
      cmd(1);
  }
  elsif  ( /<create/)
  {
      cmd(0);
  }
  elsif  ( /<delete/)
  {
      cmd(2);
  }
  elsif (/<\/osmChange/) {}
  elsif (/<osmChange/) 
  {
	#print $_;
  }
  elsif (/<\?xml/) 
  {
	#print $_;
  }
  else
  {
    #print $_;
  }
}
output_data();
exit 0;

#
# output_data : write out the new osmChange file.
#
sub output_data
{
    my $current_mode = -1;

    print "<?xml version='1.0' encoding='UTF-8'?>\n";
    print "<osmChange version='0.6' generator='oscmerge.pl'>\n";
    foreach  $key (sort {$a <=> $b} keys %node)
    {
	$current_mode = output_mode($current_mode, $node_mode{$key});
	print $node{$key};
    }
    foreach  $key (sort {$a <=> $b} keys %way)
    {
	$current_mode = output_mode($current_mode, $way_mode{$key});
	print $way{$key};
    }
    foreach  $key (sort {$a <=> $b} keys %relation)
    {
	$current_mode = output_mode($current_mode, $relation_mode{$key});
	print $relation{$key};
    }
    output_mode($current_mode, -1);
    print "<\/osmChange>\n";
}

#
# output_mode($from, $to) : output the create, modify and delete delimiters.
# 	$from indicates the section terminator to output
# 	$to indicates the section opening tag to output
# 	If either $from or $to is -1, the tag is not output.
# 	If $from equals $to, no output is generate.
#
sub output_mode
{
    my ($from, $to) = @_;

    return $to if ($from == $to);
    print "<\/$terms[$from]>\n" if ($from >= 0 && $from < 3);
    print "<$terms[$to]>\n" if ($to >= 0 && $to < 3);
    return $to;
}

# cmd($mode) : process a create(0), modify(1) or delete(2) section
# 	and save the results in the node, way or relation associate
# 	arrays.
sub cmd
{
    my ($mode) = @_;
    my ($term) = $terms[$mode];
    my $key, $id;
    my $old;

    
    #print STDERR "RRR $. $term ";
    #print $_;
    while(get_line())
    {
	if ( /<\/$term/)
	{
	    #print STDERR $_;
	    return;
	}
	elsif (/<node/)
	{
	    $node = element("node");
	    if ($node =~ /node id=['"]+([0-9]*)/)
	    {
		$id = $1;
		if ( ! defined $node{$id})
		{
		    $node{$id} = $node;
		    $node_mode{$id} = $mode;
		}
		elsif ($dup = replace_dup($id, "node", $node{$id},
			$node, $node_mode{$id}, $mode))
		{
		    $node{$id} = $node;
		    $node_mode{$id} = $mode if ($dup == 1);
		}
	    }
	    else
	    {
		die "node id not found $node\n";
	    }
	}
	elsif (/<way/)
	{
	    $way = element("way");
	    if ($way =~ /way id=['"]+([0-9]*)/)
	    {
		$id = $1;
		if ( ! defined $way{$id})
		{
		    $way{$id} = $way;
		    $way_mode{$id} = $mode;
		}
		elsif($dup = replace_dup($id, "way", $way{$id},
			$way, $way_mode{$id}, $mode))
		{
		    $way{$id} = $way;
		    $way_mode{$id} = $mode if ($dup == 1);
		}
	    }
	    else
	    {
		die "way id not found $way\n";
	    }
	}
	elsif (/<relation/)
	{
	    
	    $relation = element("relation");
	    if ($relation =~ /relation id=['"]+([0-9]*)/)
	    {
		$id = $1;
		if ( ! defined $relation{$id})
		{
		    $relation{$id} = $relation;
		    $relation_mode{$id} = $mode;
		}
		elsif($dup = replace_dup($id, "relation", $relation{$id},
			$relation, $relation_mode{$id}, $mode))
		{
		    $relation{$id} = $relation;
		    $relation_mode{$id} = $mode if ($dup == 1);
		}
	    }
	    else
	    {
		die "relation id not found $relation\n";
	    }
	}
        elsif (/^[\r\n ]*$/) {}
	else
	{
	    print STDERR "RRR unexpected input $. -$_-\n";
	    die if (/<\/modify/);
        }
        #print STDERR "$term $_" if (/<\//);
        $old = $_;
    }
}


# replace_dup(id, name, old value, new value, old mode, new mode)
# 	when an element(node, way or relation) is repeated in the
# 	input, determine what action to take.
# 	Return code has following meaning
# 		0 - use old value and mode
# 		1 -  use new value and mode
# 		2 - use new value and old mode
#
#	mode is 0 (create), 1 (modify) or 2 (delete)
#	decision is based on element version number and mode.
#
sub replace_dup
{
   my($id, $name, $old_value, $new_value, $old_mode, $new_mode) = @_;
   my ($v1, $v2);

   $vold = $1 if ($old_value =~ /version=['"]+([0-9]*)/);
   $vnew = $1 if ($new_value =~ /version=['"]+([0-9]*)/);

   return 1 if ($vnew > $vold && $old_mode == $new_mode); # use newer data
   return 0 if ($vnew < $vold); # use older more recent data
   if ($vnew > $vold) # newer version
   {
	# same mode new data, use new entry
	return 1 if ($old_mode == $new_mode);
        # was create now modify keep create mode
        return 2 if ($old_mode == 0 && $new_mode == 1);
	# new mode delete
	return 1 if ($new_mode = 2);
   }
   # new and old the same version 
   if ($vnew == $vold)
   {
	# modes same do nothing
	if ($old_mode == $new_mode)
        {
	    print STDERR "Warning $name id=$id duplicated\n" if ($verbose);
	    return 0;
        }
        if ($new_mode == 2) # new mode delete, use it
	{
	    return 1;
	}
        # was create now modify keep create mode
        return 2 if ($old_mode == 0 && $new_mode == 1);
   }
   print STDERR "Warning  dup $name id=$id ",
	"old $vold ($terms[$old_mode]) ",
	"new $vnew  ($terms[$new_mode]) \n";
   return 0;
}
# element($type) : type = "node", "way" or "relation" Process input data
# 	for the $type element until the </ terminator is seen. Return the
# 	data as a single string.
#
sub element
{
    my ($type) = @_;
    my $out = $_;
    return $out if (/\/>/);
    while(get_line())
    {
	$out = $out . $_;
	return $out if ( /<\/$type/);
    }
    die "element: unterminated $type $out";
}
# get_line() : Read input until a complete tag is read. The tag may span 
# 	several input lines. Return as a string without embedded newlines
# 	although it will be terminated with a newline.
#
sub get_line
{
   my $line;

   return $_ if (! ($_ = <>));
   if (/</ && ! />/)
   {
        $line = $_;
	do
	{
	  chop $line;
	  $line = $line . <>;
	} while ( ! ($line =~ />/) && ! eof);
	$_ = $line;
   }
   return $_;
   
}

   
