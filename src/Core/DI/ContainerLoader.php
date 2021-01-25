<?php

declare(strict_types=1);

namespace VPNMinute\Core\DI;

use Symfony\Component\Config\FileLocator;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\DependencyInjection\Loader\YamlFileLoader;
use Symfony\Component\Finder\Exception\DirectoryNotFoundException;
use Symfony\Component\Finder\Finder;
use VPNMinute\Core\Constants;
use VPNMinute\Core\Exception\InternalConfigurationException;

class ContainerLoader
{
    public const SERVICE_CONFIGURATION_SYSTEM_DIR = '/etc/'.Constants::PROGRAM_NAME_SMALL.'/service/';
    public const SERVICE_CONFIGURATION_DEV_DIR = __DIR__.'/../../../config/service/';

    private Finder $finder;

    /**
     * ContainerLoader constructor.
     */
    public function __construct(Finder $finder)
    {
        $this->finder = $finder;
    }

    public function load(): ContainerBuilder
    {
        try {
            $this->finder->files()->in(self::SERVICE_CONFIGURATION_SYSTEM_DIR);
        } catch (DirectoryNotFoundException $exception) {
            try {
                $this->finder->files()->in(self::SERVICE_CONFIGURATION_DEV_DIR);
            } catch (DirectoryNotFoundException $exception) {
                throw new InternalConfigurationException(sprintf('No “%s” neither “%s” exists.', self::SERVICE_CONFIGURATION_SYSTEM_DIR, self::SERVICE_CONFIGURATION_DEV_DIR, ));
            }
        }

        if (!$this->finder->hasResults()) {
            throw new InternalConfigurationException(sprintf('Services definition files cannot be found in “%s” or “%s”.', self::SERVICE_CONFIGURATION_SYSTEM_DIR, self::SERVICE_CONFIGURATION_DEV_DIR, ));
        }

        $containerBuilder = new ContainerBuilder();

        $loader = new YamlFileLoader($containerBuilder, new FileLocator(__DIR__));

        foreach ($this->finder as $file) {
            $loader->load($file->getPath().'/'.$file->getFilename());
        }

        return $containerBuilder;
    }
}
