from ubuntu

RUN dpkg-divert --local --rename --add /sbin/initctl && ln -s /bin/true /sbin/initctl

RUN apt-get update
RUN apt-get install -y rubygems git

RUN gem install --no-rdoc --no-ri jekyll

RUN cd /opt && git clone https://github.com/benschw/txt.fliglio.com.git

WORKDIR /opt/txt.fliglio.com

CMD ["jekyll", "serve"]

# By default, jekyll serve runs on this port.
EXPOSE 4000

