#Shortener

A super simple, Sinatra based, Redis backed URL shortener designed to be deployed on Heroku.


Check it out [here](http://shortener1.heroku.com), but be aware that the css on the add page that displays the shortened link assumes you're using a short url, so it kind of looks like shit when it displays `http://shortener1.heroku.com/whatev`

for obvious reasons, the demo is configured with S3 disabled. However, if you are just looking
to play around with `short` follow the instructions below and use `http://shortener1.heroku.com`
as your the url you want to use.

## Upgrading to 0.5.0

v0.5.0 updates how shortener stores some data. To assist in keeping your data,
v0.5.0 also provides a `rake short:data:dehyphenate_keys` task that will update
your existing data to the new schema. If have data from < 0.5 that you plan on
using in a >= 0.5 world, you should run this task.

### Installation

is now as easy as

`gem install short`

and

`short`

which will then prompt you to supply the config vars necessary to use the short
executable or the short server. You can check out `/lib/shortener/configuration.rb`
to see a list of available configuration variables.

configuration variables are parsed by default on-load and cached for each use,
but all client methods allow override.

### Server

Shortener server provides a primitive API for interacting with shorts. You get the following.

<pre>
get '/index.json'      => info on all shorts.

get '/delete/:id.json' => delete short @ id, returns {success: true, shortened: id}

get '/:id.json'        => data hash for short @ id

post '/add.json'       => data hash for new short
        can accept the following options:
          url:            the url to shorten
          expire:         time in seconds that this short should live
          max-clicks:     the maximum number of clicks this short should accept.
          desired-short:  a short that should be set for this url.
          allow-override: if desired-short is passed, whether or not to allow
                          a random short override.

post '/upload.json'    => data hash for new short,

a data hash will contain the following keys:

  shortened   => id of this short. i.e. 'xZ147'
  url         => url of this short. i.e. 'www.google.com'
  set-count   => number of times this url has been shortened.
  click-count => number of times this short has been resolved.

a data hash might contain the following keys:

  expire      => expire key that will be checked to see if this key will expire
  max-clicks  => maximum number of clicks this short will resolve for

  if it's an endpoint that performs an action it will have a success key set to true or false.
  (right now this is stupid and is set to true always, unless it errors, in which case you
  get a 500 server error. hopefully that changes with some better error messages.)


  S3 Keys

    S3          => true if this is S3 content
    extension   => the file extension of S3 content. i.e. 'm4v'
    file\_name  => the name of the file. i.e. '1234.m4v'
    name        => the descriptive name. i.e. 'Pandas'
    description => the description. i.e. 'A panda sneezes'
</pre>

### Client

`Shortener::Short` provides methods to access the server. You can access it through
the `Shortener` class or directly through the `Shortener::Short` class. You get:

* shorten
* index
* fetch
* delete

methods, each of which will return a/n istance of the `Short` class which will
parse the data and provide some defaults and access to said data.

### Executable

Use the `short` executable to

* start the shortener server
* shorten a url
* fetch info on a short
* delete a short
* view the index of shorts
* run a `short` rake task.

#### Rake

Short provides rake tasks for building and deploying an instance on heroku.
Once you have `short server` running locally (i.e. you've figured out the conf stuff)
you can run `short rake heroku:setup` and it will create a git repo of the necessary
server files, create a heroku app, add the needed addons and push to the created heroku app.
Run `short rake -T` to see more info.


### License

Short makes use of a number of libraries, each of which has its own license.

Short uses the DWTFYWPL.

<pre>
            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
                    Version 2, December 2004

 Copyright (C) 20011 Jake Wilkins \<jake AT jakewilkins DOT com\>

 Everyone is permitted to copy and distribute verbatim or modified
 copies of this license document, and changing it is allowed as long
 as the name is changed.

            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. You just DO WHAT THE FUCK YOU WANT TO.
</pre>
