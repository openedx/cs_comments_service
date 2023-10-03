FROM ubuntu:focal as app

ENV DEBIAN_FRONTEND noninteractive

ENV RUBY_VERSION 3.2.2
ENV BUNDLER_VERSION 2.4.19
ENV RAKE_VERSION 13.0.6

# # System requirements.
RUN apt update && \
    apt upgrade -y && \
    apt install -qy \
    git \
    # ubuntu locale support so that system utilities have a consistent language and time zone.
    language-pack-en \
    locales \
    curl \
    autoconf \
    bison \
    build-essential \
    libssl-dev \
    libyaml-dev \
    libreadline6-dev \
    zlib1g-dev \
    libncurses5-dev \
    libffi-dev \
    libgdbm6 \
    libgdbm-dev \
    libdb-dev \
    && \
    # delete apt package lists because we do not need them inflating our image
    rm -rf /var/lib/apt/lists/*

# Use UTF-8.
RUN locale-gen en_US.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

RUN curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
RUN echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
RUN echo 'eval "$(rbenv init -)"' >> ~/.bashrc
RUN source ~/.bashrc

RUN rbenv install $RUBY_VERSION
RUN rbenv global $RUBY_VERSION
RUN gem update --system
RUN gem install bundler -v $BUNDLER_VERSION && \
    gem install rake -v $RAKE_VERSION

ARG COMMON_APP_DIR="/edx/app"
ARG CS_COMMENTS_SERVICE_NAME="cs_comments_service"
ARG CS_COMMENTS_SERVICE_APP_DIR = "${COMMON_APP_DIR}/forums/${CS_COMMENTS_SERVICE_NAME}"

WORKDIR ${CS_COMMENTS_SERVICE_APP_DIR}
EXPOSE 4567

COPY ./Gemfile ${CS_COMMENTS_SERVICE_APP_DIR}/Gemfile
COPY ./Gemfile.lock ${CS_COMMENTS_SERVICE_APP_DIR}/Gemfile.lock
COPY . ${CS_COMMENTS_SERVICE_APP_DIR}

RUN bundle install --deployment

RUN useradd -m --shell /bin/false app

USER app

CMD unicorn -c /edx/app/forums/cs_comments_service/config/unicorn_tcp.rb -I '.'
