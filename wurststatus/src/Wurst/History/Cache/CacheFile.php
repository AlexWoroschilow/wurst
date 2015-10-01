<?php

namespace Wurst\History\Cache;

use Symfony\Component\Finder\Finder;
use Symfony\Component\Finder\SplFileInfo;
use Symfony\Component\Filesystem\Filesystem;

class CacheFile implements CacheInterface
{
	protected $source;

	public function __construct($source)
	{
		$this->source = $source;
	}

	/**
	 * Load and parse data from cache file
	 */
	public function load()
	{
		$files = new Filesystem();
		if($files->exists($this->source)) {
			$file = new SplFileInfo($this->source, null, null);
			return unserialize($file->getContents());
		}
		return [];
	}

	/**
	 * Refresh wurst cache
	 *
	 * @param unknown_type $collection
	 * @throws \Exception
	 */
	public function refresh($collection)
	{
		$collection = array_merge($this->load(), $collection);

		usort($collection, function ($item1, $item2) {
			return $item1->getDate() > $item2->getDate() ? -1 : 1;
		});

		if(!($slice = array_chunk($collection, 100))) {
			throw new \Exception('Can not chunk array');
		}

		if(!($collection = array_shift($slice))) {
			throw new \Exception('Status collection can not be empty');
		}

		if(!($collection = array_unique($collection))) {
			throw new \Exception('Status collection can not be empty');
		}

		$files = new Filesystem();
		$files->dumpFile($this->source, serialize($collection));

		return $collection;
	}
}