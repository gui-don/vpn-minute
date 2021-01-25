<?php

declare(strict_types=1);

namespace VPNMinute\Core\Fetcher;

interface CanFetch
{
    public function isAvailable(): bool;

    public function getWhenAvailable(): ?object;

    public function get(): object;
}
