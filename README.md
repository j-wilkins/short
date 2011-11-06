#Shortener

A super simple, Sinatra based, Redis backed URL shortener designed to be deployed on Heroku.

Check it out [here](http://shortener1.heroku.com), but be aware that the css on the add page that displays the shortened link assumes you're using a short url, so it kind of looks like shit when it displays `http://shortener1.heroku.com/whatev`

There are a couple branches:

* Simple data just stores every URL/short as a key-value pair.
* Complex Data stores the a hash of information about the URL in question.
* Stylish brings in the Twitter Boostrap and some jQuery.
* Simple auth wants to bring some very basic & low tech authorization to adding shortenings.

The master branch is basically stylish, since we all love us some style.