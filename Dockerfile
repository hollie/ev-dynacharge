FROM alpine

MAINTAINER  Lieven Hollevoet <lieven@quicksand.be>

WORKDIR /
 
RUN apk add --no-cache \
#     curl \
#     tar \
     make \
#     gcc \
#     build-base \
     wget \
     perl \
     perl-dev \
     perl-app-cpanminus 
#     expat-dev
  
RUN cpanm \
     Net::MQTT::Simple \
     Log::Log4perl     \
     Getopt::Long      \
     Pod::Usage        \
     JSON              

RUN apk add tzdata \
  && cp /usr/share/zoneinfo/Europe/Brussels /etc/localtime
  
RUN cd /home ; mkdir guest

WORKDIR /home/guest
ADD bin .
RUN chown -R guest /home/guest ; chmod u+x ev-dynacharge.pl

USER guest

CMD ["sh", "-c", "sleep 1000"]
