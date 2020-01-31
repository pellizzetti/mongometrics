#!/usr/bin/env perl
use strict;
use warnings;
use Mojolicious::Lite;
use Mojo::JSON qw( decode_json );
use Mojo::Util qw( secure_compare );

get '/' => sub {
  my $c        = shift;
  my $json     = $c->req->json;

  unless(secure_compare $c->req->url->to_abs->userinfo, "$ENV{'SKY_EM'}:$ENV{'SKY_PA'}") {
    return $c->render(
      json   => {error => 'unauthorized'},
      status => 401
    );
  }    

  my $cmd = `mongo --quiet --eval 'JSON.stringify(db.serverStatus())' -u clustermonitor -p "$ENV{'SKY_PA'}"`;

  return $c->render(
    json   => decode_json $cmd,
    status => 200
  );
};

app->start;
