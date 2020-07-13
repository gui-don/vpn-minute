<?php

declare(strict_types=1);

namespace VPNMinute\Core\DI;

use Symfony\Component\Config\FileLocator;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\DependencyInjection\Loader\YamlFileLoader;

class ContainerLoader
{
    public const SERVICE_CONFIGURATION_FILE = __DIR__.'/../../../config/service/services.yml';

    public function load(): ContainerBuilder
    {
        $containerBuilder = new ContainerBuilder();

        $loader = new YamlFileLoader($containerBuilder, new FileLocator(__DIR__));
        $loader->load(self::SERVICE_CONFIGURATION_FILE);

        $containerBuilder->compile();

        return $containerBuilder;
    }
}
