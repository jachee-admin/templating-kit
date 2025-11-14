###### Perl

# HTTP Calls: `HTTP::Tiny` for small jobs, `LWP::UserAgent` for stateful/advanced

Two lanes: tiny, fast JSON calls with `HTTP::Tiny`, and heavy-duty sessions with `LWP::UserAgent` (cookies, redirects, proxies, forms, multipart).

## TL;DR

* Default to `HTTP::Tiny` for quick JSON GET/POST with tight timeouts.
* Always check `success` and log `status`/`reason`; decode JSON explicitly.
* For sessions, custom agents, cookies, redirects, and forms—use `LWP::UserAgent`.
* Add backoff+retry for 429/5xx; never retry unsafe, non-idempotent POSTs unless required.

---

## Script

```perl
#!/usr/bin/env perl
use v5.36; use strict; use warnings; use utf8; use open qw(:std :encoding(UTF-8));
use JSON::MaybeXS qw(encode_json decode_json);

# --- 1) Minimal JSON client (HTTP::Tiny) --------------------------------------
use HTTP::Tiny;

sub http_json_get ($url, %opt) {
    my $http = HTTP::Tiny->new(
        timeout => $opt{timeout} // 10,
        verify_SSL => 1,
        agent => $opt{agent} // 'perl-cli/1.0',
    );
    my $res = $http->get($url, {
        headers => { 'Accept' => 'application/json', %{$opt{headers}//{}} }
    });
    $res->{success} or die "GET $url failed: $res->{status} $res->{reason}";
    return decode_json($res->{content});
}

sub http_json_post ($url, $data, %opt) {
    my $http = HTTP::Tiny->new(
        timeout => $opt{timeout} // 10,
        verify_SSL => 1,
        agent => $opt{agent} // 'perl-cli/1.0',
    );
    my $body = encode_json($data);
    my $res = $http->post($url, {
        headers => {
            'Content-Type' => 'application/json',
            'Accept'       => 'application/json',
            %{$opt{headers}//{}},
        },
        content => $body,
    });
    $res->{success} or die "POST $url failed: $res->{status} $res->{reason}";
    return decode_json($res->{content});
}

# --- Optional: simple retry for 429/5xx ---------------------------------------
use Time::HiRes qw(usleep);
sub with_http_retry (&$) {
    my ($code, $max) = @_; my $delay = 0.2;
    for my $i (1..$max) {
        my ($ok, $out) = eval { (1, $code->()) }; if ($ok) { return $out }
        my $e = $@ // '';
        if ($e =~ /\b(?:429|5\d{2})\b/ && $i < $max) {
            usleep int(($delay + rand($delay))*1_000_000); $delay = $delay*1.7; next
        }
        die $e;
    }
}

# Example:
# my $data = with_http_retry { http_json_get('https://api.example.com/v1/things') } 5;

# --- 2) Stateful/advanced client (LWP::UserAgent) ------------------------------
use LWP::UserAgent;
use HTTP::Request::Common qw(GET POST);
use HTTP::Cookies;

sub make_ua (%opt) {
    my $ua = LWP::UserAgent->new(
        timeout => $opt{timeout} // 15,
        agent   => $opt{agent}   // 'perl-lwp/1.0',
        max_redirect => 5,
        env_proxy    => 1,  # respect HTTP(S)_PROXY
    );
    $ua->cookie_jar(HTTP::Cookies->new) if $opt{cookies};
    return $ua;
}

sub lwp_get_json ($ua, $url, %opt) {
    my $req = GET $url, 'Accept' => 'application/json', %{$opt{headers}//{}};
    my $res = $ua->request($req);
    $res->is_success or die $res->status_line;
    return decode_json($res->decoded_content);
}

sub lwp_post_form ($ua, $url, %form) {
    my $res = $ua->post($url, \%form);     # application/x-www-form-urlencoded
    $res->is_success or die $res->status_line;
    return $res->decoded_content;
}

# Multipart upload:
# use HTTP::Request::Common qw(POST);
# my $res = $ua->request(POST $url, Content_Type => 'form-data',
#   Content => [ file => [$path, $filename, 'Content-Type' => 'application/octet-stream'] ]);
# $res->is_success or die $res->status_line;
```

---

## Notes

* `HTTP::Tiny` doesn’t follow redirects by default; `LWP::UserAgent` does (up to `max_redirect`).
* Use `decoded_content` in LWP to respect response encoding.
* For OAuth2/Bearer tokens: add `Authorization => "Bearer $token"` in headers.
* Respect proxies in CI with `env_proxy => 1` (LWP) or by setting `%ENV` for `HTTP::Tiny`.

---

```yaml
---
id: docs/perl/70-http-http-tiny-and-lwp.pl.md
lang: perl
platform: posix
scope: http
since: "v0.1"
tested_on: "perl 5.36, HTTP::Tiny 0.086, LWP::UserAgent 6.x"
tags: [perl, http, http-tiny, lwp, json, retry, timeout, proxies, cookies]
description: "Fast JSON calls with HTTP::Tiny; sessions, redirects, forms, and cookies with LWP::UserAgent."
---
```
