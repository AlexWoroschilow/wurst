<?php

namespace Wurst\History\Cache;

interface CacheInterface
{
	/**
	 * Load data from cache
	 */
	public function load();

	/**
	 * Refresh wurst cache
	 *
	 * @param unknown_type $collection
	 * @throws \Exception
	 */
	public function refresh($collection);
}