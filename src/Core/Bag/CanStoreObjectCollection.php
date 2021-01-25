<?php

declare(strict_types=1);

namespace VPNMinute\Core\Bag;

use VPNMinute\Core\CanBeFetched;

interface CanStoreObjectCollection
{
    public function get(string $name): ?CanBeFetched;

    public function getAll(): array;

    public function contain(string $name): bool;

    public function add(CanBeFetched $object): void;
}
