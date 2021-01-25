<?php

declare(strict_types=1);

namespace Spec\VPNMinute\Core\DI;

use PhpSpec\ObjectBehavior;
use Prophecy\Argument;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\Finder\Exception\DirectoryNotFoundException;
use Symfony\Component\Finder\Finder;
use VPNMinute\Core\DI\ContainerLoader;
use VPNMinute\Core\Exception\InternalConfigurationException;

class ContainerLoaderSpec extends ObjectBehavior
{
    public function let(Finder $finder, \SplFileInfo $file)
    {
        $file = new \SplFileInfo(__DIR__.'/../../../Features/services.yml');

        $iterator = new \ArrayIterator([$file]);
        $finder->in(Argument::any())->willReturn($finder);
        $finder->files()->willReturn($finder);
        $finder->hasResults()->willReturn(true);
        $finder->getIterator()->willReturn($iterator);

        $this->beConstructedWith($finder);
    }

    public function it_is_initializable()
    {
        $this->shouldHaveType(ContainerLoader::class);
    }

    public function it_throws_an_exception_when_no_services_config_are_found($finder)
    {
        $finder->hasResults()->willReturn(false);

        $this->shouldThrow(InternalConfigurationException::class)->during('load');
    }

    public function it_throws_an_exception_when_no_service_directory_exists($finder)
    {
        $finder->in(Argument::any())->willThrow(DirectoryNotFoundException::class);

        $this->shouldThrow(InternalConfigurationException::class)->during('load');
    }

    public function it_loads_services_and_return_a_container()
    {
        $this->load()->shouldReturnAnInstanceOf(ContainerBuilder::class);
    }
}
