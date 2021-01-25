<?php

declare(strict_types=1);

namespace VPNMinute\InfrastructureProvisioner;

use VPNMinute\Core\InfrastructureProvisioner;

/**
 * Represents an InfrastructureProvisioner.
 */
class Terraform implements InfrastructureProvisioner
{
    public const NAME = 'terraform';

    public function getName(): string
    {
        return self::NAME;
    }
}
