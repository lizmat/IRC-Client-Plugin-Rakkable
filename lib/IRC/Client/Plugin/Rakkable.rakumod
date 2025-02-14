#- prologue --------------------------------------------------------------------

use IRC::Client:ver<4.0.14+>:auth<zef:lizmat>;
use Pastebin::Gist:ver<1.007>:auth<zef:raku-community-modules>;
use App::Rak::Markdown:ver<0.0.4+>:auth<zef:lizmat>;
use Commands:ver<0.0.6+>:auth<zef:lizmat>;

# Defaults for highlighting on terminals
my constant BON  = "\e[1m";   # BOLD ON
my constant BOFF = "\e[22m";  # BOLD OFF

# App::Rak arguments always allowed
# frequencies matches-only
my %basic-allowed is Set = <
  also-first always-first after-context and andnot before-context context
  count-only stats-only eco-code eco-doc eco-meta eco-provides ecosystem
  eco-scripts eco-tests files-with-matches files-without-matches
  ignorecase ignoremark invert-match
  max-matches-per-file only-first or ornot paragraph-context
  show-blame smartcase smartmark sourcery type unique
>.map("--" ~ *);

#- helper subs -----------------------------------------------------------------

my sub own-nick($event) { $event.irc.servers()<_>.nick.head }

my sub highlight($_) { .trans( (BON,BOFF) => chr(2) ) }

my multi sub reply(*@lines) {
    my $event := $*EVENT;

    $event.reply($_) for @lines;
}
my multi sub reply(Str:D $string) {
    my $event := $*EVENT;

    $event.reply($_) for $string.lines;
}
my multi sub reply(Str:D $string, :$word-wrap!) {
    my $event := $*EVENT;

    $event.reply($_) for $string.lines.naive-word-wrapper(:max($word-wrap));
}

my sub matches($items, $, $) {
    reply "Found $items matches:";
}
my sub lines-files($items, $files, $) {
    reply "Found $items lines in $files files:"
}
my sub lines-files-dists($items, $files, $heads) {
    reply "Found $items lines in $files files ($heads distributions):";
}

#- commands --------------------------------------------------------------------

my sub default($_) {
    reply "Don't know how to handle '$_'";
}

# All of the eco-xxx commands
my sub ecosystem($_) {
    my $plugin := $*PLUGIN;

    my str @args := $plugin.setup-basic-args($_, my str $input, my %args);
    if %args<--frequencies> {
        @args.push: "--matches-only" unless %args<--matches-only>;
        $plugin.run-rak: $input, @args, &matches,
          :!headers, :tableizer<frequencies>, :!min-lines;
    }
    else {
        @args.push: "--group-matches";
        @args.push: "--break=" ~ $plugin.markdown.break;
        $plugin.run-rak: $input, @args, &lines-files-dists, :headers(2);
    }
}

my $help;  # Commands object with helper commands, to be set later at startup
my sub help($_) {
    $help.process(.skip.join(" "))
}

# All of the rakudo-xxx commands
my sub rakudo($_) {
    my $plugin := $*PLUGIN;

    my sub splitter($_) {
        .starts-with("nqp/MoarVM/")
          ?? ("MoarVM", .substr(11))
          !! .starts-with("nqp/")
            ?? ("NQP", .substr(4))
            !! .starts-with("t/spec/")
              ?? ("roast", .substr(7))
              !! ("Rakudo", $_)
    }

    my str @args := $plugin.setup-basic-args($_, my str $input, my %args);
    if %args<--frequencies> {
        @args.push: "--matches-only" unless %args<--matches-only>;
        $plugin.run-rak: $input, @args, &matches,
          :!headers, :tableizer<frequencies>, :!min-lines;
    }
    else {
        @args.push: "--group-matches";
        @args.push: "--break=***";
        $plugin.run-rak: $input, @args, &lines-files,
          :&splitter, :headers(2);
    }

}

my $thanks := (
  "You're welcome!", 'Anytime!', 'It was nothing'
).pick(**).iterator;
my sub thanks($) {
    reply $thanks.pull-one;
}

my sub unicode($_) {
    my $plugin := $*PLUGIN;

    my str @args := $plugin.setup-basic-args($_, my str $input, my %args);

    $plugin.run-rak($input, @args, &matches, :!headers, :tableizer<unicode>);
}

