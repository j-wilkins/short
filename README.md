#Shortener

A super simple, Sinatra based, Redis backed URL shortener designed to be deployed on Heroku.


Check it out [here](http://shortener1.heroku.com), but be aware that the css on the add page that displays the shortened link assumes you're using a short url, so it kind of looks like shit when it displays `http://shortener1.heroku.com/whatev`

:edit: the version ^ there is an oldy but a goody. There's been a lot of feature creep since then which would muck up a demo. Very soon there will be a way to disable said feature creep and we'll get a new demo.

### Configuration

Currently, short uses either environment variables or settings from a config file, ~/.shortener.

for the `short` client to work, you only need something like
<pre>
---
:SHORTENER\_URL: http://< your shortener url>
</pre>

checkout `lib/shortener/configuration.rb` for more options that you can set.

I'm going to put together a better way of handling this soon, because right now
it's kind of a mess.

### Usage

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

### API

Shortener provide an OK API for interacting with shorts. You get the following.

<pre>
get '/index.json'      => info on all shorts.

get '/delete/:id.json' => delete short @ id, returns {success: true, shortened: id}

get '/:id.json'        => data hash for short @ id

post '/add.json'       => data hash for new short

post '/upload.json'    => data hash for new short,

a data hash can contain the following keys:

  shortened   => id of this short. i.e. 'xZ147'
  url         => url of this short. i.e. 'www.google.com'
  set-count   => number of times this url has been shortened.
  click-count => number of times this short has been resolved.
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


### License


<pre>
            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
                    Version 2, December 2004

 Copyright (C) 20011 Jake Wilkins <jake AT jakewilkins DOT com>

 Everyone is permitted to copy and distribute verbatim or modified
 copies of this license document, and changing it is allowed as long
 as the name is changed.

            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION

  0. You just DO WHAT THE FUCK YOU WANT TO.
</pre>
