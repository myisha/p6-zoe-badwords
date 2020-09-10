#!raku

use API::Discord;
use API::Discord::Permissions;
use Myisha::Chatfilter::Core;
use Myisha::Chatfilter::Configuration;
use Redis::Async;

my $configuration = Myisha::Chatfilter::Configuration.new;
my %config = $configuration.generate;

my $redis = Redis::Async.new("%config<redis-host>:%config<redis-port>");

sub MAIN() {
    my $discord = API::Discord.new(:token(%config<discord-token>));

    $discord.connect;
    await $discord.ready;

    my @guild-ids = $discord.user.guilds.result.map( *.id );
    my $c = Myisha::Chatfilter::Core.new(:$discord, :$redis, :@guild-ids);

    react {
        whenever $discord.messages -> $message {
            my $guild-id = $message.channel.guild.id;
            my $content = $message.content;
            
            given $content {
                when $c.has-badwords($guild-id, $_) {
                    if $message.channel.guild.get-member($message.author).has-any-permission([ADMINISTRATOR, MANAGE_MESSAGES]) {
                        proceed;
                    }
                    else {
                        $message.delete;
                    }
                }
                when s/^"%config<command-prefix>"// {
                    my %r = $c.run($content, :payload($message));
                    $message.channel.send-message(|%r);
                }
            }
        }
    }   
}
