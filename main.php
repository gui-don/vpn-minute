#!/usr/bin/env php
<?php

use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\Finder\Finder;
use VPNMinute\Core\DI\ContainerLoader;
use VPNMinute\Core\DI\ServicesCollectionPass;
use VPNMinute\Core\InfrastructureProvisioner;

require __DIR__.'/vendor/autoload.php';

class main
{
    public function __construct()
    {
        $this->run();
    }

    public function run(): void
    {
        $container = $this->prepareContainer();

        echo 'This Code still brings no feature. Job in progress.'.\PHP_EOL;

        $infrastructureProvisioner = $container->get(InfrastructureProvisioner::class);
        echo 'Infrastucture provisionner: '.$infrastructureProvisioner->getName();
    }

    private function prepareContainer(): ContainerBuilder
    {
        $containerLoader = new ContainerLoader(new Finder());
        $container = $containerLoader->load();
        $container->addCompilerPass(new ServicesCollectionPass($container));
        $container->compile();

        return $container;
    }

    private function debugContainer(ContainerBuilder $container)
    {
        foreach ($container->getServiceIds() as $id) {
            $service = $container->get($id, $container::IGNORE_ON_INVALID_REFERENCE);
            if (!$service) {
                continue;
            }
            echo get_class($service).\PHP_EOL;
        }
    }
}

new main();
