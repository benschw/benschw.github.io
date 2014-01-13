FROM ubuntu:12.04

RUN echo "deb http://archive.ubuntu.com/ubuntu/ precise universe" >> /etc/apt/sources.list

RUN apt-get update
RUN apt-get install -y build-essential python-software-properties python g++ make ruby1.9.1-full

RUN gem install --no-rdoc --no-ri jekyll json

ADD ./ /opt/src

EXPOSE 4000

CMD ["jekyll", "serve", "-s", "/opt/src"]



