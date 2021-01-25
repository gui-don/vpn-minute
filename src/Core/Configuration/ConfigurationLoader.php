<?php

declare(strict_types=1);

namespace VPNMinute\Core\Configuration;

use Symfony\Component\Yaml\Exception\ParseException;
use Symfony\Component\Yaml\Yaml;
use VPNMinute\Core\Exception\ConfigurationException;
use VPNMinute\Core\Exception\IOException;

/**
 * Singleton to read and store the configuration file in memory.
 */
class ConfigurationLoader
{
    public const DEFAULT_PATH = '/etc/vpnm/config.yml';
    public const KEY_INFRASTRUCTURE_Provisioner = 'infrastructure_Provisioner';

    private array $content = [];

    /**
     * @throws IOException
     */
    public function load(string $path = self::DEFAULT_PATH): array
    {
        if ([] !== $this->content) {
            return $this->content;
        }

        $this->checkPathExists($path);

        $this->content = $this->readYaml($path);

        return $this->content;
    }

    /**
     * @throws IOException
     */
    public function getInfrastructureProvisionerOptions(string $path = self::DEFAULT_PATH): array
    {
        if (!isset($this->load($path)[self::KEY_INFRASTRUCTURE_Provisioner])) {
            throw new ConfigurationException(sprintf('“%s” key is missing from file.', self::KEY_INFRASTRUCTURE_Provisioner));
        }

        return $this->load($path)[self::KEY_INFRASTRUCTURE_Provisioner];
    }

    private function readYaml(string $path): array
    {
        try {
            $content = Yaml::parseFile($path);
        } catch (ParseException $exception) {
            throw new IOException(sprintf('Unable to read “%s” configuration file. Is the file in YAML format?', $path));
        }

        return $content;
    }

    private function checkPathExists(string $path): void
    {
        if (!file_exists($path)) {
            throw new IOException(sprintf('Unable to open “%s” configuration file. File does not exists.', $path));
        }
    }
}
