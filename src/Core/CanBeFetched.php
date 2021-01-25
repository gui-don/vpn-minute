<?php

declare(strict_types=1);

namespace VPNMinute\Core;

/**
 * Represents any fetchable object: InfrastructureProvisioner, Platform, etc.
 */
interface CanBeFetched
{
    public function getName(): string;
}
