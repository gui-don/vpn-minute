<?php

declare(strict_types=1);

namespace VPNMinute\Core\Assembly;

/**
 * Proxy to InfrastructureProvisionerAssembly. This proxy caches the deliberation results.
 */
class AssemblyDeliberationCacheProxy
{
    private CanDeliberate $canDeliberate;
    private ?array $deliberation = null;

    public function __construct(CanDeliberate $canDeliberate)
    {
        $this->canDeliberate = $canDeliberate;
    }

    public function getDeliberation($data): array
    {
        if (null === $this->deliberation) {
            $this->deliberation = $this->canDeliberate->deliberate($data);
        }

        return $this->deliberation;
    }
}
