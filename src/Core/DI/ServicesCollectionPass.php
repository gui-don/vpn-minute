<?php

declare(strict_types=1);

namespace VPNMinute\Core\DI;

use Symfony\Component\DependencyInjection\Compiler\CompilerPassInterface;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\DependencyInjection\Reference;
use VPNMinute\Core\Exception\InternalConfigurationException;

/**
 * Pass tagged services to other bag services.
 */
class ServicesCollectionPass implements CompilerPassInterface
{
    public const COLLECTOR_SERVICES = [
        'voter' => 'VPNMinute\Core\Assembly\%s',
        'can_be_fetched' => 'VPNMinute\Core\Bag\%s',
    ];

    public const COLLECTOR_CLASS_KEY = 'class';

    public const COLLECTOR_ADD_METHODS = [
        'voter' => 'addVoter',
        'can_be_fetched' => 'add',
    ];

    private ContainerBuilder $container;

    public function __construct(ContainerBuilder $container)
    {
        $this->container = $container;
    }

    /**
     * {@inheritdoc}
     */
    public function process(ContainerBuilder $container)
    {
        foreach (array_keys(self::COLLECTOR_SERVICES) as $collectorCategory) {
            $taggedServices = $this->container->findTaggedServiceIds($collectorCategory);

            foreach ($taggedServices as $id => $tags) {
                array_map(function ($attributes) use ($id, $collectorCategory) {
                    $collectorClassName = $attributes[self::COLLECTOR_CLASS_KEY];
                    $collectorService = $this->getCollectorService($collectorCategory, $collectorClassName);

                    if (!$this->container->has($collectorService)) {
                        throw new InternalConfigurationException(sprintf('No collector service “%s” exists. Make sure there is no typo in the class namespace or classname.', $collectorService));
                    }

                    $definition = $this->container->findDefinition($collectorService);

                    $definition->addMethodCall($this->getCollectorAddMethod($collectorCategory), [new Reference($id)]);
                }, $tags);
            }
        }
    }

    private function getCollectorService(string $collectorCategory, string $collectorClass): string
    {
        return sprintf(self::COLLECTOR_SERVICES[$collectorCategory], $collectorClass);
    }

    private function getCollectorAddMethod(string $collectorCategory): string
    {
        return self::COLLECTOR_ADD_METHODS[$collectorCategory];
    }
}
