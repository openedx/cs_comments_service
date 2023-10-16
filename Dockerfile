FROM ubuntu:focal as app

ENV DEBIAN_FRONTEND noninteractive

ENV RUBY_VERSION 3.0.4

# System requirements.
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

# Install Ruby
RUN curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
ENV PATH=/root/.rbenv/shims:/root/.rbenv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
RUN echo 'eval "$(rbenv init -)"' >> /etc/profile.d/rbenv.sh
RUN echo 'eval "$(rbenv init -)"' >> .bashrc

RUN rbenv install $RUBY_VERSION
RUN echo 'gem: --no-rdoc --no-ri' >> /.gemrc
RUN rbenv global $RUBY_VERSION
RUN ruby --version
RUN gem update --system

ARG COMMON_APP_DIR="/edx/app"
ARG CS_COMMENTS_SERVICE_NAME="cs_comments_service"
ARG CS_COMMENTS_SERVICE_APP_DIR="${COMMON_APP_DIR}/forum/${CS_COMMENTS_SERVICE_NAME}"
ENV BUNDLE_GEMFILE ./Gemfile3

WORKDIR ${CS_COMMENTS_SERVICE_APP_DIR}
EXPOSE 4567

FROM app as dev

COPY ./Gemfile3 ${CS_COMMENTS_SERVICE_APP_DIR}/Gemfile3
COPY ./Gemfile3.lock ${CS_COMMENTS_SERVICE_APP_DIR}/Gemfile3.lock
COPY . ${CS_COMMENTS_SERVICE_APP_DIR}

RUN bundle install

CMD while true; do unicorn -c /edx/app/forum/cs_comments_service/config/unicorn_tcp.rb -I '.'; sleep 2; done

FROM app as prod

COPY ./Gemfile3 ${CS_COMMENTS_SERVICE_APP_DIR}/Gemfile3
COPY ./Gemfile3.lock ${CS_COMMENTS_SERVICE_APP_DIR}/Gemfile3.lock
COPY . ${CS_COMMENTS_SERVICE_APP_DIR}

RUN bundle install

CMD ["unicorn", "--workers=2", "--name", "forum", "-c", "/edx/app/forum/cs_comments_service/config/unicorn_tcp.rb", "-I", ".", "--log-file", "-", "--max-requests=1000"]