my sub version($) {
    my $event  := $*EVENT;
    my $plugin := $*PLUGIN;

    my str $on = $event ~~ IRC::Client::Message::Privmsg::Channel
      ?? " on $event.channel()"
      !! "";

    reply
      "Rakking$on with Raku module $plugin.^name() $plugin.^ver()",
      "Please put any suggestions / bug reports in https://github.com/lizmat/IRC-Client-Plugin-Rakkable/issues.  Thank you!";
}

# Set up commands
my $commands := Commands.new(
  :&default,
  :commands(
    :eco-code(&ecosystem),  :eco-doc(&ecosystem), :eco-provides(&ecosystem),
    :eco-tests(&ecosystem), :eco-scripts(&ecosystem),

    :rakudo-all(&rakudo),   :rakudo-c(&rakudo),    :rakudo-doc(&rakudo),
    :rakudo-java(&rakudo),  :rakudo-js(&rakudo),   :rakudo-nqp(&rakudo),
    :rakudo-perl(&rakudo),  :rakudo-raku(&rakudo), :rakudo-shell(&rakudo),
    :rakudo-tests(&rakudo), :rakudo-yaml(&rakudo),

    :source<rakudo-all>, :tests<rakudo-tests>,

    &help, &thanks, &unicode, &version
  ),
);

#- help ------------------------------------------------------------------------

my constant %help =
  eco-code => q:to/ECO-CODE/,
Search all of the code of the active distributions in the ecosystem
which is the sum of 'eco-provides', 'eco-tests', 'eco-scripts'.
ECO-CODE

  eco-doc => q:to/ECO-DOC/,
Search all of the documentation of the active distributions in the ecosystem.
Note that this may also include code if documentation and code reside in the
same file.  First check dist.ini spec, then look for .pod files, fall back to
README.md.
ECO-DOC

  eco-provides => q:to/ECO-PROVIDES/,
Search all of the files indicated by the 'provides' sections of the active
distributions in the ecosystem.
ECO-PROVIDES

  eco-tests => q:to/ECO-TESTS/,
Search all of the files with test extensions in the 't' and 'xt' directories
of the active distributions in the ecosystem.
ECO-TESTS

  eco-scripts => q:to/ECO-SCRIPTS/,
Search all of the files in the 'bin' directories of the active distributions
in the ecosystem.
ECO-SCRIPTS

  rakudo-all => q:to/RAKUDO-ALL/,
Search all of the files in Rakudo.
RAKUDO-ALL

  rakudo-c => q:to/RAKUDO-C/,
Search all of the C files in Rakudo.
RAKUDO-C

  rakudo-doc => q:to/RAKUDO-DOC/,
Search all of the documentation files in Rakudo.
RAKUDO-DOC

  rakudo-java => q:to/RAKUDO-JAVA/,
Search all of the Java files in Rakudo.
RAKUDO-JAVA

  rakudo-js => q:to/RAKUDO-JS/,
Search all of the Javascript files in Rakudo.
RAKUDO-JS

  rakudo-nqp => q:to/RAKUDO-NQP/,
Search all of the NQP files in Rakudo.
RAKUDO-NQP

  rakudo-perl => q:to/RAKUDO-PERL/,
Search all of the Perl files in Rakudo.
RAKUDO-PERL

  rakudo-raku => q:to/RAKUDO-RAKU/,
Search all of the Raku files in Rakudo.
RAKUDO-RAKU

  rakudo-shell => q:to/RAKUDO-SHELL/,
Search all of the shell scripts / batch files in Rakudo.
RAKUDO-SHELL

  rakudo-tests => q:to/RAKUDO-TEST/,
Search all of the test related files in Rakudo.
RAKUDO-TEST

  rakudo-yaml => q:to/RAKUDO-YAML/,
Search all files that have some sort of YAML in Rakudo.
RAKUDO-YAML

  unicode => q:to/UNICODE/,
Search the unicode database for code points of which the name matches.
UNICODE

  version => q:to/VERSION/,
Show version information.
VERSION

  sections => q:to/SECTIONS/,
Help sections available: eco-code eco-doc eco-provides eco-scripts
eco-tests rakudo-all rakudo-c rakudo-java rakudo-js rakudo-nqp
rakudo-perl rakudo-raku rakudo-shell rakudo-tests rakudo-yaml
unicode version.
SECTIONS
;

