use Email::Simple;

use Email::MIME::ParseContentType;

class Email::MIME is Email::Simple does Email::MIME::ParseContentType;

class X::Email::MIME::NYI is Exception {
    has $.description;

    method new($description is copy) {
        if $description ~~ Failure {
            $description = $description.exception.message;
        }
        self.bless(:$description);
    }

    method message {
        sprintf "Not Yet Implemented! (%s)", $.description;
    }
}

class X::Email::MIME::CharsetNeeded is Exception {
    method message { "body-str and body-str-set require a charset!"; }
}

class X::Email::MIME::InvalidBody is Exception {
    method message { "Invalid body from encoding handler - I need a Str or something that I can .decode to a Str"; }
}

use Email::MIME::Encoder::Base64NYI;
use Email::MIME::Encoder::QuotedPrintNYI;

has $!ct;
has @!parts;
has $!body-raw;

class X::Email::MIME::CharsetNeeded is Exception {

}
method new (Str $text){
    my $self = callsame;
    $self!finish_new();
    return $self;
}
method !finish_new(){
    $!ct = self.parse-content-type(self.content-type);
    self.parts;
}

method create(:$header, :$header-str, :$attributes, :$parts, :$body, :$body-str) {
    my $self = callwith(Array.new(), '');
    $self!finish_new();

    die X::Email::MIME::NYI.new('.create NYI');
}

method body-raw {
    return $!body-raw // self.body(True);
}

method parts {
    self.fill-parts unless @!parts;
    
    if +@!parts {
        return @!parts;
    } else {
        return self;
    }
}

method debug-structure($level = 0) {
    my $rv = ' ' x (5 * $level);
    $rv ~= '+ ' ~ self.content-type ~ "\n";
    if +self.parts > 1 {
        for self.parts -> $part {
            $rv ~= $part.debug-structure($level + 1);
        }
    }
    return $rv;
}

method filename {
    die X::Email::MIME::NYI.new('.filename NYI');
}

method invent-filename {
    die X::Email::MIME::NYI.new('.invent-filename NYI');
}

method filename-set {
    die X::Email::MIME::NYI.new('.filename-set NYI');
}

method subparts {
    self.fill-parts unless @!parts;
    return @!parts;
}

method fill-parts {
    if $!ct<type> eq "multipart" || $!ct<type> eq "message" {
        self.parts-multipart;
    } else {
        self.parts-single-part;
    }
    
    return self;
}

method parts-single-part {
    @!parts = ();
}

method parts-multipart {
    my $boundary = $!ct<attributes><boundary>;

    $!body-raw //= self.body(True);
    my @bits = split(/\-\-$boundary/, self.body-raw);
    my $x = 0;
    for @bits {
        if $x {
            unless $_ ~~ /^\-\-/ {
                $_ ~~ s/^\n//;
                $_ ~~ s/\n$//;
                @!parts.push(self.new($_));
            }
        } else {
            $x++;
            self.body-set($_);
        }
    }

    return @!parts;
}

method parts-set(@parts) {
    my $body = '';

    my $ct = self.parse-content-type(self.content-type);

    if +@parts > 1 && $!ct<type> eq 'multipart' {
        $ct<attributes><boundary> //= die X::Email::MIME::NYI.new('Need a port of Email::MessageID');
        my $boundary = $ct<attributes><boundary>;

        for @parts -> $part {
            $body ~= self.crlf ~ "--" ~ $boundary ~ self.crlf;
            $body ~= ~$part;
        }
        $body ~= self.crlf ~ "--" ~ $boundary ~ "--" ~ self.crlf;
        unless $ct<type> eq 'multipart' || $ct<type> eq 'message' {
            $ct<type> = 'multipart';
            $ct<subtype> = 'mixed';
        }
    } elsif +@parts == 1 {
        my $part = @parts[0];
        $body = $part.body;
        my $thispart_ct = self.parse-content-type($part.content-type);
        $ct<type> = $thispart_ct<type>;
        $ct<subtype> = $thispart_ct<subtype>;
        self.encoding-set($part.header('Content-Transfer-Encoding'));
        $ct<attributes><boundary>.delete;
    }

    self!compose-content-type($ct);
    self.body-set($body);
    self.fill-parts;
    self!reset-cids;
}

method parts-add(@parts) {
    my @allparts = self.parts, @parts;
    self.parts-set(@allparts);
}

method walk-parts($callback) {
    die X::Email::MIME::NYI.new('.walk-parts NYI');
}

method boundary-set($data) {
    my $ct-hash = self.parse-content-type(self.content-type);
    if $data {
        $ct-hash<attributes><boundary> = $data;
    } else {
        $ct-hash<attributes><boundary>.delete;
    }
    self!compose-content-type($ct-hash);
    
    if +self.parts > 1 {
        self.parts-set(self.parts)
    }
}

method content-type(){
  return ~self.header("Content-type");
}

method content-type-set($ct) {
    my $ct-hash = self.parse-content-type($ct);
    self!compose-content-type($ct-hash);
    self!reset-cids;
    return $ct;
}

