package Netdot::Model::Asset;

use base 'Netdot::Model';
use warnings;
use strict;


############################################################################
=head2 search_like -  Search for asset objects.  Allow substrings

  Overridden to allow producttype to be searched on

  Arguments: 
    Hash with key/value pairs
  Returns: 
    Array of Asset objects or iterator

=cut

sub search_like{
    my ($class, %argv) = @_;
    $class->isa_class_method('search_like');

    if ( $argv{producttype} ){
        if( $argv{producttype} == 11 ){
	    return $class->search_by_type_unknown($argv{producttype});
	}
        return $class->search_by_type($argv{producttype});
    }else{
        return $class->SUPER::search_like(%argv);
    }
}

__PACKAGE__->set_sql(by_type => qq{
    SELECT a.id
        FROM asset a 
        LEFT JOIN product p ON a.product_id = p.id
        LEFT JOIN producttype t ON p.type = t.id
	WHERE (t.id = ?)
    });

__PACKAGE__->set_sql(by_type_unknown => qq{
    SELECT a.id
        FROM asset a 
        LEFT JOIN product p ON a.product_id = p.id
        LEFT JOIN producttype t ON p.type = t.id
        WHERE t.id = ?
	OR a.product_id = 0
	OR a.product_id IS NULL
    });



1;

