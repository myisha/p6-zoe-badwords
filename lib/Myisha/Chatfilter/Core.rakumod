unit class Myisha::Chatfilter::Core;
use API::Discord::Permissions;
use Command::Despatch;

has SetHash %!badwords;
has @.guild-ids is required;
has $.discord is required;
has $.redis is required;
has $.commands;

method run($str, :$payload) {
    CATCH {
        when X::Command::Despatch::InvalidCommand { return }
    }

    $!commands.run($str, :$payload)
}

submethod TWEAK () {
    %!badwords = self!load-badwords();
    $!commands = Command::Despatch.new(
        command-table => {
            cf => {
                add => -> $cd {
                    if $cd.payload.channel.guild.get-member($cd.payload.author).has-any-permission([ADMINISTRATOR]) {
                        my $guild-id = $cd.payload.channel.guild.id;
                        my @words = $cd.args.comb(/'"' <( <-[\"]>* )> '"'||\w+/);
                        self.add-badword($guild-id, |@words);
                    } else { content => "You don't have permission to do that." }
                },
                remove => -> $cd {
                    if $cd.payload.channel.guild.get-member($cd.payload.author).has-any-permission([ADMINISTRATOR]) {
                        my $guild-id = $cd.payload.channel.guild.id;
                        my @words = $cd.args.comb(/'"' <( <-[\"]>* )> '"'||\w+/);
                        self.remove-badword($guild-id, |@words);
                    } else { content => "You don't have permission to do that." }
                },
                list => -> $cd {
                    ...
                },
            }
        }
    );
}

method has-badwords($guild-id, $content) {
    $content ~~ any(%!badwords{$guild-id}.keys.map({ rx:m:i/ << $_ >> / }))
}

method add-badword($guild-id, *@words) {
    for @words { %!badwords{$guild-id}{~$_} = True }
    $!redis.sadd(badwords-redis-key($guild-id), @words);
    return content => "The following terms were added to the chatfilter: `@words.join("`, `")`.";
}

method remove-badword($guild-id, *@words) {
    my @removed = %!badwords{$guild-id}{@words}:delete:k;
    $!redis.srem(badwords-redis-key($guild-id), @words);
    return content => "The following terms were removed from the chatfilter: `@removed.join("`, `")`.";
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
