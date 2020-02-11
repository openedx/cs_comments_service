FROM ubuntu:bionic as app

RUN apt update && \
  apt upgrade -y && \
  apt install -y git wget autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm-dev && rm -rf /var/lib/apt/lists/*

# Install ruby-build for building specific version of ruby
RUN git clone https://github.com/rbenv/ruby-build.git /edx/app/ruby-build

# Install ruby and some specific dependencies
ENV RUBY_VERSION 2.4.1
ENV BUNDLER_VERSION 1.11.2

ENV RAKE_VERSION 10.4.2
ENV PATH "/edx/app/ruby/bin:${PATH}"
ENV PATH "/edx/app/forums/cs_comments_service/bin:${PATH}"
ENV RACK_ENV production
ENV API_KEY forumapikey
ENV SEARCH_SERVER "http://elasticsearch:9200"
ENV MONGODB_AUTH ""
ENV MONGODB_HOST "mongodb"
ENV MONGODB_PORT "27017"

RUN /edx/app/ruby-build/bin/ruby-build $RUBY_VERSION /edx/app/ruby
RUN gem install bundler -v $BUNDLER_VERSION
RUN gem install rake -v $RAKE_VERSION
# gem upgrade must come after bundler/rake install
RUN gem install rubygems-update && update_rubygems


WORKDIR /edx/app/forums/cs_comments_service
EXPOSE 4567

COPY ./Gemfile /edx/app/forums/cs_comments_service/Gemfile
COPY ./Gemfile.lock /edx/app/forums/cs_comments_service/Gemfile.lock
COPY . /edx/app/forums/cs_comments_service/
RUN bundle install --deployment

RUN useradd -m --shell /bin/false app
USER app

CMD unicorn -c /edx/app/forums/cs_comments_service/config/unicorn_tcp.rb -I '.'
