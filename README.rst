Part of `edX code`__.

__ http://code.edx.org/

edX Comments Service/Forums   |Build|_ |Codecov|_
==================================================
.. |Build| image:: https://github.com/openedx/cs_comments_service/workflows/RUBY%20CI/badge.svg?branch=master
.. _Build: https://github.com/openedx/cs_comments_service/actions?query=workflow%3A%22RUBY+CI%22

.. |Codecov| image:: http://codecov.io/github/edx/cs_comments_service/coverage.svg?branch=master
.. _Codecov: http://codecov.io/github/edx/cs_comments_service?branch=master

An independent comment system which supports voting and nested comments. It
also supports features including instructor endorsement for education-aimed
discussion platforms.

Getting Started
---------------
If you are running cs_comments_service as part of edx-platform__ development under
devstack, it is strongly recommended to read `those setup documents`__ first.  Note that
devstack will take care of just about all of the installation, configuration, and
service management on your behalf. If running outside of devstack, continue reading below.

__ https://github.com/openedx/edx-platform
__ https://github.com/openedx/configuration/wiki/edX-Developer-Stack

This service relies on Elasticsearch and MongoDB. By default the service will use the Elasticsearch server available at
`http://localhost:9200` and the MongoDB server available at `localhost:27017`. This is suitable for local development;
however, if you wish to change these values, refer to `config/application.yml` and `config/mongoid.yml` for the
environment variables that can be set to override the defaults.

Install the requisite gems:

.. code-block:: bash

    $ bundle install

To initialize indices:

Setup search indices. Note that the command below creates `comments_20161220185820323` and
`comment_threads_20161220185820323` indices and assigns `comments` and `comment_threads` aliases. This will enable you
to swap out indices (e.g. rebuild_index) without having to take downtime or modify code with a new index name.

.. code-block:: bash

    $ bin/rake search:initialize

To validate indices exist and contain the proper mappings:

.. code-block:: bash

    $ bin/rake search:validate_indices

To rebuild indices:

To rebuild new indices from the database and then point the aliases `comments` and `comment_threads` to each index
which has equivalent index prefix, you can use the rebuild_indices task. This task will also run catch up before
and after aliases are moved, to minimize time where aliases do not contain all documents.

.. code-block:: bash

    $ bin/rake search:rebuild_indices

You can also adjust the batch size (e.g. 200) and the sleep time (e.g. 2 seconds) between batches to lighten the load
on MongoDB.

.. code-block:: bash

    $ bin/rake search:rebuild_indices[200,2]

Run the server:

.. code-block::

    $ ruby app.rb

By default Sinatra runs on port `4567`. If you'd like to use a different port pass the `-p` parameter:

.. code-block::

    $ ruby app.rb -p 5678

Rake timeout configuration should be set as env varaiable, the default value is 15 second. to set to 20 second:

.. code-block::

    $ RACK_TIMEOUT_SERVICE_TIMEOUT=20 ruby app.rb -p 5678

Running Tests
-------------
Tests are built using the rspec__ framework, and can be run with the command below:

.. code-block::

    $ bin/rspec

If you'd like to view additional options for the command, append the `--help` option:

.. code-block::

    $ bin/rspec --help

__ http://rspec.info/


Running Tests with Docker
-------------------------
You can also use docker-compose to run your tests as follows (assuming you have
docker-compose installed):

.. code-block::

    $ docker-compose -f .github/docker-compose-ci.yml run --rm test-forum

To debug the tests using docker-compose, first start up the containers:

.. code-block::

    $ # Note: Ignore errors creating forum_testing container after it was already started
    $ docker-compose -f .github/docker-compose-ci.yml up

Next, shell into the container:

.. code-block::

    $ docker exec -it forum_testing bash

Finally, from inside the container, start the tests:

.. code-block::

    $ cd /edx/app/forum/cs_comments_service/
    $ .github/run_tests.sh

Tips:

* After running for the first time, you can speed up ``run_tests.sh`` by commenting out ``bundle install`` and ``sleep 10``, which is only needed the first time.
* Add ``binding.pry`` in code anywhere you want a breakpoint to start debugging.

Internationalization (i18n) and Localization (l10n)
---------------------------------------------------

To run the comments service in a language other than English, set the
``SERVICE_LANGUAGE`` environment variable to the `language code` for the
desired language.  Its default value is en-US.

Setting the language has no effect on user content stored by the service.
However, there are a few data validation messages that may be seen by end
users via the frontend in edx-platform__.  These will be
translated to ``SERVICE_LANGUAGE`` assuming a suitable translation file is
found in the locale/ directory.

__ https://github.com/openedx/edx-platform

edX uses Transifex to host translations. To use the Transifex client, be sure
it is installed (``pip install transifex-client`` will do this for you), and
follow the instructions here__ to set up your ``.transifexrc`` file.

__ http://support.transifex.com/customer/portal/articles/1000855-configuring-the-client

To upload strings to Transifex for translation when you change the set
of translatable strings: ``bin/rake i18n:push``

To fetch the latest translations from Transifex: ``bin/rake i18n:pull``

The repository includes some translations so they will be available
upon deployment. To commit an update to these: ``bin/rake i18n:commit``

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
