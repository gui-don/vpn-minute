<?php

declare(strict_types=1);

namespace VPNMinute\Core\Voter\InfrastructureProvisioner;

use VPNMinute\Core\Configuration\ConfigurationLoader;
use VPNMinute\Core\Exception\ConfigurationException;
use VPNMinute\Core\Exception\IOException;
use VPNMinute\Core\Voter\CanVote;

/**
 * Votes for InfrastructureProvisioner using end user configuration file.
 */
class ConfigurationVoter implements CanVote
{
    public const INFRASTUCTURE_TOOL_ENABLED_KEY = 'enable';

    private ConfigurationLoader $configurationLoader;

    public function __construct(ConfigurationLoader $configurationLoader)
    {
        $this->configurationLoader = $configurationLoader;
    }

    /**
     * @param mixed $data
     *
     * @throws ConfigurationException
     * @throws IOException
     */
    public function vote($data): array
    {
        if (!$this->configurationHasEnabledKey()) {
            throw new ConfigurationException(sprintf('The “%s” key is missing for InfrastructureProvisioner settings.', self::INFRASTUCTURE_TOOL_ENABLED_KEY));
        }

        return $this->configurationLoader->getInfrastructureProvisionerOptions()[self::INFRASTUCTURE_TOOL_ENABLED_KEY];
    }

    public function hasKnowledgeOn(string $subject): bool
    {
        return 'infrastructureProvisioner' === $subject;
    }

    private function configurationHasEnabledKey(): bool
    {
        return isset($this->configurationLoader->getInfrastructureProvisionerOptions()[self::INFRASTUCTURE_TOOL_ENABLED_KEY]);
    }
}