# TODO: make the next three methods into a macro call
method charset-set($data) {
    my $ct-hash = self.parse-content-type(self.content-type);
    if $data {
        $ct-hash<attributes><charset> = $data;
    } else {
        $ct-hash<attributes><charset>.delete;
    }
    self!compose-content-type($ct-hash);
    return $data;
}
method name-set($data) {
    my $ct-hash = self.parse-content-type(self.content-type);
    if $data {
        $ct-hash<attributes><name> = $data;
    } else {
        $ct-hash<attributes><name>.delete;
    }
    self!compose-content-type($ct-hash);
    return $data;
}
method format-set($data) {
    my $ct-hash = self.parse-content-type(self.content-type);
    if $data {
        $ct-hash<attributes><format> = $data;
    } else {
        $ct-hash<attributes><format>.delete;
    }
    self!compose-content-type($ct-hash);
    return $data;
}

method disposition-set($data) {
    self.header-set('Content-Disposition', $data);
}

method as-string {
    return self.header-obj.as-string ~ self.crlf ~ self.body-raw;
}

method !compose-content-type($ct-hash) {
    my $ct = $ct-hash<type> ~ '/' ~ $ct-hash<subtype>;
    for keys $ct-hash<attributes> -> $attr {
        $ct ~= "; " ~ $attr ~ '="' ~ $ct-hash<attributes>{$attr} ~ '"';
    }
    self.header-set('Content-Type', $ct);
    $!ct = $ct-hash;
}

method !get-cid {
    die X::Email::MIME::NYI.new('Need a port of Email::MessageID');
}

method !reset-cids {
    my $ct-hash = self.parse-content-type(self.content-type);

    if +self.parts > 1 {
        if $ct-hash<subtype> eq 'alternative' {
            my $cids;
            for self.parts -> $part {
                my $cid = $part.header('Content-ID') // '';
                $cids{$cid}++;
            }
            if +$cids.keys == 1 {
                return;
            }

            my $cid = self!get-gid;
            for self.parts -> $part {
                $part.header-set('Content-ID', $cid);
            }
        } else {
            for self.parts -> $part {
                my $cid = self!get-cid;
                unless $part.header('Content-ID') {
                    $part.header-set('Content-ID', $cid);
                }
            }
        }
    }
}

###
# content transfer encoding stuff here
###

my %cte-coders = ('base64' => Email::MIME::Encoder::Base64NYI,
                  'quoted-printable' => Email::MIME::Encoder::QuotedPrintNYI);

method set-encoding-handler($cte, $coder) {
    %cte-coders{$cte} = $coder;
}

method body($callsame_only?) {
    my $body = callwith();
    if $callsame_only {
        return $body;
    }
    my $cte = ~self.header('Content-Transfer-Encoding') // '';
    $cte ~~ s/\;.*$//;
    $cte ~~ s:g/\s//;

    if $cte && %cte-coders{$cte}.can('decode') {
        return %cte-coders{$cte}.decode($body);
    } else {
        return $body.encode('ascii');
    }
}

method body-set($body) {
    my $cte = ~self.header('Content-Transfer-Encoding') // '';
    $cte ~~ s/\;.*$//;
    $cte ~~ s:g/\s//;

    my $body-encoded;
    if $cte && %cte-coders{$cte}.can('encode') {
        $body-encoded = %cte-coders{$cte}.encode($body);
    } else {
        if $body.isa('Str') {
            # ensure everything is ascii like it should be
            $body-encoded = $body.encode('ascii').decode('ascii');
        } else {
            $body-encoded = $body.decode('ascii');
        }
    }

    $!body-raw = $body-encoded;
    callwith($body-encoded);
}

method encoding-set($enc) {
    my $body = self.body;
    self.header-set('Content-Transfer-Encoding', $enc);
    self.body-set($body);
}

###
# charset stuff here
###

method body-str {
    my $body = self.body;
    if $body.isa('Str') {
        # if body is a Str, we assume it's already been decoded
        return $body;
    }
    if $body.can('decode') {
        my $charset = $!ct<attributes><charset>;

        if $charset ~~ m:i/^us\-ascii$/ {
            $charset = 'ascii';
        }

        unless $charset {
            if $!ct<type> eq 'text' && ($!ct<subtype> eq 'plain'
                                        || $!ct<subtype> eq 'html') {
                return $body.decode('ascii');
            }

            # I have a Buf with no charset. Can't really do anything...
            die X::Email::MIME::CharsetNeeded.new();
        }

        return $body.decode($charset);
    }
    die X::Email::MIME::InvalidBody.new();
}

method body-str-set(Str $body) {
    my $charset = $!ct<attributes><charset>;

    unless $charset {
        # well, we can't really do anything with this
        die X::Email::MIME::CharsetNeeded.new();
    }

    if $charset ~~ m:i/^us\-ascii$/ {
        $charset = 'ascii';
    }

    self.body-set($body.encode($charset));
}

method header-str-set($header, $value) {
    # Stubbity stub stub stub
    self.header-set($header, $value);
}
