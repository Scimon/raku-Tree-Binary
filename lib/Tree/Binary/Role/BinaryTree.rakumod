unit package Tree::Binary::Role;

use Tree::Binary::PrettyTree;
use Tree::Binary::Role::Renderer;
use Tree::Binary::Role::HasNodes;
use Tree::Binary::Grammar;
use Tree::Binary::Iterator;
use Tree::Binary::Enums;

=begin pod

=head1 NAME

Tree::Binary - Roles for building and traversing binary trees

=head1 SYNOPSIS

=begin code :lang<raku>

use Tree::Binary;
class IntTree does Tree::Binary::Role::BinaryTree[Int] {};
my IntTree(Str) $tree = "1(2)(3)";
say $tree;

=end code

=begin code

 1 
┌┴┐
2 3

=end code

=head1 DESCRIPTION

Tree::Binary is intended to be a framework that can be used as the basis for 
building binary trees. The core C<Role> provided is 
C<Tree::Binary::Role::BinaryTree> which encapsulates binary tree storage, 
traversing, parsing and rendering.

C<Tree::Binary::Role::BinaryTree> does not include code for inserting 
or deleting nodes as this is dependent on the concreate class using it. 

=head2 Tree::Binary

=begin code :lang<raku>
role Tree::Binary::Role::BinaryTree[
    ::ValueType=Any,
    Tree::Binary::Role::Renderer :$gist-renderer=Tree::Binary::PrettyTree,
    Tree::Binary::Role::Renderer :$Str-renderer=BasicStrRenderer,
    Tree::Binary::TraverseType :$traverse-type=Tree::Binary::TraverseType::InOrder,
    Tree::Binary::TraverseDirection :$traverse-direction=Tree::Binary::TraverseDirection::LeftToRight,
]
=end code

The Tree::Binary::Role::BinaryTree C<Role> accepts one postional and four named parameters : 

=defn ValueType 

The type of object it should allow (defaulting to Any) 

=defn :$gist-renderer

An output renderer used for creating the C<Tree::Binary::Role::BinaryTree>'s 
gist representation. 
The default for this is C<Tree::Binary::PrettyTree>  but any class that does 
C<Tree::Binary::Role::Renderer> will work.

=defn :$Str-renderer

An output renderer used for creating the  C<Tree::Binary::Role::BinaryTree>'s 
Str representation. 
The default for this is C<BasicStrRenderer> but any class that does 
C<Tree::Binary::Role::Renderer> will work.

=defn :$traverse-type

How the tree should be iterated one of C<Tree::Binary::Enums::TraverseType> 
defaults to C<Tree::Binary::TraverseType::InOrder>

=defn :$traverse-direction

The direction the tree should be iterated one of 
C<Tree::Binary::Enums::TraverseDirection> defaults to 
C<Tree::Binary::TraverseDirection::LeftToRight>

=head3 Construction

The default constructor takes two named arguments :

=defn ValueType :$value
The value of the current node

=defn Array[Tree::Binary::Role::BinaryTree] :@nodes[2]
An array of 0-2 Tree::Binary::Role::BinaryTree nodes that are the children 
of the current node.

The role also allows for basic string coercion where a tree can be represented
with the following structure.

=begin code

value(node1)(node2)

=end code

Where C<value> is a C<Str> that can be coerced into a C<ValueType> and C<node1> 
and C<node2> another C<Tree::Binary> representation. The C<Str> method should produce
a value that can be coered into a Tree::Binary of the appropriate C<ValueType>.

Alternate construction options using C<Str> coercion are :

=begin code :lang<raku>

# Coercion from a Str to a Tree::Binary
my Tree::Binary(Str) $tree1 = "1(a)(£)";

# Using the from-Str constructor
my $tree2 = Tree::Binary.from-Str("1(a)(£)");

=end code

=end pod


class BasicStrRenderer does Tree::Binary::Role::Renderer {
    has Tree::Binary::Role::BinaryTree $.tree;

    method render {
        ( $.tree.value , |$.tree.nodes.map( { "({$_})" } ) ).join("");
    }
}

=begin pod

=head2 Attributes

=end pod

