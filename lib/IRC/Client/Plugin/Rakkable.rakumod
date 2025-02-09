use IRC::Client:ver<4.0.13+>:auth<zef:lizmat>;
use Pastebin::Gist:ver<1.007>:auth<zef:raku-community-modules>;
use App::Rak::Markdown:ver<0.0.1+>:auth<zef:lizmat>;

# Defaults for highlighting on terminals
my constant BON  = "\e[1m";   # BOLD ON
my constant BOFF = "\e[22m";  # BOLD OFF

# App::Rak arguments always allowed
my %basic-allowed is Set = <
  also-first always-first after-context and andnot before-context context
  count-only stats-only eco-code eco-doc eco-meta eco-provides ecosystem
  eco-scripts eco-tests files-with-matches files-without-matches
  frequencies ignorecase ignoremark invert-match matches-only
  max-matches-per-file only-first or ornot paragraph-context
  show-blame smartcase smartmark sourcery type unique
>.map("--" ~ *);

class IRC::Client::Plugin::Rakkable:ver<0.0.1>:auth<zef:lizmat> {
    has       $.pastebin is built(:bind);
    has       $.markdown is built(:bind);
    has Int() $.debug      = 0;
    has int   $.only-first = 100;
    has int   $.max-lines  = 5;

    method TWEAK(:$token is copy) {
        without $!pastebin {
            $token = %*ENV<RAKKABLE_TOKEN> unless $token;
            $!pastebin := Pastebin::Gist.new(:$token)
              if $token;
        }

        without $!markdown {
            $!markdown := App::Rak::Markdown.new(
              break => "***",
              headers => 2,
            )
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

    my sub own-nick($event) { $event.irc.servers()<_>.nick.head }
    my sub highlight($_) { .trans( (BON,BOFF) => chr(2) ) }

    method irc-connected($event) {
        note "<&own-nick($event)> ready for action";
    }

    method !process($event) {
        my $text    := $event.text;
        my @words    = $text.words;
        my $command := @words.shift;

        my str @query;
        my str @args;
        my str @nono;
        my %args;
        my str $only-first = $!only-first;

        self!debug($event) if $!debug;

        for @words {
            if .starts-with("--") {
                my ($arg,$value) = .split("=",2);
                if %basic-allowed{$arg} {
                    $value //= True;
                    $only-first = $value if $arg eq "--only-first=";
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
            $event.reply: @nono == 1
              ?? "'@nono.head' argument not allowed / unknown: ignored"
              !! "'@nono.join("', '") arguments are not allowed, ignored";
        }

        my str $given-args = "'$pattern'";
        $given-args ~= " @args[]" if @args;

        @args.unshift: "--pattern=$pattern";
        @args.push: "--no-modifications";
        @args.push: "--only-first=$only-first";
        @args.push: "--highlight";
        @args.push: "--group-matches";
        @args.push: "--break=***";

        my %nameds = :min-lines($!max-lines + 1);
        if $command eq <
          eco-code eco-doc eco-provides eco-scripts eco-tests
        >.any {
            @args.unshift: "--$command";
        }
        elsif $command eq 'unicode' {
            %nameds<headers> := False;
            %nameds<tableizer> := "unicode";
            @args.unshift: "--unicode";
        }

        elsif $command eq 'help' {
            my str $on = $event ~~ IRC::Client::Message::Privmsg::Channel
              ?? " on $event.channel()"
              !! "";

            $event.reply:
              "Rakking$on with Raku module {self.^name} {self.^ver}";
            $event.reply:
              "Currently supported: eco-code | eco-doc | eco-provides | eco-tests | eco-scripts | unicode query [rak args]";
            return;
        }

        else {
            $event.reply: "Unknown command: $command";
            return;
        }

        $event.reply: "Looking for $given-args using '$command', please be patient!";

        with $!markdown.run(
                 @args,
          my str @err,
          my str @out,
          my int $items,
          my int $files,
          my int $heads,
          |%nameds,
        ) -> $content {
            $event.reply: $command eq 'unicode'
              ?? "Found $items matches"
              !! "Found $items lines in $files files ($heads distributions):";
            with $!pastebin {
                my $url := .paste(
                  desc => "&own-nick($event): $command $given-args",
                  { "result.md" => { :$content } },
                );
                $event.reply: $url;
            }
            else {
                $event.reply: "No pastebin available to store results";
            }
        }
        elsif @err {
            $event.reply: "An error has occurred:";
            $event.reply: $_ for @err.head($!max-lines).map(&highlight);
        }
        elsif @out {
            $event.reply: $_ for @out.map(&highlight);
            $event.reply: "That was all!";
        }
        else {
            $event.reply:
              "No occurrences found for '$command $given-args'";
        }
    }

    multi method irc-to-me(IRC::Client::Message::Privmsg::Channel:D $event) {
        self!process($event);
    }

    multi method irc-to-me(IRC::Client::Message::Privmsg::Me:D $event) {
        self!process($event);
    }
}

# vim: expandtab shiftwidth=4
