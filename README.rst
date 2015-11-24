Part of `edX code`__.

__ http://code.edx.org/

comment_as_a_service
====================

An independent comment system which supports voting and nested comments. It
also supports features including instructor endorsement for education-aimed
discussion platforms.

Running The Server
----
Elasticsearch and MongoDB servers need to be available, and correctly referenced
in config/application.yml and config/mongoid.yml, respectively.

Before the server is first run, ensure gems are installed by doing ``bundle install``.

To run the server, do ``ruby app.rb [-p PORT]`` where PORT defaults to 4567.

If you are running cs_comments_service as part of edx-platform__ development under
devstack, it is strongly recommended to read `those setup documents`__ first.  Note that
devstack will take care of just about all of the installation, configuration, and 
service management on your behalf.

__ https://github.com/edx/edx-platform
__ https://github.com/edx/configuration/wiki/edX-Developer-Stack

Runing with Docker Compose
----
Need docker > 1.9 
Need docker-compose > 1.5.1

sudo docker daemon --dns 8.8.8.8

DOCKER_DATA_ROOT is the directory that stores data for persistence services like MySQL or MongoDB.  The
data will survive container restarts and allow continuity during development.

DOCKER_EDX_ROOT is the directory into which you checkout edX source code.  We recommend that you checkout
all edX projects into this directory.

``DOCKER_DATA_ROOT=/var/docker DOCKER_EDX_ROOT=/home/me/git/edx ~/bin/docker-compose --x-networking up``

Ensure that the MongoDB user has been created on the MongoDB container.  This will be automated

```
docker exec -ti $(docker ps --filter="name=mongo" -q) /bin/bash
mongo
use cs_comments_service
db.createUser(
   {
     user: "cs_comments_service",
     pwd: "password",
     roles: [ "readWrite", "dbAdmin" ]
   }
)
quit()

```

Shell into the running container and provision the seed data

```
docker exec -ti $(docker ps --filter="name=forums" -q) /bin/bash
source /edx/app/forum/forum_env
cd /edx/app/forum/cs_comments_service/
bundle install
bundle exec rake db:seed
/edx/app/supervisor/venvs/supervisor/bin/supervisorctl -c /edx/app/supervisor/supervisord.conf start forum

```

From the host verify that the service is functional

``curl -X GET 'http://localhost:4567/api/v1/users/1?api_key=password&complete=True' | python -mjson.tool``

Running Tests
----
To run tests, do ``bundle exec rspec``.  Append ``--help`` or see rspec documentation
for additional options to this command.

Internationalization and Localization
----

To run the comments service in a language other than English, set the
``SERVICE_LANGUAGE`` environment variable to the `language code` for the
desired language.  Its default value is en-US.

Setting the language has no effect on user content stored by the service.
However, there are a few data validation messages that may be seen by end
users via the frontend in edx-platform__.  These will be
translated to ``SERVICE_LANGUAGE`` assuming a suitable translation file is
found in the locale/ directory.

__ https://github.com/edx/edx-platform

edX uses Transifex to host translations. To use the Transifex client, be sure
it is installed (``pip install transifex-client`` will do this for you), and
follow the instructions here__ to set up your ``.transifexrc`` file.

__ http://support.transifex.com/customer/portal/articles/1000855-configuring-the-client

To upload strings to Transifex for translation when you change the set
of translatable strings: ``bundle exec rake i18n:push``

To fetch the latest translations from Transifex: ``bundle exec rake i18n:pull``

The repository includes some translations so they will be available
upon deployment. To commit an update to these: ``bundle exec rake i18n:commit``

License
-------

The code in this repository is licensed under version 3 of the AGPL unless
otherwise noted.

Please see ``LICENSE.txt`` for details.

How to Contribute
-----------------

Contributions are very welcome. The easiest way is to fork this repo, and then
make a pull request from your fork. The first time you make a pull request, you
may be asked to sign a Contributor Agreement.

Reporting Security Issues
-------------------------

Please do not report security issues in public. Please email security@edx.org

Mailing List and IRC Channel
----------------------------

You can discuss this code on the `edx-code Google Group`__ or in the
``edx-code`` IRC channel on Freenode.

__ https://groups.google.com/forum/#!forum/edx-code