# Set up help commands
my sub default-help($_) {
    dd;
    dd $_
}
my sub handler(@words) {
    my $event := $*EVENT;

    if @words && %help{@words.head} -> $text {
        $event.reply:
          $_ for $text.naive-word-wrapper(:100max).lines;
    }
    else {
        $event.reply:
          $_ for %help<sections>.naive-word-wrapper(:100max).lines;
    }
}

# Set up help commands
$help := $commands.extended-help-from-hash(
  %help, :default(&default-help), :&handler
);

#- IRC::Client::Plugin::Rakkable -----------------------------------------------

class IRC::Client::Plugin::Rakkable:ver<0.0.2>:auth<zef:lizmat> {
    has       $.pastebin is built(:bind);
    has       $.markdown is built(:bind);
    has Int() $.debug      = 0;
    has int   $.only-first = 1000;
    has int   $.min-lines  = 6;

    method TWEAK(:$token is copy) {
        without $!pastebin {
            $token = %*ENV<RAKKABLE_TOKEN> unless $token;
            $!pastebin := Pastebin::Gist.new(:$token)
              if $token;
        }

        without $!markdown {
            $!markdown := App::Rak::Markdown.new;
        }
    }

    method !debug($event --> Nil) {
        if $!debug > 1 {
            if $event.?channel -> $channel {
                note "$channel: $event";
            }
            else {
                note $event;
            }
        }
    }

    method irc-connected($event) {
        note "<&own-nick($event)> ready for action";
    }

    multi method irc-to-me(IRC::Client::Message::Privmsg::Channel:D $event) {
        self.process($event);
    }

    multi method irc-to-me(IRC::Client::Message::Privmsg::Me:D $event) {
        self.process($event);
    }

    method process($event) is implementation-detail {
        my $text := $event.text;

        # some basic logging
        say DateTime.now.Str.substr(0,19) ~ " $event.nick(): $text";
        self!debug($event) if $!debug;

        # Process the event
        my $*EVENT    := $event;
        my $*PLUGIN   := self;
        $commands.process($text);
    }

    method setup-basic-args(
      @words, $given-args is raw, %args
    ) is implementation-detail {
        my str @query;
        my str @args;
        my str @nono;

        my $command := $commands.resolve-command(@words.head);
        for @words.skip {
            if .starts-with("--") {
                my ($arg,$value) = .split("=",2);
                if %basic-allowed{$arg} {
                    $value //= True;
                    %args{$arg} := $value;
                    @args.push($_);
                }
                else {
                    @nono.push($arg);
                }
            }
            else {
                @query.push($_);
            }
        }

        my str $pattern = (@query.join(" ") || (%args<--pattern>:delete)) // "";
        @nono.push("--pattern") if %args<--pattern>:delete;

        if @nono {
            reply @nono == 1
              ?? "'@nono.head()' argument not allowed / unknown: ignored"
              !! "'@nono.join("', '") arguments are not allowed, ignored";
        }

        $given-args = "$command $pattern";
        $given-args ~= " @args[]" if @args;

        @args.unshift: "--pattern=$pattern";
        @args.push: "--no-modifications";
        @args.push: "--only-first="
          ~ (%args<only-first>:delete // $!only-first);
        @args.push: "--highlight";

        @args.unshift: "--$command";
        @args
    }

    method run-rak(
      str $input, @args, &found, :$min-lines = $!min-lines
    ) is implementation-detail {
        reply "Running: $input, please be patient!";

        my str @out;
        my str @err;
        my int $items;
        my int $files;
        my int $heads;

        with $!markdown.run(
           @args, :@out, :@err, :$items, :$files, :$heads, :$min-lines, |%_,
        ) -> $content {
            found($items, $files, $heads);

            with $!pastebin {
                my $url := .paste(
                  desc => "&own-nick($*EVENT): $input",
                  { "result.md" => { :$content } },
                );
                reply $url;
            }
            else {
                reply "No pastebin available to store results";
            }
        }
        elsif @err {
            reply "An error has occurred:";
            reply @err.head($min-lines).map(&highlight);
        }
        elsif @out {
            reply @out.map(&highlight);
            reply "That was all!";
        }
        else {
            reply "No occurrences found for: $input";
        }
    }
}

# vim: expandtab shiftwidth=4
