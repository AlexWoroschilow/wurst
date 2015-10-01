<?php 

namespace Wurst\History\Parser;
use Symfony\Component\Filesystem\Filesystem;

class Parser {

	protected $finder;
	protected $constructor;

	public function __construct(\Symfony\Component\Finder\Finder $finder, \Closure $constructor = null)
	{
		$this->finder = $finder;
		$this->constructor = $constructor;
	}

	/**
	 * iterrate all files and use a constructor to
	 * @param unknown_type $constructor
	 */
	public function collection (\Closure $constructor = null)
	{
		$collection = [];

		$constructor = empty($constructor) ? $this->constructor : $constructor;

		$filesystem = new Filesystem();
		foreach ($this->finder as $file) {
			if($filesystem->exists($file)) {
				array_push($collection, $constructor($file));
				$filesystem->remove($file);
			}
		}

		return $collection;
	}
}
