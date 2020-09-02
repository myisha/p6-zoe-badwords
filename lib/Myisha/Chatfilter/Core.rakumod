unit class Myisha::Chatfilter::Core;
use Command::Despatch;

has $.discord is required;
has $.redis is required;
has $.commands;

method run($str, :$payload) { $!commands.run($str, :$payload) }

submethod TWEAK () {
    $!commands = Command::Despatch.new(
        command-table => {
            ping => -> $self {
                self.ping;
            },
        }
    );
}

method ping {
    return content => 'pong!';
}

method add-badword(%badwords, $guild-id, $content) {
    self.set-badword(%badwords, $guild-id, $content, True);
}

method remove-badword(%badwords, $guild-id, $content) {
    self.set-badword(%badwords, $guild-id, $content, False);
}

method !set-badword(%badwords, $guild-id, $content, $state) {
    %badwords{$guild-id}{$content} = $state;
    $!redis.sadd(badwords-redis-key($guild-id), %badwords{$guild-id}.keys);    
}

method get-badwords(@guild-ids) {
    #return gather {
    #    react for @guild-ids -> $gid {
    #        whenever $redis.smembers($gid, :async) { take $gid => SetHash[Str].new(|$_) }
    #    }
    #}
    return @guild-ids.map({ $_ => SetHash.new($!redis.smembers(badwords-redis-key($_))) })
}

sub badwords-redis-key($guild-id) { return "{$guild-id}-badwords" }
