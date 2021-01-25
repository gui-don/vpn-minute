<?php

declare(strict_types=1);

namespace VPNMinute\Core\Fetcher;

use VPNMinute\Core\Assembly\AssemblyDeliberationCacheProxy;
use VPNMinute\Core\Bag\CanBeFetchedBag;
use VPNMinute\Core\CanBeFetched;
use VPNMinute\Core\Exception\InternalConfigurationException;

/**
 * Fetches any effective CanBeFetched class to be used.
 */
class Fetcher implements CanFetch
{
    private AssemblyDeliberationCacheProxy $assemblyDeliberationCacheProxy;
    private CanBeFetchedBag $canBeFetchedBag;

    public function __construct(AssemblyDeliberationCacheProxy $assemblyDeliberationCacheProxy, CanBeFetchedBag $canBeFetchedClass)
    {
        $this->assemblyDeliberationCacheProxy = $assemblyDeliberationCacheProxy;
        $this->canBeFetchedBag = $canBeFetchedClass;
    }

    public function isAvailable(): bool
    {
        $canBeFetchedClass = $this->do_fetch();

        if (null === $canBeFetchedClass) {
            return false;
        }

        return true;
    }

    public function getWhenAvailable(): ?CanBeFetched
    {
        return $this->do_fetch();
    }

    /**
     * @throws InternalConfigurationException
     */
    public function get(): CanBeFetched
    {
        $canBeFetchedClass = $this->do_fetch();
        if (null === $canBeFetchedClass) {
            throw new InternalConfigurationException(sprintf('No InfrastructureProvisioner class for “%s” were found. Either there are not implemented, not added to the bag or there was a misconfiguration.', implode('', $this->assemblyDeliberationCacheProxy->getDeliberation([]))));
        }

        return $canBeFetchedClass;
    }

    private function do_fetch(): ?CanBeFetched
    {
        foreach ($this->assemblyDeliberationCacheProxy->getDeliberation([]) as $infrastructureProvisioner) {
            if ($this->canBeFetchedBag->contain($infrastructureProvisioner)) {
                return $this->canBeFetchedBag->get($infrastructureProvisioner);
            }
        }

        return null;
    }
}
