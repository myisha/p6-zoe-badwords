unit class Myisha::Chatfilter::Core;
use Command::Despatch;

has SetHash %!badwords .= new;
has $.discord is required;
has $.redis is required;
has $.commands;

method run($str, :$payload) { $!commands.run($str, :$payload) }

submethod TWEAK () {
    $!commands = Command::Despatch.new(
        command-table => {
            cfadd => -> $cd {
                my $guild-id = $cd.payload.channel.guild.id;
                my @words = $cd.args ~~ m:g/'"'<(<-[\"]>*)>'"'||\w+/;
                self.add-badword($guild-id, |@words);
            },
            cfremove => -> $cd {
                my $guild-id = $cd.payload.channel.guild.id;
                my @words = $cd.args ~~ m:g/'"'<(<-[\"]>*)>'"'||\w+/;
                self.remove-badword($guild-id, |@words);
            },
        }
    );
}

method add-badword($guild-id, *@words) {
    self!set-badword($guild-id, True, |@words);
}

method remove-badword($guild-id, *@words) {
    self!set-badword($guild-id, False, |@words);
}

method !set-badword($guild-id, $state, *@words) {
    for @words { %!badwords{$guild-id}{$_} = $state }
    $!redis.sadd(badwords-redis-key($guild-id), %!badwords{$guild-id}.keys);   
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
