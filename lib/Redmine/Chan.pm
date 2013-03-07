package Redmine::Chan {
  use Mouse;
  use Mouse::Util::TypeConstraints;
  use URI;
  use Redmine::Chan::API;
  use Redmine::Chan::Recipe;

  my $subtype_uri = subtype 'Redmine::Chan::URI'
    => as class_type('URI');
  coerce $subtype_uri
    => from 'Str' => via { URI->new($_) };

  has 'redmine_url'     => (is => 'ro', isa => $subtype_uri, required => 1, coerce => 1);
  has 'redmine_api_key' => (is => 'ro', isa => 'Str',        required => 1);
  has 'irc_channels'    => (is => 'ro', isa => 'HashRef',    required => 1);
  has 'irc_server'      => (is => 'ro', isa => 'Str',        required => 1);
  has 'irc_port'        => (is => 'ro', isa => 'Int',        required => 1);
  has 'irc_password'    => (is => 'ro', isa => 'Str',        required => 1);

  has 'nick'   => (is => 'ro', isa => 'Str',                   default => 'minechan');
  has 'api'    => (is => 'ro', isa => 'Redmine::Chan::API',    default => \&default_api,    lazy => 1);
  has 'recipe' => (is => 'ro', isa => 'Redmine::Chan::Recipe', default => \&default_recipe, lazy => 1);
  has 'cv'     => (is => 'rw', isa => 'AnyEvent::CondVar'    );
  has 'irc'    => (is => 'rw', isa => 'AnyEvent::IRC::Client');
  has 'issue_fields'        => (is => 'ro', isa => 'Maybe[ArrayRef]');
  has 'status_commands'     => (is => 'ro', isa => 'Maybe[HashRef]' );
  has 'custom_field_prefix' => (is => 'ro', isa => 'Maybe[HashRef]' );

  sub BUILDARGS {
    my $class = shift;
    return ref($_[0]) eq 'HASH' ? $_[0] : { @_ };
  }

  sub BUILD {
    my $self = shift;
    $self->init;
  }

  __PACKAGE__->meta->make_immutable;

  no Mouse;

  use AnyEvent;
  use AnyEvent::IRC::Client;

  sub init {
    my $self = shift;

    # fetch metadata of redmine
    $self->api->reload;

    my $cv  = AnyEvent->condvar;
    my $irc = AnyEvent::IRC::Client->new;

    $irc->reg_cb(
      registered => $self->cb_registered,
      disconnect => $self->cb_disconnect,
      publicmsg  => $self->cb_publicmsg,
      privatemsg => $self->cb_privatemsg,
    );

    $self->cv($cv);
    $self->irc($irc);
  }

  sub default_api {
    my $self = shift;
    my $api = Redmine::Chan::API->new( # constructor of WebService::Simple
      base_url => $self->redmine_url,
    );
    $api->issue_fields($self->issue_fields);
    $api->status_commands($self->status_commands);
    $api->custom_field_prefix($self->custom_field_prefix);
    $api->member_api_key({});
    $api->api_key($self->redmine_api_key);
    return $api;
  }

  sub default_recipe {
    my $self = shift;
    my $recipe = Redmine::Chan::Recipe->new({
      api      => $self->api,
      nick     => $self->nick,
      channels => $self->irc_channels,
    });
    return $recipe;
  }

  sub cb_registered {
    return sub { print "registered.\n" };
  }

  sub cb_disconnect {
    return sub { print "disconnected.\n" };
  }

  sub cb_publicmsg {
    my $self = shift;
    return sub {
      my ($irc, $channel, $ircmsg) = @_;
      my (undef, $who) = $irc->split_nick_mode($ircmsg->{prefix});

      # Jenkinsのビルド番号除外
      return if $who =~ /jenkins/i;

      my $msg = $self->recipe->cook(
        irc     => $irc,
        channel => $channel,
        ircmsg  => $ircmsg,
        who     => $who,
      );
      #$irc->send_chan($channel, "NOTICE", $channel, $msg) if $msg;
    };
  }

  sub cb_privatemsg {
    my $self = shift;
    return sub {
      # TODO
      my ($irc, $channel, $ircmsg) = @_;
      my (undef, $who) = $irc->split_nick_mode($ircmsg->{prefix});
      my $key = $ircmsg->{params}[1];
      my $msg = $self->api->set_api_key($who, $key);
      $irc->send_msg("PRIVMSG", $who, $msg);
    };
  }

  sub cook {
    my $self = shift;
    my $info = {
      nick     => $self->nick,
      real     => $self->nick,
      password => $self->irc_password,
    };
    $self->irc->connect($self->irc_server, $self->irc_port, $info);
    for my $name (keys %{$self->irc_channels}) {
      $self->irc->send_srv("JOIN", $name);
    }
    $self->cv->recv;
    $self->irc->disconnect;
  }

  *run = \&cook;
}

1;
__END__

=head1 NAME

Redmine::Chan

=head1 SYNOPSIS

    use Redmine::Chan;
    my $minechan = Redmine::Chan->new(
        irc_server      => 'irc.example.com', # irc
        irc_port        => 6667,
        irc_password    => '',
        irc_channels    => {
            '#channel' => { # irc channel name
                key        => '', # irc channel key
                project_id => 1,  # redmine project id
                charset    => 'iso-2022-jp',
            },
        },
        redmine_url     => $redmine_url,
        redmine_api_key => $redmine_api_key,

        # optional config
        status_commands => {
            1 => [qw/hoge/], # change status command
        },
        custom_field_prefix => {
            1 => [qw(prefix)], # prefix to change custome field
        },
        issue_fields => [qw/subject/], # displayed issue fields
    );
    $minechan->cook;

=head1 AUTHOR

Yasuhiro Onishi  C<< <yasuhiro.onishi@gmail.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2012, Yasuhiro Onishi C<< <yasuhiro.onishi@gmail.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

