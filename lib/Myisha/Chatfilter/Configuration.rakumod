unit class Myisha::Chatfilter::Configuration;

use JSON::Fast;

has $.config-file = %*ENV<MYISHA_CONFIG> // "./config.json";
has %.generate;

submethod TWEAK {
    %!generate = from-json(slurp($!config-file));
}
