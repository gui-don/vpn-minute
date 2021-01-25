<?php

declare(strict_types=1);

namespace Spec\VPNMinute\Core\DI;

use PhpSpec\ObjectBehavior;
use Prophecy\Argument;
use Symfony\Component\DependencyInjection\Compiler\CompilerPassInterface;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\DependencyInjection\Definition;
use Symfony\Component\DependencyInjection\Reference;
use VPNMinute\Core\DI\ServicesCollectionPass;
use VPNMinute\Core\Exception\InternalConfigurationException;

class ServicesCollectionPassSpec extends ObjectBehavior
{
    public const TAGS = ['\SplHeap' => [['name' => 'voter', 'class' => 'InfrastructureProvisionerAssembly']]];

    public function let(ContainerBuilder $container, Definition $definition)
    {
        $container->findTaggedServiceIds(Argument::type('string'))->willReturn(self::TAGS);
        $container->has(Argument::type('string'))->willReturn(true);
        $container->findDefinition(Argument::type('string'))->willReturn($definition);

        $this->beConstructedWith($container);
    }

    public function it_is_initializable()
    {
        $this->shouldHaveType(ServicesCollectionPass::class);
    }

    public function it_is_a_compiler_pass()
    {
        $this->shouldImplement(CompilerPassInterface::class);
    }

    public function it_processes_and_add_method_calls($container, $definition)
    {
        $definition->addMethodCall(Argument::any(), Argument::any())->shouldBeCalledTimes(2);

        $this->process($container);
    }

    public function it_throws_an_exception_when_the_container_does_not_have_a_class_with_the_configured_name($container)
    {
        $container->has(Argument::type('string'))->willReturn(false);

        $this->shouldThrow(InternalConfigurationException::class)->during('process', [$container]);
    }
}