role BinaryTree[
    ::ValueType = Any, 
    Tree::Binary::Role::Renderer :$gist-renderer = PrettyTree,
    Tree::Binary::Role::Renderer :$Str-renderer  = BasicStrRenderer,
    TraverseType :$traverse-type = InOrder,
    TraverseDirection :$traverse-direction = LeftToRight
] is export does HasNodes does Iterable {

    #|The Type of node values (default to Any)
    has ValueType() $.value is required;
    #| The child nodes
    has Tree::Binary::Role::BinaryTree @!nodes[2] is built;

=begin pod

=head2 Methods

=end pod

    #| The child nodes of this node, undefined nodes will not be returned.
    method nodes(--> Array[Tree::Binary::Role::BinaryTree]) {
       my Tree::Binary::Role::BinaryTree @ = @!nodes.grep({defined $_});
    }

    method iterator (Tree::Binary::Role::BinaryTree:D :) {
        return Tree::Binary::Iterator.new( 
            tree => self, 
            :$traverse-type, 
            :$traverse-direction 
        );
    }

    #|( Returns the number of defined nodes for the current node.
    Note that the elems method does NOT return the count of all nodes 
    in the tree just the current nodes children. 
    )
    multi method elems(--> UInt) {
        @.nodes.elems;
    }

    multi method elems( Bool :$leaf!, Bool :$all! --> UInt ) {
        die "The :all and :leaf flags in elems are incompatible";
    }

    #|( With the :all flag returns the total number of nodes in the tree 
    including the current one but not any undefined ones.
    )
    multi method elems( Bool :$all! --> UInt ) {
        [+] 1, |self.nodes().map( *.elems(:all) );
    }

    #|( With the :leaf flag returns the total number of leaf nodes )
    multi method elems( Bool :$leaf! --> UInt ) {
        given self.nodes.elems {
            when 0 {
                return 1;
            }
            default {
                return [+] |self.nodes().map( *.elems(:leaf) );
            }
        }
    }

    #| Returns a Str representation of the tree using the :$Str-renderer parameter 
    multi method Str(::?CLASS:D: --> Str ) {
        $Str-renderer.new( tree=>self ).render();
    }

    #| Returns the gist for this tree using the defined $gist-renderer parameter
    multi method gist(::?CLASS:D: --> Str) {
        $gist-renderer.new( tree=>self ).render();
    }
    
    #| Returns a raku representation of the tree
    method raku(--> Str) {
        "{self.^name}.new( {("value => {$!value}", self.nodes ?? "nodes => {(self.nodes.map(*.raku)).join(", ")}" !! Empty).join(", ")} )";
    }

    method routes() {
        gather {
            if ( self.elems ) {
                for @.nodes -> $n {
                    for $n.routes -> @t {
                        take ($!value, |@t);
                    }
                }
            } else {
                take ( $!value, );
            }
        }
    }
    
    #|( Returns a new Tree::Binary where the node pairs have been swapped at each level )
    multi method reverse( ::?CLASS:D: --> Tree::Binary::Role::BinaryTree ) {
        self.new(
            value => $!value,
            nodes => @.nodes.reverse.map( *.reverse )
        )
    }

    multi method reverse( ::?CLASS:U: --> Tree::Binary::Role::BinaryTree ) { ::?CLASS }
    
    method COERCE( Str:D $str --> Tree::Binary::Role::BinaryTree ) {
        return ::?CLASS.from-Str( $str );
    }

    multi method from-Str('' --> Tree::Binary::Role::BinaryTree ) { ::?CLASS }
    
    #| Object creation method using the Str coercion rules.
    multi method from-Str( ::?CLASS:U: Str $in --> Tree::Binary::Role::BinaryTree ) {
        my $match = Tree::Binary::Grammar.parse( $in );
        if ( $match ) {
            self.new(
                value => $match<tree><value>.Str,
                nodes => [
                          self.from-Str( $match<tree><left> ?? $match<tree><left>.Str !! '' ),
                          self.from-Str( $match<tree><right> ?? $match<tree><right>.Str !! '' )
                      ]
            );
        } else {
            die "Unable to Parse $in";
        }
        
    }

}

=begin pod

=head1 AUTHOR

Scimon Proctor <simon.proctor@gmail.com>

=head1 COPYRIGHT AND LICENSE

Copyright 2021 Scimon Proctor

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod
