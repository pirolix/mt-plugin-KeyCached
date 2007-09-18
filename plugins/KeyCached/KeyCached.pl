package MT::Plugin::KeyCached;
#   KeyCached - Filesystem based cache of the already built contents
#           Original Copyright (c) 2007 Piroli YUKARINOMIYA
#           Open MagicVox.net - http://www.magicvox.net/
#           @see http://www.magicvox.net/archive/2007/03041744/

use strict;
use Cache::File;
use Digest::MD5 qw( md5_hex );

# default expire time of cached content
use constant DEFAULT_EXPIRE =>          '72 hours';

use vars qw( $MYNAME $VERSION );
$MYNAME = 'KeyCached';
$VERSION = '1.00';

use base qw( MT::Plugin );
my $plugin = new MT::Plugin ({
        name => $MYNAME,
        version => $VERSION,
        author_name => 'Piroli YUKARINOMIYA',
        author_link => "http://www.magicvox.net/?$MYNAME",
        doc_link => "http://www.magicvox.net/archive/2007/03041744/?$MYNAME",
        description => <<HTMLHEREDOC,
Filesystem based cache of the already built contents to avoid compiling and building the templates each time.
Cache-$Cache::VERSION is installed.
HTMLHEREDOC
});
MT->add_plugin( $plugin );

sub instance { $plugin }

########################################################################
use MT::Template::Context;

### MTKeyCachedKey - 
MT::Template::Context->add_container_tag( KeyCachedKey => \&key_cached_key );
sub key_cached_key {
    my ( $ctx, $args, $cond ) = @_;

    # Built content are used as a key
    my $builder = $ctx->stash( 'builder' );
    my $tokens = $ctx->stash( 'tokens' );
    defined( my $key = $builder->build( $ctx, $tokens, $cond ))
        or return $ctx->error( $builder->errstr );
    $key = md5_hex( $ctx->stash( 'blog_id' ). $key );

    # Set key value of the current context
    my $stash_key = get_stash_key( $ctx );
    $ctx->stash( "${stash_key}::key_value", $key );

    exists $args->{debug}
        ? $key      # when any <debug> param is specified.
        : '';       # in default, this container tag return empty string.
}

### MTKeyCachedValue - 
MT::Template::Context->add_container_tag (KeyCachedValue => \&key_cached_value);
sub key_cached_value {
    my ( $ctx, $args, $cond ) = @_;

    # Retrieve in the current context
    my $stash_key = get_stash_key( $ctx );
    my $key_value = $ctx->stash( "${stash_key}::key_value" ) || '';
    $key_value = md5_hex( $key_value. $ctx->stash( 'blog_id' ). $ctx->stash( 'uncompiled' ));

    # If the cachedcontent exists, use them.
    my $cache = &get_cache_instance
        or return $ctx->error( 'MT'.$ctx->{tag}.': Can\'t initialize <Cache::File>' );
    if( defined( my $cached_content = $cache->get( $key_value ))) {
        return $cached_content;
    }

    # Build content
    my $builder = $ctx->stash( 'builder' );
    my $tokens = $ctx->stash( 'tokens' );
    defined (my $value = $builder->build ($ctx, $tokens, $cond))
        or return $ctx->error( $builder->errstr );
    # Save the built content into cache with expires
    $cache->set(
            $key_value,
            $value,
            exists $args->{expire} ? $args->{expire} : DEFAULT_EXPIRE);

    $value;
}

sub get_stash_key { __PACKAGE__ }

### Handling <Cache::File> as singleton
sub get_cache_dir {
    my $path = &instance->{full_path};
    -d $path
        ? "${path}/$MYNAME"
        : "${path}.cache";
}

use MT::Request;
sub get_cache_instance {
    my $r = MT::Request->instance;
    my $cache = $r->cache( __PACKAGE__. '::cache' );
    unless( defined $cache ) {
        $cache = Cache::File->new(
                cache_root => &get_cache_dir,
                lock_level => Cache::File::LOCK_LOCAL(),
                cache_depth => 2,
                );
        $r->cache( __PACKAGE__. '::cache', $cache );
    }
    $cache;
}

1;
__END__
########################################################################
# '07/09/18 1.00  èâî≈åˆäJ
