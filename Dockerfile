from ubuntu

RUN dpkg-divert --local --rename --add /sbin/initctl && ln -s /bin/true /sbin/initctl

RUN echo "deb http://archive.ubuntu.com/ubuntu/ precise universe" >> /etc/apt/sources.list
RUN echo "deb http://archive.ubuntu.com/ubuntu/ precise-updates main" >> /etc/apt/sources.list

RUN apt-get update
RUN apt-get install -y ruby1.9.1 ruby1.9.1-dev rubygems1.9.1 irb1.9.1 ri1.9.1 rdoc1.9.1 build-essential libopenssl-ruby1.9.1 libssl-dev zlib1g-dev

RUN gem install --no-rdoc --no-ri jekyll json

ADD ./ /opt/src

EXPOSE 4000

CMD ["jekyll", "serve", "-s", "/opt/src"]



