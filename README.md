#Shortener

A super simple, Sinatra based, Redis backed URL shortener designed to be deployed on Heroku.


Check it out [here](http://shortener1.heroku.com), but be aware that the css on the add page that displays the shortened link assumes you're using a short url, so it kind of looks like shit when it displays `http://shortener1.heroku.com/whatev`

:edit: the version ^ there is an oldy but a goody. There's been a lot of feature creep since then which would muck up a demo. Very soon there will be a way to disable said feature creep and we'll get a new demo.

### Configuration

Currently, short uses either environment variables or settings from a config file, ~/.shortener.

for the `short` client to work, you only need something like
<pre>
---
:SHORTENER_URL: http://< your shortener url>
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
