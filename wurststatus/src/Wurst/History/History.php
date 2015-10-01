<?php

namespace Wurst\History;

use Wurst\History\Entity\Record;
use Wurst\History\Parser\Parser;
use Wurst\History\Cache\CacheInterface;


use Symfony\Component\Finder\Finder;

class History
{
	protected $cache;
	protected $source;

	public function __construct($source, CacheInterface $cache)
	{
		$this->cache = $cache;
		$this->source = $source;
	}

	/**
	 * Get status records, parse new records
	 * and remove processed xml files
	 *
	 * @throws \Exception
	 */
	public function collection()
	{
		$finder = new Finder();
		$finder->files()->in($this->source);
		if($finder->files()->count()) {

			$parser = new Parser($finder, function ($file) use($filesystem) {

				if(!\phpQuery::newDocumentFileXML($file)) {
					throw new \Exception('Can not create php query object');
				}

				return (new Record())
				->setName(pq('task')->text())
				->setDate(pq('date')->text())
				->setDescription("<p>Status: ".pq('status')->text()."</p>".
						"<p>Command: ".pq('command')->text()."</p>".
						"<p>Error: ".pq('error')->text()."</p>");
			});

			$this->cache->refresh($parser->collection());
		}

		return $this->cache->load();
	}
}