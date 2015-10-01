<?php

namespace Wurst\History\Entity;

class Record
{
	protected $name;
	protected $date;
	protected $description;

	public function getName()
	{
		return $this->name;
	}

	public function setName($name) {
		$this->name = $name;
		return $this;
	}

	public function getDate()
	{
		return $this->date;
	}

	public function setDate($date) {
		$this->date = $date;
		return $this;
	}

	public function getDescription()
	{
		return $this->description;
	}

	public function setDescription($description) {
		$this->description = $description;
		return $this;
	}

	public function __toString()
	{
		return $this->getDate();
	}
}