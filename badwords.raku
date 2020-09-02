#!raku

use API::Discord;
use Myisha::Chatfilter::Core;
use Myisha::Chatfilter::Configuration;
use Redis::Async;

my $configuration = Myisha::Chatfilter::Configuration.new;
my %config = $configuration.generate;

my $redis = Redis::Async.new('127.0.0.1:6379');

sub MAIN() {
    my $discord = API::Discord.new(:token(%config<discord-token>));

    $discord.connect;
    await $discord.ready;

    my $c = Myisha::Chatfilter::Core.new(:$discord, :$redis);

    my @guild-ids = $discord.user.guilds.result.map( *.id );
    my SetHash %badwords = $c.get-badwords(@guild-ids);

    react {
        whenever $discord.messages -> $message {
            my $guild-id = $message.channel.guild.id;
            my $content = $message.content;
            
            given $content {
                when s/^"%config<command-prefix>"// {
                    my %response = $c.run(:str($content), :payload($message));
                    $message.channel.result.send-message(|%response);
                }
            }
            default {
                if any(%badwords{$guild-id}.keys.map({ rx:m:i/ << $_ >> / })) {
                    $message.delete;
                }
            }
        }
    }
}
