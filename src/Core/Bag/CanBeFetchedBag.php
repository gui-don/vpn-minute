<?php

declare(strict_types=1);

namespace VPNMinute\Core\Bag;

use VPNMinute\Core\CanBeFetched;

/**
 * Bag of objects that CanBeFetched.
 */
class CanBeFetchedBag implements CanStoreFetchableCollection
{
    /**
     * @var CanBeFetched[]
     */
    private array $bag;

    public function get(string $name): ?CanBeFetched
    {
        if (!$this->contain($name)) {
            return null;
        }

        return $this->bag[$name];
    }

    /**
     * @return CanBeFetched[]
     */
    public function getAll(): array
    {
        return $this->bag;
    }

    public function contain(string $name): bool
    {
        return isset($this->bag[$name]);
    }

    public function add(CanBeFetched $object): void
    {
        $this->bag[$object->getName()] = $object;
    }
}
