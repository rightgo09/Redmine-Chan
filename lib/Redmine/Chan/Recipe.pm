package Redmine::Chan::Recipe {
  use utf8;
  use Mouse;
  use Encode qw/ encode decode /;

  has 'api'      => (is => 'ro', isa => 'Redmine::Chan::API');
  has 'nick'     => (is => 'ro', isa => 'Str'               );
  has 'channels' => (is => 'ro', isa => 'HashRef'           );
  has 'buffer'   => (is => 'rw', isa => 'Str'               );
  has 'buffer_issue_id' => (is => 'rw', isa => 'Maybe[Int]' );

  sub cook {
    my ($self, %args) = @_;
    my $irc     = $args{irc}    or return;
    my $ircmsg  = $args{ircmsg} or return;
    my $who     = $args{who}    or return;
    my $channel = $self->channel($args{channel}) or return;

    my $api   = $self->api;
    my $nick  = $self->nick;
    my $msg   = $ircmsg->{params}[1];
    my $charset = $channel->{charset} || 'UTF-8';
    $api->who($who);
    $msg = decode $charset, $msg;

    # API サマリ
    if ($msg =~ /^(users|trackers|issue_statuses)$/) {
      my $method = $1 . '_summary';
      my $summary = $api->$method;
      $irc->send_long_message($charset, 0, "NOTICE", $channel->{name}, encode $charset, $summary);
      return;
    }

    my $notice = sub { $irc->send_chan($channel->{name}, "NOTICE", $channel->{name}, encode $charset, +shift) };

    # 設定再読み込み
    if ($msg eq 'reload') {
      $api->reload;
      $notice->('reloaded');
    }
    # "それめっちゃええやん"
    # 上の行をissue登録
    elsif ($msg eq '..') {
      if ($self->buffer) {
        $notice->($api->create_issue($self->buffer, $channel->{project_id}));
      }
    }
    # issue 登録
    elsif ($msg =~ /^\Q$nick\E:?\s+(.+)/) {
      my $reply = $api->create_issue($1, $channel->{project_id});
      $notice->($reply);
      $reply =~ m|/(\d+) |;
      $self->buffer_issue_id($1);
      $notice->("じゃあ#${1}をいつやるのか？");
    }
    # いまでしょ！
    elsif ($msg =~ /^(いま|今)でしょ(！|!)$/) {
      if (my $issue_id = $self->buffer_issue_id) {
        $self->buffer_issue_id(undef);
        # FIXME: 優先度ハードコードを直す
        $api->put($issue_id, { priority_id => 7 });
        $notice->("(｀・ω・´)");
      }
    }
    # note 追加
    elsif ($msg =~ /^(.+?)\s*>\s*\#(\d+)$/) {
      my ($note, $issue_id) = ($1, $2);
      $api->note_issue($issue_id, $note);
      $notice->($api->issue_detail($issue_id));
    }
    # 複数issue 確認
    elsif ((() = $msg =~ /\#(\d+)/g) > 1) {
      while ($msg =~ /\#(\d+)/g) {
        my $issue_id = $1;
        $notice->($api->issue_detail($issue_id));
      }
    }
    # issue 確認/update
    elsif ($msg =~ /\#(\d+)/) {
      my $issue_id = $1;
      $api->update_issue($issue_id, $msg);
      $notice->($api->issue_detail($issue_id));
    }
    else {
      # 何もしない
      # 1行バッファにためる
      $self->buffer($msg);
      # いまでしょ用チケット番号クリア
      if ($self->buffer_issue_id) {
        $notice->('(´・ω・`)');
        $self->buffer_issue_id(undef);
      }
      if ($msg =~ /うー/) {
        $notice->('(／・ω・)／にゃー！');
      }
      return;
    }
  }

  sub channel {
    my $self = shift;
    my $name = shift or return;
    my $channel = $self->channels->{$name};
    $channel->{name} = $name;
    return $channel;
  }
}

1;
__END__
