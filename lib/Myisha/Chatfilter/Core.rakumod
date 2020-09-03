unit class Myisha::Chatfilter::Core;
use Command::Despatch;

has SetHash %!badwords;
has @!guild-ids is required;
has $.discord is required;
has $.redis is required;
has $.commands;

method run($str, :$payload) { $!commands.run($str, :$payload) }

submethod TWEAK () {
    %!badwords = self!load-badwords();
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
    for @words { %!badwords{$guild-id}{~$_} = True }
    $!redis.sadd(badwords-redis-key($guild-id), @words);
}

method remove-badword($guild-id, *@words) {
    for @words { %!badwords{$guild-id}{~$_} = False }
    $!redis.srem(badwords-redis-key($guild-id), @words);
}

method !load-badwords() {
    #return gather {
    #    react for @guild-ids -> $gid {
    #        whenever $redis.smembers($gid, :async) { take $gid => SetHash[Str].new(|$_) }
    #    }
    #}
    return @!guild-ids.map({ $_ => SetHash.new($!redis.smembers(badwords-redis-key($_))) })
}

sub badwords-redis-key($guild-id) { return "{$guild-id}-badwords" }
