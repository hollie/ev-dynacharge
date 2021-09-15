# NAME

ev-dynacharge.pl - Dynamically charge an electric vehicle based on the energy budget of the house

# SYNOPSIS

    ./ev-dynacharge.pl [--host <MQTT server hostname...> ]
    

# DESCRIPTION

This script allows to dynamically steer the charging process of an electric vehicle. It fetches energy 
consumption values over MQTT and based on the balance and the selected operating mode it will set the 
charge current of the chargepoint where the vehicle is connected to.

This is very much a work in progress, additional documentation and howto information will be added
after the intial field testing is done.

# AUTHOR

Lieven Hollevoet `hollie@cpan.org`

# LICENSE

CC BY-NC-SA
