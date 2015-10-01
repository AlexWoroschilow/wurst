<?php

$loader = require_once __DIR__.'/../vendor/autoload.php';
$loader->add("Wurst", "../src");

use Suin\RSSWriter\Feed;
use Suin\RSSWriter\Item;
use Suin\RSSWriter\Channel;

use Wurst\History\History;
use Wurst\History\Cache\CacheFile;

use Symfony\Component\Finder\Finder;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

$app = new Silex\Application();
$app->get('/wurst/rss', function (Request $request) {

	$feed = new Feed();

	$channel = (new Channel())
		->title('Wurst update status')
		->description("Uni-Hamburg server")
		->url('http://zbh.uni-hamburg.de')
		->appendTo($feed);

	$history = new History(__DIR__."/../xml",
			new CacheFile(__DIR__."/../cache/wurst_status.cache"));

	foreach($history->collection() as $element) {

		$item = (new Item())
			->title($element->getName())
			->pubDate($element->getDate())
			->description($element->getDescription())
			->appendTo($channel);
	}

	return new Response($feed, 201);
});

$app->run();
