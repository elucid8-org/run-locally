use v6.d;
use Cro::HTTP::Router;
use Cro::HTTP::Server;
use Cro::HTTP::Log::File;
use RakuConfig;

multi sub MAIN (
        :$config = 'config', #= localised config directory
        :$host = 'localhost', #= default host
        :$port = 3000, #= default port, with defaults set browser to localhost:3000
    ) is export {
    my %config = get-config(:path( $config ));
    my $publication = %config<publication>;
    my $canonical = %config<canonical>;
    my %map = %config<deprecated>.hash;
    my $landing = $canonical ~ '/' ~ %config<landing-page>;
    my @urls;
    my $pretty-urls = %config<publication> ~ '/assets/prettyurls';
    if $pretty-urls.IO ~~ :e & :f {
        for $pretty-urls.IO.lines {
            if m/ \" ~ \" (.+?) \s+ \" ~ \" (.+) / {
                %map{ ~$0 } = ~$1;
            }
        }
    }
    @urls = %map.keys;
    my $app = route {
        get -> *@path {
            if @path.head(2).join('/') eq 'assets/hashed' {
                @path = ('404',)
            }
            my $url = '/' ~ @path.join('/');
            @path = (%map{$url},) if $url ~~ any(@urls);
            @path[*- 1] ~= ".html"
                unless @path[0] eq '' or @path[*- 1].ends-with('.html') or "$publication/{ @path.join('/') }".IO ~~ :e & :f;
            @path.unshift("$canonical")
            unless @path[0] eq '' or "$publication/{ @path.join('/') }".IO ~~ :e & :f;
            static "$publication", @path, :indexes("$landing\.html",);
        }
    }
    my Cro::Service $http = Cro::HTTP::Server.new(
        http => <1.1>,
        :$host, :$port,
        application => $app,
        after => [
            Cro::HTTP::Log::File.new(logs => $*OUT, errors => $*ERR)
        ]
    );
    say "Serving $landing on $host\:$port";
    $http.start;
    react {
        whenever signal(SIGINT) {
            say "Shutting down...";
            $http.stop;
            done;
        }
    }
}
multi sub MAIN(
        Bool :version(:$v)! #= Return version of distribution
               ) {
    say 'Using version ', $?DISTRIBUTION.meta<version>, ' of Elucid8::Run-locally distribution.' if $v;
};
