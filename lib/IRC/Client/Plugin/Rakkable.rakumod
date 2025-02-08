use IRC::Client:ver<4.0.13+>:auth<zef:lizmat>;
use Pastebin::Gist:ver<1.007>:auth<zef:raku-community-modules>;
use String::Utils:ver<0.0.32+>:auth<zef:lizmat> <after before>;

# Defaults for highlighting on terminals
my constant BON  = "\e[1m";   # BOLD ON
my constant BOFF = "\e[22m";  # BOLD OFF

my %allowed;

class IRC::Client::Plugin::Rakkable:ver<0.0.1>:auth<zef:lizmat> {
    has       $.pastebin is built(:bind);
    has Int() $.debug      = 0;
    has int   $.only-first = 100;
    has int   $.max-lines  = 5;

    method TWEAK(:$token) {
        without $!pastebin {
            $!pastebin := Pastebin::Gist.new(:$token)
              if $token;
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

    my sub escape($_) {
        .trans(
         ('<',    '>',BON,  BOFF,'[','$', '*'  )
         =>
         ('\\<','\\>','<b>','</b>','\\[','<span>$</span>', '<span>*</span>')
        )
    }

    method rakit(@args) { run 'rak', @args, :out, :err }

    method irc-connected($event) {
        note "Rakkable ready for action";
    }

    multi method irc-to-me(IRC::Client::Message::Privmsg::Channel:D $event) {
        self!debug($event) if $!debug;

        my $text    := $event.text;
        my @words    = $text.words;
        my $command := @words.shift;

        if $command eq 'all' | 'provides' | 'scripts' | 'tests' {
            my str @query;
            my str @args;
            my str $only-first = $!only-first;

            my %args is SetHash;

            for @words {
                if .starts-with("--") {
                    $only-first = .&after("=")
                      if .starts-with("--only-first=");
                    %args.set($_);
                    @args.push($_);
                }
                else {
                    @query.push($_);
                }
            }
            my str $pattern = @query.join(" ");

            my str $given-args = "'$pattern'";
            $given-args ~= " @args[]" if @args;
            @args.unshift: "--pattern=$pattern";

            @args.push: "--no-modifications";
            @args.push: "--human";
            @args.push: "--no-trim";
            @args.push: "--eco-$command";
            @args.push: "--only-first=$only-first";

            my $proc := self.rakit(@args);
            $event.reply:
              "Looking for $given-args in '$command', please be patient!";

            if $proc.exitcode -> $error {
                $event.reply:
                  "Sorry, an error occurred in calling rak ($error):";
                $event.reply: $_
                  for $proc.err.lines.head($!max-lines);
            }
            elsif $proc.out.lines -> @raw {
                if @raw > $!max-lines {
                    my str $last-module;
                    my int $nr-lines;
                    my int $nr-modules;
                    my int $nr-files;

                    my @lines;
                    for @raw {
                        if .contains(/^ \d /) {
                            ++$nr-lines;
                            @lines.push(escape "$_\\");
                        }
                        elsif $_ {
                            @lines.tail .= chop if @lines;

                            my ($module,$file) = .split("/",2);
                            if $module ne $last-module {
                                ++$nr-modules;
                                @lines.push("___") if $last-module;
                                $last-module = $module;
                                @lines.push(escape "### $module");
                            }

                            ++$nr-files;
                            @lines.push(escape "#### $file");
                        }
                    }

                    $event.reply: "Found $nr-lines lines in $nr-files files ($nr-modules distributions):";

                    @lines.tail .= chop;
                    my $content := @lines.join("\n");

                    with $!pastebin {
                        my $url := .paste(
                          desc => "$event.irc.servers()<_>.nick.head(): $command $given-args",
                          { "result.md" => { :$content } },
                        );
                        $event.reply: $url;
                    }
                    else {
                        $event.reply: "No pastebin available to store results";
                    }
                }
                else {
                    $event.reply: .trans( (BON,BOFF) => "\x02" ) for @raw;
                    $event.reply: "That was all!";
                }
            }
            else {
                $event.reply:
                  "No occurrences found for $given-args in '$command'";
            }
        }
        elsif $command eq 'help' {
            $event.reply:
              "Rakking on $event.channel() with Raku module {self.^name} {self.^ver}";
            $event.reply:
              "Currently supported: all | provides | tests | scripts query [rak args]";
        }
        else {
            $event.reply: "Don't understand: '$text'";
        }
    }

    multi method irc-to-me(IRC::Client::Message::Privmsg::Me:D $event) {
        self!debug($event) if $!debug;

        say $event.text.trim;

        $event.reply:
          "Rakking with Raku module {self.^name} {self.^ver}";
    }
}

# vim: expandtab shiftwidth=4
