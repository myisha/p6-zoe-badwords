#!raku

use API::Discord;
use Command::Despatch;
use Redis::Async;

my $redis = Redis::Async.new('127.0.0.1:6379');

sub MAIN($token) {
    my $discord = API::Discord.new(:$token);

    $discord.connect;
    await $discord.ready;

    my @guild-ids = $discord.user.guilds.result.map( *.id );
    my SetHash[Str] %badwords = get-badwords(@guild-ids);

    react {
        whenever $discord.messages -> $message {
            my $guild-id = $message.channel.guild.id;
            given $message.content {
                when any(%badwords{$guild-id}.keys.map({ rx:m:i/ << $_ >> / })) {
                    $message.delete;
                }
            }
        }
    }
}

# DRY subroutine for getting the badwords key for redis
sub badwords-redis-key($guild-id) { return "{$guild-id}-badwords" }

sub add-badword(%badwords, $guild-id, $content) {
    set-badword(%badwords, $guild-id, $content, True);
}

sub remove-badword(%badwords, $guild-id, $content) {
    set-badword(%badwords, $guild-id, $content, False);
}

sub set-badword(%badwords, $guild-id, $content, $state) {
    %badwords{$guild-id}{$content} = $state;
    $redis.sadd(badwords-redis-key($guild-id), %badwords{$guild-id}.keys);    
}

# pulls badwords from redis and populates the %badwords megahash
sub get-badwords(@guild-ids) {
    #return gather {
    #    react for @guild-ids -> $gid {
    #        whenever $redis.smembers($gid, :async) { take $gid => SetHash[Str].new(|$_) }
    #    }
    #}
    return @guild-ids.map({ $_ => SetHash[Str].new($redis.smembers(badwords-redis-key($_))) })
}
