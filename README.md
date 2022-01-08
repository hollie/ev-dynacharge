# NAME

ev-dynacharge.pl - Dynamically charge an electric vehicle based on the energy budget of the house

# SYNOPSIS

```
./ev-dynacharge.pl [--host <MQTT server hostname...> ]

```

# DESCRIPTION

This script allows to dynamically steer the charging process of an electric vehicle. It fetches energy 
consumption values over MQTT and based on the balance and the selected operating mode it will set the 
charge current of the chargepoint where the vehicle is connected to.

This is very much a work in progress, additional documentation and howto information will be added
after the intial field testing is done.

# Using docker to run this script in a container

This repository contains all required files to build a minimal Alpine linux container that runs the script.
The advantage of using this method of running the script is that you don't need to setup the required Perl
environment to run the script, you just bring up the container.

To do this check out this repository, configure the MQTT broker host, username and password in the `.env` file and run:

`docker compose up -d`.

# Updating the README.md file

The README.md file in this repo is generated from the POD content in the script. To update it, run

`pod2github bin/ev-dynacharge.pl > README.md`

# AUTHOR

Lieven Hollevoet `hollie@cpan.org`

# LICENSE

CC BY-NC-SA
