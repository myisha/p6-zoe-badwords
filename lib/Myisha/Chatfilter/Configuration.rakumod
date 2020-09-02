unit class Myisha::Chatfilter::Configuration;

use JSON::Fast;

has $.config-file = %*ENV<MYISHA_CONFIG> // "./config.json";

method generate {
    from-json(slurp($!config-file));
}
