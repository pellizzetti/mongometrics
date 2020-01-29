#!/usr/bin/env perl
use strict;
use Mojolicious::Lite;
use Mojo::JSON qw( decode_json );

get '/' => sub {
  my $c        = shift;
  my $json     = $c->req->json;
  my $email    = $json->{email};
  my $password = $json->{password};
  my $cmd      = `mongo --quiet --eval 'JSON.stringify(db.serverStatus())' -u clustermonitor -p "$envPassword"`;

  unless($email eq $ENV{'SKY_EM'} && $password eq $ENV{'SKY_PA'}) {
    return $c->render(
      json   => {error => 'invalid_username_or_password'},
      status => 400
    );
  }

  return $c->render(
    json   => decode_json $cmd,
    status => 200
  );
};

app->start;
